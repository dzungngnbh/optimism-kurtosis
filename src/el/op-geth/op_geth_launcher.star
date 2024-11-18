el_context = import_module("../../el/el_context.star")
el_admin_node_info = import_module("../../el/el_admin_node_info.star")

constants = import_module("../../common/constants.star")
input_parser = import_module("../../common/input_parser.star")
node_metrics_info = import_module("../../common/node_metrics_info.star")
utils     = import_module("../../common/utils.star")

RPC_PORT_NUM         = 8545
WS_PORT_NUM          = 8546
DISCOVERY_PORT_NUM   = 30303
ENGINE_RPC_PORT_NUM  = 8551
METRICS_PORT_NUM     = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU    = 300
EXECUTION_MIN_MEMORY = 512

# Port IDs
RPC_PORT_ID           = "rpc"
WS_PORT_ID            = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID    = "engine-rpc"
ENGINE_WS_PORT_ID     = "engineWs"
METRICS_PORT_ID       = "metrics"

# TODO(old) Scale this dynamically based on CPUs available and Geth nodes mining
NUM_MINING_THREADS = 1

METRICS_PATH = "/debug/metrics/prometheus"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/geth/execution-data"

def get_ports(discovery_port=DISCOVERY_PORT_NUM):
    return {
        RPC_PORT_ID: utils.new_port_spec(
            RPC_PORT_NUM,
        ),
        WS_PORT_ID: utils.new_port_spec(
            WS_PORT_NUM
        ),
        TCP_DISCOVERY_PORT_ID: utils.new_port_spec(
            discovery_port
        ),
        UDP_DISCOVERY_PORT_ID: utils.new_port_spec(
            discovery_port, "UDP"
        ),
        ENGINE_RPC_PORT_ID: utils.new_port_spec(
            ENGINE_RPC_PORT_NUM,
        ),
        METRICS_PORT_ID: utils.new_port_spec(
            METRICS_PORT_NUM
        ),
    }

ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "1",
    constants.GLOBAL_LOG_LEVEL.warn: "2",
    constants.GLOBAL_LOG_LEVEL.info: "3",
    constants.GLOBAL_LOG_LEVEL.debug: "4",
    constants.GLOBAL_LOG_LEVEL.trace: "5",
}

BUILDER_IMAGE_STR = "builder"
SUAVE_ENABLED_GETH_IMAGE_STR = "suave"


def run(
    plan,
    launcher,
    service_name,
    participant,
    global_log_level,
    persistent,
    tolerations,
    node_selectors,
    existing_el_clients,
    sequencer_enabled,
    sequencer_context,
):
    log_level = input_parser.get_client_log_level_or_default(
        participant.el_log_level, global_log_level, VERBOSITY_LEVELS
    )

    cl_client_name = service_name.split("-")[4]

    config = get_config(
        plan,
        launcher,
        service_name,
        participant,
        log_level,
        persistent,
        tolerations,
        node_selectors,
        existing_el_clients,
        cl_client_name,
        sequencer_enabled,
        sequencer_context,
    )

    service = plan.add_service(service_name, config)

    enode, enr = el_admin_node_info.get_enode_enr_for_node(
        plan, service_name, RPC_PORT_ID
    )

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    geth_metrics_info = node_metrics_info.new(
        service_name, METRICS_PATH, metrics_url
    )

    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)

    return el_context.new(
        client_name="op-geth",
        enode=enode,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        enr=enr,
        service_name=service_name,
        el_metrics_info=[geth_metrics_info],
    )


def get_config(
    plan,
    launcher,
    service_name,
    participant,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    existing_el_clients,
    cl_client_name,
    sequencer_enabled,
    sequencer_context,
):
    init_datadir_cmd_str = "geth init --datadir={0} --state.scheme=hash {1}".format(
        EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
        + "/genesis-{0}.json".format(launcher.network_id),
    )

    discovery_port = DISCOVERY_PORT_NUM
    used_ports = get_ports(discovery_port)

    cmd = [
        "geth",
        "--networkid={0}".format(launcher.network_id),
        # "--verbosity=" + verbosity_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--gcmode=archive",
        "--state.scheme=hash",
        "--http",
        "--http.addr=0.0.0.0",
        "--http.vhosts=*",
        "--http.corsdomain=*",
        "--http.api=admin,engine,net,eth,web3,debug",
        "--ws",
        "--ws.addr=0.0.0.0",
        "--ws.port={0}".format(WS_PORT_NUM),
        "--ws.api=admin,engine,net,eth,web3,debug",
        "--ws.origins=*",
        "--allow-insecure-unlock",
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.addr=0.0.0.0",
        "--authrpc.vhosts=*",
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--syncmode=full",
        "--nat=extip:" + constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--rpc.allow-unprotected-txs",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
        "--discovery.port={0}".format(discovery_port),
        "--port={0}".format(discovery_port),
    ]

    if not sequencer_enabled:
        cmd.append(
            "--rollup.sequencerhttp={0}".format(sequencer_context.beacon_http_url)
        )

    if len(existing_el_clients) > 0:
        cmd.append(
            "--bootnodes="
            + ",".join(
                [
                    ctx.enode
                    for ctx in existing_el_clients[
                        : constants.MAX_ENODE_ENTRIES
                    ]
                ]
            )
        )

    cmd += participant.el_extra_params
    cmd_str = " ".join(cmd)
    if launcher.network not in constants.PUBLIC_NETWORKS:
        subcommand_strs = [
            init_datadir_cmd_str,
            cmd_str,
        ]
        command_str = " && ".join(subcommand_strs)
    else:
        command_str = cmd_str

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.deployment_output,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }
    if persistent:
        files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=int(participant.el_volume_size)
            if int(participant.el_volume_size) > 0
            else constants.VOLUME_SIZE[launcher.network][
                constants.EL_TYPE.op_geth + "_volume_size"
            ],
        )
    env_vars = participant.el_extra_env_vars
    config_args = {
        "image": participant.el_image,
        "ports": used_ports,
        "public_ports": {
            "metrics": utils.new_port_spec(9001),

        },
        "cmd": [command_str],
        "files": files,
        "entrypoint": ENTRYPOINT_ARGS,
        "private_ip_address_placeholder": constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": utils.label_maker(
            client=constants.EL_TYPE.op_geth,
            client_type=constants.CLIENT_TYPES.el,
            image=participant.el_image,
            connected_client=cl_client_name,
            extra_labels=participant.el_extra_labels,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    if participant.el_min_cpu > 0:
        config_args["min_cpu"] = participant.el_min_cpu
    if participant.el_max_cpu > 0:
        config_args["max_cpu"] = participant.el_max_cpu
    if participant.el_min_mem > 0:
        config_args["min_memory"] = participant.el_min_mem
    if participant.el_max_mem > 0:
        config_args["max_memory"] = participant.el_max_mem
    return ServiceConfig(**config_args)


def new_op_geth_launcher(
    deployment_output,
    jwt_file,
    network,
    network_id,
):
    return struct(
        deployment_output=deployment_output,
        jwt_file=jwt_file,
        network=network,
        network_id=network_id,
    )
