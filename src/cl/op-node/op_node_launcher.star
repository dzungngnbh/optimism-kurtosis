cl_context = import_module("../cl_context.star")
constants = import_module("../../common/constants.star")
input_parser = import_module("../../common/input_parser.star")
utils = import_module("../../common/utils.star")

BEACON_DATA_DIRPATH = "/data/op-node/op-node-beacon-data"
BEACON_DISCOVERY_PORT_NUM = 9003
BEACON_HTTP_PORT_NUM = 8547

BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID = "http"

VOLUME_SIZE = 1000 # 1GB

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}

def run(plan, launcher, service_name, participant, global_log_level, persistent, tolerations, node_selectors, el_context, existing_cl_clients, l1_config_env_vars, sequencer_enabled):
    """
    Launches an op-node service with the specified configuration.

    Args:
        plan: Kurtosis execution plan
        launcher: Launcher configuration object
        service_name: Name of the service to create
        participant: Node participant configuration
        global_log_level: Global logging level
        persistent: Whether to use persistent storage
        tolerations: Kubernetes tolerations
        node_selectors: Kubernetes node selectors
        el_context: Execution layer context
        existing_cl_clients: List of existing CL clients
        l1_config_env_vars: L1 configuration environment variables
        sequencer_enabled: Whether sequencer mode is enabled

    Returns:
        CLContext: Context object containing node information
    """
    beacon_node_identity = PostHttpRequestRecipe(
        endpoint="/",
        content_type="application/json",
        body='{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}',
        port_id=BEACON_HTTP_PORT_ID,
        extract={
            "enr": ".result.ENR",
            "multiaddr": ".result.addresses[0]",
            "peer_id": ".result.peerID",
        },
    )

    log_level = input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )

    config = _get_beacon_config(
        plan, launcher, service_name, participant, log_level, persistent,
        tolerations, node_selectors, el_context, existing_cl_clients,
        l1_config_env_vars, beacon_node_identity, sequencer_enabled,
    )

    beacon_service = plan.add_service(service_name, config)
    response = plan.request(recipe=beacon_node_identity, service_name=service_name)

    return cl_context.new_cl_context(
        client_name="op-node",
        enr=response["extract.enr"],
        ip_addr=beacon_service.ip_address,
        http_port=beacon_service.ports[BEACON_HTTP_PORT_ID].number,
        beacon_http_url="http://{0}:{1}".format(
            beacon_service.ip_address,
            beacon_service.ports[BEACON_HTTP_PORT_ID].number
        ),
        cl_nodes_metrics_info=None,
        beacon_service_name=service_name,
        multiaddr=response["extract.multiaddr"],
        peer_id=response["extract.peer_id"],
    )

def _get_used_ports():
    return {
        BEACON_TCP_DISCOVERY_PORT_ID: utils.new_port_spec(BEACON_DISCOVERY_PORT_NUM, "TCP"),
        BEACON_UDP_DISCOVERY_PORT_ID: utils.new_port_spec(BEACON_DISCOVERY_PORT_NUM, "UDP"),
        BEACON_HTTP_PORT_ID: utils.new_port_spec(BEACON_HTTP_PORT_NUM, "TCP", "http"),
    }

def _get_beacon_config(plan, launcher, service_name, participant, log_level, persistent, tolerations, node_selectors, el_context, existing_cl_clients, l1_config_env_vars, beacon_node_identity, sequencer_enabled):
    cmd = _build_command(launcher, el_context, l1_config_env_vars, existing_cl_clients)

    if sequencer_enabled:
        sequencer_key = utils.read_network_config_value(
            plan,
            launcher.deployment_output,
            "sequencer-{0}".format(launcher.network_params.network_id),
            ".privateKey",
        )
        cmd.extend([
            "--p2p.sequencer.key={0}".format(sequencer_key),
            "--sequencer.enabled",
            "--sequencer.l1-confs=5",
        ])

    cmd.extend(participant.cl_extra_params)

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.deployment_output,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    if persistent:
        size = int(participant.el_volume_size) if int(participant.el_volume_size) > 0 else VOLUME_SIZE
        files[BEACON_DATA_DIRPATH] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=size,
        )

    return ServiceConfig(
        image=participant.cl_image,
        ports=_get_used_ports(),
        cmd=cmd,
        files=files,
        env_vars=participant.cl_extra_env_vars,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        labels=utils.label_maker(
            client="op-node",
            client_type=constants.CLIENT_TYPES.cl,
            image=participant.cl_image,
            connected_client=el_context.client_name,
            extra_labels=participant.cl_extra_labels,
        ),
        ready_conditions=ReadyCondition(
            recipe=beacon_node_identity,
            field="code",
            assertion="==",
            target_value=200,
            timeout="1m",
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
        min_cpu=participant.cl_min_cpu if participant.cl_min_cpu > 0 else None,
        max_cpu=participant.cl_max_cpu if participant.cl_max_cpu > 0 else None,
        min_memory=participant.cl_min_mem if participant.cl_min_mem > 0 else None,
        max_memory=participant.cl_max_mem if participant.cl_max_mem > 0 else None,
    )

def _build_command(launcher, el_context, l1_config_env_vars, existing_cl_clients):
    cmd = [
        "op-node",
        "--l2=http://{0}:{1}".format(el_context.ip_addr, el_context.engine_rpc_port_num),
        "--l2.jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--verifier.l1-confs=4",
        "--rollup.config={0}/rollup-{1}.json".format(
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            launcher.network_params.network_id
        ),
        "--rpc.addr=0.0.0.0",
        "--rpc.port={0}".format(BEACON_HTTP_PORT_NUM),
        "--rpc.enable-admin",
        "--l1={0}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l1.rpckind={0}".format(l1_config_env_vars["L1_RPC_KIND"]),
        "--l1.beacon={0}".format(l1_config_env_vars["CL_RPC_URL"]),
        "--l1.trustrpc",
        "--p2p.advertise.ip=" + constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p.advertise.tcp={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.advertise.udp={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.listen.ip=0.0.0.0",
        "--p2p.listen.tcp={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.listen.udp={0}".format(BEACON_DISCOVERY_PORT_NUM),
        ]

    if existing_cl_clients:
        cmd.append("--p2p.bootnodes=" + ",".join([
            ctx.enr for ctx in existing_cl_clients[:constants.MAX_ENR_ENTRIES]
        ]))

    return cmd

def new_op_node_launcher(deployment_output, jwt_file, network_params):
    return struct(
        deployment_output=deployment_output,
        jwt_file=jwt_file,
        network_params=network_params,
    )
