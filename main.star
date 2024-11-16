ethereum_package = import_module("github.com/ethpandaops/ethereum-package/main.star")

contract_deployer = import_module("./src/contracts/contract_deployer.star")
input_parser = import_module("./src/common/input_parser.star")
l2_launcher = import_module("./src/l2.star")
wait_for_sync = import_module("./src/wait/wait_for_sync.star")


def run(plan, args):
    """Deploy Optimism L2s on an Ethereum L1.

    Args:
        args(json): Configures other aspects of the environment.
    Returns:
        Full deployment of Optimism L2(s)
    """
    plan.print("Parsing the L1 input args")

    # Deploy L1 and L2 smart contract
    # Use default ethereum network params
    ethereum_args = args.get("ethereum_package", {})
    if "network_params" not in ethereum_args:
        ethereum_args.update(input_parser.default_ethereum_package_network_params())

    # deploy L1
    plan.print("Deploying a local L1")
    l1 = ethereum_package.run(plan, ethereum_args)
    plan.print(l1.network_params)

    # get l1 info
    all_l1_participants = l1.all_participants
    l1_network_params = l1.network_params
    l1_network_id = l1.network_id
    l1_private_key = l1.pre_funded_accounts[
        12
    ].private_key  # reserved for L2 contract deployers
    l1_env_vars = get_l1_env_vars(all_l1_participants, l1_network_params, l1_network_id)

    if l1_network_params.network == "kurtosis":
        plan.print("Waiting for L1 to start up")
        wait_for_sync.wait_for_startup(plan, l1_env_vars)
    else:
        plan.print("Waiting for network to sync")
        wait_for_sync.wait_for_sync(plan, l1_env_vars)

    # Get L2 config
    # need to do a raw get here in case only optimism_package is provided.
    # .get will return None if the key is in the config with a None value.
    optimism_args = args.get("optimism_package") or input_parser.default_optimism_args()
    optimism_args_with_right_defaults = input_parser.input_parser(plan, optimism_args)
    global_tolerations = optimism_args_with_right_defaults.global_tolerations
    global_node_selectors = optimism_args_with_right_defaults.global_node_selectors
    global_log_level = optimism_args_with_right_defaults.global_log_level
    persistent = optimism_args_with_right_defaults.persistent

    # deploy L2 smart contract
    deployment_output = contract_deployer.deploy_contracts(
        plan,
        l1_private_key,
        l1_env_vars,
        optimism_args_with_right_defaults,
    )

    # launch L2 nodes: cl and el.
    for chain in optimism_args_with_right_defaults.chains:
        l2_launcher.launch_l2(
            plan,
            chain.network_params.name,
            chain,
            deployment_output,
            l1_env_vars,
            l1_private_key,
            all_l1_participants[0].el_context,
            global_log_level,
            global_node_selectors,
            global_tolerations,
            persistent,
        )


# get l1 config and set global env vars.
def get_l1_env_vars(all_l1_participants, l1_network_params, l1_network_id):
    return {
        "L1_RPC_KIND": "standard",
        "WEB3_RPC_URL": str(all_l1_participants[0].el_context.rpc_http_url),
        "L1_RPC_URL": str(all_l1_participants[0].el_context.rpc_http_url),
        "CL_RPC_URL": str(all_l1_participants[0].cl_context.beacon_http_url),
        "L1_WS_URL": str(all_l1_participants[0].el_context.ws_url),
        "L1_CHAIN_ID": str(l1_network_id),
        "L1_BLOCK_TIME": str(l1_network_params.seconds_per_slot),
    }
