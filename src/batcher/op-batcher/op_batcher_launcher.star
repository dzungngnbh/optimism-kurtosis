utils = import_module("../../common/utils.star")
constants = import_module("../../common/constants.star")

BATCHER_DATA_DIR = "/data/op-batcher/op-batcher-data"
HTTP_PORT = 8548
PORTS = {"http": utils.new_port_spec(HTTP_PORT)}

def run(
        plan,
        service_name,
        image,
        el_context,
        cl_context,
        l1_config_env_vars,
        gs_batcher_private_key,
        batcher_params,
):
    """
    Launches an op-batcher service in the Kurtosis environment.

    Args:
        plan: The Kurtosis plan object
        service_name: Name for the batcher service
        image: Docker image for the batcher
        el_context: Execution layer context
        cl_context: Consensus layer context
        l1_config_env_vars: Layer 1 configuration environment variables
        gs_batcher_private_key: Batcher private key
        batcher_params: Additional batcher parameters

    Returns:
        str: HTTP URL of the launched batcher service
    """
    config = _create_service_config(
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
    return _build_http_url(batcher_service)

def _create_service_config(
        plan,
        image,
        service_name,
        el_context,
        cl_context,
        l1_config_env_vars,
        gs_batcher_private_key,
        batcher_params,
):
    cmd = _build_batcher_command(
        el_context,
        cl_context,
        l1_config_env_vars,
        gs_batcher_private_key,
        HTTP_PORT,
    )
    cmd.extend(batcher_params.extra_params)

    return ServiceConfig(
        image=image,
        ports=PORTS,
        cmd=cmd,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )

def _build_batcher_command(
        el_context,
        cl_context,
        l1_config_env_vars,
        gs_batcher_private_key,
        port,
):
    return [
        "op-batcher",
        "--l2-eth-rpc=" + el_context.rpc_http_url,
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--poll-interval=1s",
        "--sub-safety-margin=6",
        "--num-confirmations=1",
        "--safe-abort-nonce-too-low-count=3",
        "--resubmission-timeout=30s",
        "--rpc.addr=0.0.0.0",
        "--rpc.port=" + str(port),
        "--rpc.enable-admin",
        "--max-channel-duration=1",
        "--l1-eth-rpc=" + l1_config_env_vars['L1_RPC_URL'],
        "--private-key=" + gs_batcher_private_key,
        "--data-availability-type=blobs",
    ]

def _build_http_url(service):
    http_port = service.ports["http"]
    return "http://{0}:{1}".format(service.ip_address, http_port.number)