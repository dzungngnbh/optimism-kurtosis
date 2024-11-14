utils     = import_module("../../package_io/utils.star")
constants = import_module("../../package_io/constants.star")

#
#  ---------------------------------- Batcher client -------------------------------------
# The Docker container runs as the "op-batcher" user so we can't write to root
BATCHER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-batcher/op-batcher-data"

BATCHER_HTTP_PORT_ID  = "http"
BATCHER_HTTP_PORT_NUM = 8548

def get_ports():
    ports = {
        BATCHER_HTTP_PORT_ID: utils.new_port_spec(
            BATCHER_HTTP_PORT_NUM,
            utils.TCP_PROTOCOL,
            utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return ports


ENTRYPOINT_ARGS = ["sh", "-c"]

def launch(
    plan,
    service_name,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    gs_batcher_private_key,
    batcher_params,
):
    config = get_batcher_config(
        plan,
        image,
        service_name,
        el_context,
        cl_context,
        l1_config_env_vars,
        gs_batcher_private_key,
        batcher_params,
    )

    batcher_service = plan.add_service(service_name, config)

    batcher_http_port = batcher_service.ports[BATCHER_HTTP_PORT_ID]
    batcher_http_url = "http://{0}:{1}".format(
        batcher_service.ip_address, batcher_http_port.number
    )

    return "op_batcher"


def get_batcher_config(
    plan,
    image,
    service_name,
    el_context,
    cl_context,
    l1_config_env_vars,
    gs_batcher_private_key,
    batcher_params,
):
    cmd = [
        "op-batcher",
        "--l2-eth-rpc=" + el_context.rpc_http_url,
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--poll-interval=1s",
        "--sub-safety-margin=6",
        "--num-confirmations=1",
        "--safe-abort-nonce-too-low-count=3",
        "--resubmission-timeout=30s",
        "--rpc.addr=0.0.0.0",
        "--rpc.port=" + str(BATCHER_HTTP_PORT_NUM),
        "--rpc.enable-admin",
        "--max-channel-duration=1",
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--private-key=" + gs_batcher_private_key,
        "--data-availability-type=blobs",
    ]

    cmd += batcher_params.extra_params

    ports = get_ports()
    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )