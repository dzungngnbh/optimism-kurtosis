el_cl_client_launcher = import_module("./el_cl_launcher.star")
input_parser          = import_module("./common/input_parser.star")
utils                 = import_module("./common/utils.star")
op_batcher_launcher   = import_module("./batcher/op-batcher/op_batcher_launcher.star")

def run(
    plan,
    participants,
    jwt_file,
    network_params,
    batcher_params,
    deployment_output,
    l1_config_env_vars,
    l2_services_suffix,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
):
    """Launches network participants and batcher service.

    Args:
        plan: Kurtosis execution plan.
        participants: List of network participants.
        jwt_file: JWT authentication file.
        network_params: Network configuration parameters.
        batcher_params: Batcher service parameters.
        deployment_output: Deployment configuration output.
        l1_config_env_vars: L1 configuration environment variables.
        l2_services_suffix: Suffix for L2 service names.
        global_log_level: Global logging level.
        global_node_selectors: Global node selectors for K8s.
        global_tolerations: Global tolerations for K8s.
        persistent: Whether to use persistent storage.

    Returns:
        List of participant configurations.
    """
    num_participants = len(participants)
    # First EL and sequencer CL
    all_el_contexts, all_cl_contexts = el_cl_client_launcher.run(
        plan,
        jwt_file,
        network_params,
        deployment_output,
        participants,
        num_participants,
        l1_config_env_vars,
        l2_services_suffix,
        global_log_level,
        global_node_selectors,
        global_tolerations,
        persistent,
    )

    all_participants = []
    for index, participant in enumerate(participants):
        el_type = participant.el_type
        cl_type = participant.cl_type

        el_context = all_el_contexts[index]
        cl_context = all_cl_contexts[index]

        participant_entry = struct(
            el_type = el_type,
            cl_type = cl_type,
            el_context = el_context,
            cl_context = cl_context,
        )

        all_participants.append(participant_entry)

    proposer_key = utils.read_network_config_value(
        plan,
        deployment_output,
        "proposer-{0}".format(network_params.network_id),
        ".privateKey",
    )
    batcher_key = utils.read_network_config_value(
        plan,
        deployment_output,
        "batcher-{0}".format(network_params.network_id),
        ".privateKey",
    )

    op_batcher_image = (
        batcher_params.image
        if batcher_params.image != ""
        else input_parser.BATCHER_IMAGES["op-batcher"]
    )

    op_batcher_launcher.run(
        plan,
        "op-batcher-{0}".format(l2_services_suffix),
        op_batcher_image,
        all_el_contexts[0],
        all_cl_contexts[0],
        l1_config_env_vars,
        batcher_key,
        batcher_params,
    )

    return all_participants
