CLIENT_TYPES = struct(
    el="execution",
    cl="beacon",
)

PUBLIC_NETWORKS = (
    "mainnet",
    "sepolia",
    "holesky",
)

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

GLOBAL_LOG_LEVEL = struct(
    info="info",
    error="error",
    warn="warn",
    debug="debug",
    trace="trace",
)

GENESIS_DATA_MOUNTPOINT_ON_CLIENTS = "/network-configs"
GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER = GENESIS_DATA_MOUNTPOINT_ON_CLIENTS

JWT_MOUNTPOINT_ON_CLIENTS = "/jwt"
JWT_MOUNT_PATH_ON_CONTAINER = JWT_MOUNTPOINT_ON_CLIENTS + "/jwtsecret"

MAX_ENR_ENTRIES = 20
MAX_ENODE_ENTRIES = 20