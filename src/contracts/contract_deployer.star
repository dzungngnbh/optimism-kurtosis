utils = import_module("../common/utils.star")

FUND_SCRIPT_FILEPATH = "../../static_files/scripts"

# Deploy L2 contracts
def deploy_contracts(
    plan,
    private_key,
    l1_env_vars,
    optimism_args,
):
    l2_chain_ids = ",".join(
        [str(chain.network_params.network_id) for chain in optimism_args.chains]
    )

    # op-deployer init to create intent.toml file in /network-data folder
    op_deployer_init = plan.run_sh(
        name="op-deployer-init",
        description="Initialize L2 contract deployments",
        image=optimism_args.op_contract_deployer_params.image,
        env_vars=l1_env_vars,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        run=" && ".join(
            [
                "mkdir -p /network-data",
                "op-deployer init --l1-chain-id $L1_CHAIN_ID --l2-chain-ids {0} --workdir /network-data".format(
                    l2_chain_ids
                ),
            ]
        ),
    )

    # update intent with funding dev accounts and block time
    intent_updates = (
        [
            (
                "string",
                "contractArtifactsURL",
                optimism_args.op_contract_deployer_params.artifacts_url,
            ),
        ]
        + [
            (
                "int",
                "chains.[{0}].deployOverrides.l2BlockTime".format(index),
                str(chain.network_params.seconds_per_slot),
            )
            for index, chain in enumerate(optimism_args.chains)
        ]
        + [
            (
                "bool",
                "chains.[{0}].deployOverrides.fundDevAccounts".format(index),
                "true" if chain.network_params.fund_dev_accounts else "false",
            )
            for index, chain in enumerate(optimism_args.chains)
        ]
    )

    op_deployer_configure = plan.run_sh(
        name="op-deployer-configure",
        description="Configure L2 contract deployments",
        image=utils.DEPLOYMENT_UTILS_IMAGE,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        files={
            "/network-data": op_deployer_init.files_artifacts[0],
        },
        run=" && ".join(
            [
                "cat /network-data/intent.toml | dasel put -r toml -t {0} -v '{2}' '{1}' -o /network-data/intent.toml".format(
                    t, k, v
                )
                for t, k, v in intent_updates
            ]
        ),
    )

    # apply op-deployer contract with settings
    cmds = [
        "op-deployer apply --l1-rpc-url $L1_RPC_URL --private-key $PRIVATE_KEY --workdir /network-data",
    ]
    for chain in optimism_args.chains:
        network_id = chain.network_params.network_id
        cmds.extend(
            [
                "op-deployer inspect genesis --workdir /network-data --outfile /network-data/genesis-{0}.json {0}".format(
                    network_id
                ),
                "op-deployer inspect rollup --workdir /network-data --outfile /network-data/rollup-{0}.json {0}".format(
                    network_id
                ),
            ]
        )

    op_deployer_apply = plan.run_sh(
        name="op-deployer-apply",
        description="Apply L2 contract deployments",
        image=optimism_args.op_contract_deployer_params.image,
        env_vars={"PRIVATE_KEY": str(private_key)} | l1_env_vars,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        files={
            "/network-data": op_deployer_configure.files_artifacts[0],
        },
        run=" && ".join(cmds),
    )

    # fund dev accounts
    fund_script_artifact = plan.upload_files(
        src=FUND_SCRIPT_FILEPATH,
        name="op-deployer-fund-script",
    )

    collect_fund = plan.run_sh(
        name="op-deployer-fund",
        description="Collect keys, and fund addresses",
        image=utils.DEPLOYMENT_UTILS_IMAGE,
        env_vars={"PRIVATE_KEY": str(private_key), "FUND_VALUE": "10ether"}
                 | l1_env_vars,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        files={
            "/network-data": op_deployer_apply.files_artifacts[0],
            "/fund-script": fund_script_artifact,
        },
        run='bash /fund-script/fund.sh "{0}"'.format(l2_chain_ids),
    )

    return collect_fund.files_artifacts[0]
