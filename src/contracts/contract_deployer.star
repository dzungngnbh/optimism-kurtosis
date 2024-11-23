utils = import_module("../common/utils.star")

FUND_SCRIPT_FILEPATH = "../../static_files/scripts"

def deploy_contracts(plan, private_key, l1_env_vars, optimism_args):
    """Deploys L2 contracts and handles initialization, configuration and funding.

    Args:
        plan: Kurtosis plan object for execution
        private_key: Private key for contract deployment
        l1_env_vars: Environment variables for L1 chain
        optimism_args: Configuration arguments for Optimism deployment

    Returns:
        Files artifact containing network data and configurations
    """
    l2_chain_ids = _get_chain_ids(optimism_args.chains)
    deployer_configs = _initialize_deployer(plan, l1_env_vars, l2_chain_ids, optimism_args)
    configured_deployer = _configure_deployer(plan, optimism_args, deployer_configs)
    deployed_contracts = _apply_deployer(
        plan,
        private_key,
        l1_env_vars,
        optimism_args.chains,
        configured_deployer,
        optimism_args.op_contract_deployer_params.image
    )

    return _fund_accounts(
        plan,
        private_key,
        l1_env_vars,
        l2_chain_ids,
        deployed_contracts
    )

def _get_chain_ids(chains):
    return ",".join([str(chain.network_params.network_id) for chain in chains])

def _initialize_deployer(plan, l1_env_vars, l2_chain_ids, optimism_args):
    init_cmd = " && ".join([
        "mkdir -p /network-data",
        "op-deployer init --l1-chain-id $L1_CHAIN_ID --l2-chain-ids {0} --workdir /network-data".format(l2_chain_ids)
    ])

    return plan.run_sh(
        name="op-deployer-init",
        description="Initialize L2 contract deployments",
        image=optimism_args.op_contract_deployer_params.image,
        env_vars=l1_env_vars,
        store=[StoreSpec(src="/network-data", name="op-deployer-configs")],
        run=init_cmd,
    )

def _configure_deployer(plan, optimism_args, deployer_configs):
    intent_updates = _create_intent_updates(optimism_args)
    update_commands = [
        "cat /network-data/intent.toml | dasel put -r toml -t {0} -v '{2}' '{1}' -o /network-data/intent.toml".format(t, k, v)
        for t, k, v in intent_updates
    ]

    return plan.run_sh(
        name="op-deployer-configure",
        description="Configure L2 contract deployments",
        image=utils.DEPLOYMENT_UTILS_IMAGE,
        store=[StoreSpec(src="/network-data", name="op-deployer-configs")],
        files={"/network-data": deployer_configs.files_artifacts[0]},
        run=" && ".join(update_commands),
    )

def _create_intent_updates(optimism_args):
    base_updates = [(
        "string",
        "contractArtifactsURL",
        optimism_args.op_contract_deployer_params.artifacts_url,
    )]

    block_time_updates = [
        ("int", "chains.[{0}].deployOverrides.l2BlockTime".format(i),
         str(chain.network_params.seconds_per_slot))
        for i, chain in enumerate(optimism_args.chains)
    ]

    fund_updates = [
        ("bool", "chains.[{0}].deployOverrides.fundDevAccounts".format(i),
         "true" if chain.network_params.fund_dev_accounts else "false")
        for i, chain in enumerate(optimism_args.chains)
    ]

    return base_updates + block_time_updates + fund_updates

def _apply_deployer(plan, private_key, l1_env_vars, chains, configured_deployer, deployer_image):
    commands = ["op-deployer apply --l1-rpc-url $L1_RPC_URL --private-key $PRIVATE_KEY --workdir /network-data"]
    commands.extend(_generate_inspect_commands(chains))

    return plan.run_sh(
        name="op-deployer-apply",
        description="Apply L2 contract deployments",
        image=deployer_image,
        env_vars={"PRIVATE_KEY": str(private_key)} | l1_env_vars,
        store=[StoreSpec(src="/network-data", name="op-deployer-configs")],
        files={"/network-data": configured_deployer.files_artifacts[0]},
        run=" && ".join(commands),
    )

def _generate_inspect_commands(chains):
    commands = []
    for chain in chains:
        network_id = chain.network_params.network_id
        commands.extend([
            "op-deployer inspect genesis --workdir /network-data --outfile /network-data/genesis-{0}.json {0}".format(network_id),
            "op-deployer inspect rollup --workdir /network-data --outfile /network-data/rollup-{0}.json {0}".format(network_id)
        ])
    return commands

def _fund_accounts(plan, private_key, l1_env_vars, l2_chain_ids, deployed_contracts):
    fund_script = plan.upload_files(
        src=FUND_SCRIPT_FILEPATH,
        name="op-deployer-fund-script",
    )

    return plan.run_sh(
        name="op-deployer-fund",
        description="Collect keys, and fund addresses",
        image=utils.DEPLOYMENT_UTILS_IMAGE,
        env_vars={"PRIVATE_KEY": str(private_key), "FUND_VALUE": "10ether"} | l1_env_vars,
        store=[StoreSpec(src="/network-data", name="op-deployer-configs")],
        files={
            "/network-data": deployed_contracts.files_artifacts[0],
            "/fund-script": fund_script,
        },
        run='bash /fund-script/fund.sh "{0}"'.format(l2_chain_ids),
    ).files_artifacts[0]
