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