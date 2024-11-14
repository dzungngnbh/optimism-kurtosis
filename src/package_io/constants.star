EL_TYPE = struct(
    op_geth="op-geth",
    op_reth="op-reth",
)

CL_TYPE = struct(
    op_node="op-node",
)

CLIENT_TYPES = struct(
    el="execution",
    cl="beacon",
)

VOLUME_SIZE = {
    "kurtosis": {
        "op_geth_volume_size": 5000,  # 5GB
        "op_reth_volume_size": 5000,  # 5GB
        "op_node_volume_size": 3000,  # 3GB
    },
}

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"