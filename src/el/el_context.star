def new(
        client_name,
        enode,
        ip_addr,
        rpc_port_num,
        ws_port_num,
        engine_rpc_port_num,
        rpc_http_url,
        ws_url="",
        enr="",
        service_name="",
        el_metrics_info=None,
):
    """Creates a new Execution Layer context with the specified parameters.

    Args:
        client_name: Name of the client implementation.
        enode: enode identifier for the node.
        ip_addr: IP address of the node.
        rpc_port_num: Port number for RPC connections.
        ws_port_num: Port number for WebSocket connections.
        engine_rpc_port_num: Port number for engine RPC.
        rpc_http_url: HTTP URL for RPC endpoint.
        ws_url: WebSocket URL (optional).
        enr: ENR string (optional).
        service_name: Name of the service (optional).
        el_metrics_info: Metrics information (optional).

    Returns:
        A struct containing the execution layer context configuration.
    """
    return struct(
        client_name=client_name,
        enode=enode,
        ip_addr=ip_addr,
        rpc_port_num=rpc_port_num,
        ws_port_num=ws_port_num,
        engine_rpc_port_num=engine_rpc_port_num,
        rpc_http_url=rpc_http_url,
        ws_url=ws_url,
        enr=enr,
        service_name=service_name,
        el_metrics_info=el_metrics_info,
    )
