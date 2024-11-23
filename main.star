ethereum_package = import_module("github.com/ethpandaops/ethereum-package/main.star")

contract_deployer = import_module("./src/contracts/contract_deployer.star")
input_parser = import_module("./src/common/input_parser.star")
l2_launcher = import_module("./src/l2_launcher.star")
wait_for_sync = import_module("./src/wait/wait_for_sync.star")

def run(plan, args):
    """Deploy Optimism L2s on an Ethereum L1.
    Args:
        plan: Kurtosis execution plan
        args: Configuration arguments for deployment
    """
    l1_config = _deploy_l1(plan, args)
    _deploy_l2(plan, args, l1_config)

def _deploy_l1(plan, args):
    plan.print("Preparing Ethereum L1 configuration")
    ethereum_args = args.get("ethereum_package", {})
    if "network_params" not in ethereum_args:
        ethereum_args.update(input_parser.default_ethereum_package_network_params())

    plan.print("Deploying Ethereum L1 network")
    l1 = ethereum_package.run(plan, ethereum_args)
    l1_env_vars = _get_l1_env_vars(l1)

    if l1.network_params.network == "kurtosis":
        plan.print("Waiting for L1 network startup")
        wait_for_sync.wait_for_startup(plan, l1_env_vars)
    else:
        plan.print("Waiting for L1 network sync")
        wait_for_sync.wait_for_sync(plan, l1_env_vars)

    return l1

def _get_l1_env_vars(l1):
    participant = l1.all_participants[0]
    return {
        "L1_RPC_KIND": "standard",
        "WEB3_RPC_URL": str(participant.el_context.rpc_http_url),
        "L1_RPC_URL": str(participant.el_context.rpc_http_url),
        "CL_RPC_URL": str(participant.cl_context.beacon_http_url),
        "L1_WS_URL": str(participant.el_context.ws_url),
        "L1_CHAIN_ID": str(l1.network_id),
        "L1_BLOCK_TIME": str(l1.network_params.seconds_per_slot),
    }

def _deploy_l2(plan, args, l1):
    plan.print("Preparing Optimism L2 configuration")
    optimism_args = args.get("optimism_package") or input_parser.default_optimism_args()
    optimism_config = input_parser.input_parser(plan, optimism_args)

    l1_env_vars = _get_l1_env_vars(l1)
    l1_private_key = l1.pre_funded_accounts[12].private_key

    plan.print("Deploying L2 contracts")
    deployment = contract_deployer.deploy_contracts(
        plan,
        l1_private_key,
        l1_env_vars,
        optimism_config,
    )

    plan.print("Launching L2 nodes")
    _launch_l2_nodes(
        plan,
        optimism_config,
        l1,
        l1_private_key,
        l1_env_vars,
        deployment
    )

def _launch_l2_nodes(plan, optimism_config, l1, l1_private_key, l1_env_vars, deployment):
    for chain in optimism_config.chains:
        plan.print("Launching L2 chain: {}".format(chain.network_params.name))
        l2_launcher.run(
            plan,
            chain.network_params.name,
            chain,
            deployment,
            l1_env_vars,
            l1_private_key,
            l1.all_participants[0].el_context,
            optimism_config.global_log_level,
            optimism_config.global_node_selectors,
            optimism_config.global_tolerations,
            optimism_config.persistent,
        )
