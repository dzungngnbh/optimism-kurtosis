# Constants for JSON-RPC request
_NODE_INFO_REQUEST = {
    "method": "admin_nodeInfo",
    "params": [],
    "id": 1,
    "jsonrpc": "2.0"
}

# JQ path for extracting enode without query parameters
_ENODE_EXTRACT_PATH = ".result.enode | split(\"?\") | .[0]"

def get_enode_enr_for_node(plan, service_name, port_id):
    """Gets both enode and ENR information for a node via admin_nodeInfo.

    Args:
        plan: Kurtosis execution plan object
        service_name: Name of the service running the node
        port_id: Port identifier for the RPC endpoint

    Returns:
        tuple: (enode_address, enr_record) for the node
    """
    recipe = PostHttpRequestRecipe(
        endpoint="",
        body=json.encode(_NODE_INFO_REQUEST),
        content_type="application/json",
        port_id=port_id,
        extract={
            "enode": _ENODE_EXTRACT_PATH,
            "enr": ".result.enr",
        },
    )

    response = _wait_for_node_info(plan, recipe, service_name)
    return (response["extract.enode"], response["extract.enr"])


def get_enode_for_node(plan, service_name, port_id):
    """Gets only the enode information for a node via admin_nodeInfo.

    Args:
        plan: Kurtosis execution plan object
        service_name: Name of the service running the node
        port_id: Port identifier for the RPC endpoint

    Returns:
        str: enode address for the node
    """
    recipe = PostHttpRequestRecipe(
        endpoint="",
        body=json.encode(_NODE_INFO_REQUEST),
        content_type="application/json",
        port_id=port_id,
        extract={
            "enode": _ENODE_EXTRACT_PATH,
        },
    )

    response = _wait_for_node_info(plan, recipe, service_name)
    return response["extract.enode"]


def _wait_for_node_info(plan, recipe, service_name):
    """Waits for node info to become available.

    Args:
        plan: Kurtosis execution plan
        recipe: PostHttpRequestRecipe to execute
        service_name: Name of the service to query

    Returns:
        dict: Response containing extracted node information
    """
    return plan.wait(
        recipe=recipe,
        field="extract.enode",
        assertion="!=",
        target_value="",
        timeout="15m",
        service_name=service_name,
    )
