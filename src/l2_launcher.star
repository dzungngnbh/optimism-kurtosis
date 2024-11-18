participant_network = import_module("./participant_network.star")
contract_deployer = import_module("./contracts/contract_deployer.star")
input_parser = import_module("./common/input_parser.star")
utils = import_module("./common/utils.star")

blockscout = import_module("./blockscout/blockscout_launcher.star")
proxyd = import_module("./proxyd/proxyd.star")

def run(
    plan,
    l2_services_suffix,
    l2_args,
    deployment_output,
    l1_config,
    l1_private_key,
    l1_bootnode_context,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
):
    network_params = l2_args.network_params
    batcher_params = l2_args.batcher_params

    plan.print("Deploying L2 with name {0}".format(network_params.name))
    jwt_file = plan.upload_files(
        src="/static_files/jwt/jwtsecret",
        name="op_jwt_file{0}".format(l2_services_suffix),
    )

    l2_participants = participant_network.run(
        plan,
        l2_args.participants,
        jwt_file,
        network_params,
        batcher_params,
        deployment_output,
        l1_config,
        l2_services_suffix,
        global_log_level,
        global_node_selectors,
        global_tolerations,
        persistent,
    )

    all_el_contexts = []
    all_cl_contexts = []
    for participant in l2_participants:
        all_el_contexts.append(participant.el_context)
        all_cl_contexts.append(participant.cl_context)

    network_id_as_hex = utils.to_hex_chain_id(network_params.network_id)
    l1_bridge_address = utils.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .l1StandardBridgeProxyAddress'.format(
            network_id_as_hex
        ),
    )

    l2_el_context = all_el_contexts[0] # op
    for additional_service in l2_args.additional_services:
        if additional_service == "blockscout":
            plan.print("Launching op-blockscout")
            blockscout.run(
                plan,
                l2_services_suffix,
                l1_bootnode_context,  # first l1 EL url
                all_el_contexts[0],  # first l2 EL url
                network_params.name,
                deployment_output,
                network_params.network_id,
            )
            plan.print("Successfully launched op-blockscout")

    plan.print("Launching proxyd")
    proxyd.run(
        plan,
        l2_el_context
    )
    plan.print("Successfully launched proxyd")

    plan.print(l2_participants)
    plan.print(
        "Begin your L2 adventures by depositing some L1 Kurtosis ETH to bridge address: {0}".format(
            l1_bridge_address
        )
    )