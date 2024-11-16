cl_context   = import_module("../cl_context.star")
constants    = import_module("../../common/constants.star")
input_parser = import_module("../../common/input_parser.star")
utils        = import_module("../../common/utils.star")

#  ---------------------------------- Beacon client -------------------------------------

# The Docker container runs as the "op-node" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-node/op-node-beacon-data"
# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID = "http"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9003
BEACON_HTTP_PORT_NUM = 8547


def get_used_ports(discovery_port):
    used_ports = {
        BEACON_TCP_DISCOVERY_PORT_ID: utils.new_port_spec(
            discovery_port, utils.TCP_PROTOCOL, wait=None
        ),
        BEACON_UDP_DISCOVERY_PORT_ID: utils.new_port_spec(
            discovery_port, utils.UDP_PROTOCOL, wait=None
        ),
        BEACON_HTTP_PORT_ID: utils.new_port_spec(
            BEACON_HTTP_PORT_NUM,
            utils.TCP_PROTOCOL,
            utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}


def run(
    plan,
    launcher,
    service_name,
    participant,
    global_log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    sequencer_enabled,
):
    beacon_node_identity_recipe = PostHttpRequestRecipe(
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

    config = get_beacon_config(
        plan,
        launcher,
        service_name,
        participant,
        log_level,
        persistent,
        tolerations,
        node_selectors,
        el_context,
        existing_cl_clients,
        l1_config_env_vars,
        beacon_node_identity_recipe,
        sequencer_enabled,
    )

    beacon_service = plan.add_service(service_name, config)

    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=service_name
    )

    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    return cl_context.new_cl_context(
        client_name="op-node",
        enr=beacon_node_enr,
        ip_addr=beacon_service.ip_address,
        http_port=beacon_http_port.number,
        beacon_http_url=beacon_http_url,
        cl_nodes_metrics_info=None,
        beacon_service_name=service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
    )


def get_beacon_config(
    plan,
    launcher,
    service_name,
    participant,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    beacon_node_identity_recipe,
    sequencer_enabled,
):
    EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
        el_context.ip_addr,
        el_context.engine_rpc_port_num,
    )

    used_ports = get_used_ports(BEACON_DISCOVERY_PORT_NUM)

    cmd = [
        "op-node",
        "--l2={0}".format(EXECUTION_ENGINE_ENDPOINT),
        "--l2.jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--verifier.l1-confs=4",
        "--rollup.config="
        + constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
        + "/rollup-{0}.json".format(launcher.network_params.network_id),
        "--rpc.addr=0.0.0.0",
        "--rpc.port={0}".format(BEACON_HTTP_PORT_NUM),
        "--rpc.enable-admin",
        "--l1={0}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l1.rpckind={0}".format(l1_config_env_vars["L1_RPC_KIND"]),
        "--l1.beacon={0}".format(l1_config_env_vars["CL_RPC_URL"]),
        "--l1.trustrpc",
        "--p2p.advertise.ip="
        + constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p.advertise.tcp={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.advertise.udp={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.listen.ip=0.0.0.0",
        "--p2p.listen.tcp={0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.listen.udp={0}".format(BEACON_DISCOVERY_PORT_NUM),
    ]

    sequencer_private_key = utils.read_network_config_value(
        plan,
        launcher.deployment_output,
        "sequencer-{0}".format(launcher.network_params.network_id),
        ".privateKey",
    )

    if sequencer_enabled:
        cmd.append("--p2p.sequencer.key=" + sequencer_private_key)
        cmd.append("--sequencer.enabled")
        cmd.append("--sequencer.l1-confs=5")

    if len(existing_cl_clients) > 0:
        cmd.append(
            "--p2p.bootnodes="
            + ",".join(
                [
                    ctx.enr
                    for ctx in existing_cl_clients[
                        : constants.MAX_ENR_ENTRIES
                    ]
                ]
            )
        )

    cmd += participant.cl_extra_params

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.deployment_output,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=int(participant.cl_volume_size)
            if int(participant.cl_volume_size) > 0
            else constants.VOLUME_SIZE[launcher.network][
                constants.CL_TYPE.hildr + "_volume_size"
            ],
        )

    ports = {}
    ports.update(used_ports)

    env_vars = participant.cl_extra_env_vars
    config_args = {
        "image": participant.cl_image,
        "ports": ports,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": utils.label_maker(
            client=constants.CL_TYPE.op_node,
            client_type=constants.CLIENT_TYPES.cl,
            image=participant.cl_image,
            connected_client=el_context.client_name,
            extra_labels=participant.cl_extra_labels,
        ),
        "ready_conditions": ReadyCondition(
            recipe=beacon_node_identity_recipe,
            field="code",
            assertion="==",
            target_value=200,
            timeout="1m",
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.cl_min_cpu > 0:
        config_args["min_cpu"] = participant.cl_min_cpu
    if participant.cl_max_cpu > 0:
        config_args["max_cpu"] = participant.cl_max_cpu
    if participant.cl_min_mem > 0:
        config_args["min_memory"] = participant.cl_min_mem
    if participant.cl_max_mem > 0:
        config_args["max_memory"] = participant.cl_max_mem
    return ServiceConfig(**config_args)


def new_op_node_launcher(deployment_output, jwt_file, network_params):
    return struct(
        deployment_output=deployment_output,
        jwt_file=jwt_file,
        network_params=network_params,
    )
