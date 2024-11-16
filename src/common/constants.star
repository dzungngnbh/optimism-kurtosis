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

PUBLIC_NETWORKS = (
    "mainnet",
    "sepolia",
    "holesky",
)

VOLUME_SIZE = {
    "kurtosis": {
        "op_geth_volume_size": 5000,  # 5GB
        "op_reth_volume_size": 5000,  # 5GB
        "op_node_volume_size": 3000,  # 3GB
    },
}

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

GLOBAL_LOG_LEVEL = struct(
    info="info",
    error="error",
    warn="warn",
    debug="debug",
    trace="trace",
)

GENESIS_DATA_MOUNTPOINT_ON_CLIENTS = "/network-configs"

JWT_MOUNTPOINT_ON_CLIENTS = "/jwt"
JWT_MOUNT_PATH_ON_CONTAINER = JWT_MOUNTPOINT_ON_CLIENTS + "/jwtsecret"

MAX_ENR_ENTRIES = 20
MAX_ENODE_ENTRIES = 20