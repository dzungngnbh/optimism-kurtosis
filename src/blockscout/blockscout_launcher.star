postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
utils = import_module("../common/utils.star")

IMAGE_NAME_BLOCKSCOUT = "blockscout/blockscout-optimism:6.8.0"
IMAGE_NAME_BLOCKSCOUT_VERIF = "ghcr.io/blockscout/smart-contract-verifier:v1.9.0"
SERVICE_NAME = "op-blockscout"

HTTP_PORT_NUMBER = 4000
HTTP_PORT_NUMBER_VERIF = 8050

BLOCKSCOUT_MIN_CPU = 100
BLOCKSCOUT_MAX_CPU = 1000
BLOCKSCOUT_MIN_MEMORY = 1024
BLOCKSCOUT_MAX_MEMORY = 2048

BLOCKSCOUT_VERIF_MIN_CPU = 10
BLOCKSCOUT_VERIF_MAX_CPU = 1000
BLOCKSCOUT_VERIF_MIN_MEMORY = 10
BLOCKSCOUT_VERIF_MAX_MEMORY = 1024

PORTS = {"http": utils.new_port_spec(HTTP_PORT_NUMBER)}
VERIF_PORTS = {"http": utils.new_port_spec(HTTP_PORT_NUMBER_VERIF)}

def run(
        plan,
        l2_services_suffix,
        l1_el_context,
        l2_el_context,
        l2_network_name,
        deployment_output,
        network_id,
):
    """
    Launches Blockscout explorer and its dependencies for an L2 network.

    Args:
        plan: Kurtosis execution plan
        l2_services_suffix: Suffix for L2 service names
        l1_el_context: L1 execution layer context
        l2_el_context: L2 execution layer context
        l2_network_name: Name of the L2 network
        deployment_output: Deployment configuration output
        network_id: Network identifier

    Returns:
        str: URL of the launched Blockscout instance
    """
    rollup_config = _get_rollup_config(plan, deployment_output, network_id)
    postgres_output = _launch_postgres(plan, l2_services_suffix)
    verifier_url = _launch_verifier(plan, l2_services_suffix)

    blockscout_service = _launch_blockscout(
        plan,
        l2_services_suffix,
        postgres_output,
        l1_el_context,
        l2_el_context,
        verifier_url,
        l2_network_name,
        rollup_config,
    )

    return _build_blockscout_url(blockscout_service)

def _get_rollup_config(plan, deployment_output, network_id):
    rollup_filename = "rollup-{0}".format(network_id)
    portal_address = utils.read_network_config_value(
        plan, deployment_output, rollup_filename, ".deposit_contract_address"
    )
    l1_deposit_start_block = utils.read_network_config_value(
        plan, deployment_output, rollup_filename, ".genesis.l1.number"
    )

    return {
        "INDEXER_OPTIMISM_L1_PORTAL_CONTRACT": portal_address,
        "INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK": l1_deposit_start_block,
        "INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK": l1_deposit_start_block,
        "INDEXER_OPTIMISM_L1_BATCH_START_BLOCK": l1_deposit_start_block,
        "INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT": "0x0000000000000000000000000000000000000000",
    }

def _launch_postgres(plan, l2_services_suffix):
    return postgres.run(
        plan,
        service_name="{0}-postgres{1}".format(SERVICE_NAME, l2_services_suffix),
        database="blockscout",
        extra_configs=["max_connections=1000"],
    )

def _launch_verifier(plan, l2_services_suffix):
    verifier_service_name = "{0}-verif{1}".format(SERVICE_NAME, l2_services_suffix)
    verifier_service = plan.add_service(
        verifier_service_name,
        ServiceConfig(
            image=IMAGE_NAME_BLOCKSCOUT_VERIF,
            ports=VERIF_PORTS,
            env_vars={
                "SMART_CONTRACT_VERIFIER__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(
                    HTTP_PORT_NUMBER_VERIF
                )
            },
            min_cpu=BLOCKSCOUT_VERIF_MIN_CPU,
            max_cpu=BLOCKSCOUT_VERIF_MAX_CPU,
            min_memory=BLOCKSCOUT_VERIF_MIN_MEMORY,
            max_memory=BLOCKSCOUT_VERIF_MAX_MEMORY,
        ),
    )
    return "http://{}:{}".format(verifier_service.hostname, verifier_service.ports["http"].number)

def _get_optimism_env_vars(l1_el_context, verif_url, additional_env_vars):
    return {
        # Required vars
        "CHAIN_TYPE": "optimism",
        "INDEXER_OPTIMISM_L1_RPC": l1_el_context.rpc_http_url,
        "INDEXER_OPTIMISM_L1_BATCH_INBOX": "0xff00000000000000000000000000000000042069",
        "INDEXER_OPTIMISM_L1_BATCH_SUBMITTER": "0x776463f498A63a42Ac1AFc7c64a4e5A9ccBB4d32",
        "INDEXER_OPTIMISM_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL": verif_url + "/blobs",
        "INDEXER_OPTIMISM_L2_MESSAGE_PASSER_CONTRACT": "0xC0D3C0d3C0d3c0d3C0d3C0D3c0D3c0d3c0D30016",

        # Optional vars with defaults
        "INDEXER_OPTIMISM_L1_BATCH_BLOCKS_CHUNK_SIZE": "4",
        "INDEXER_OPTIMISM_L2_BATCH_GENESIS_BLOCK_NUMBER": "0",
        "INDEXER_OPTIMISM_L1_OUTPUT_ROOTS_START_BLOCK": "0",
        "INDEXER_OPTIMISM_L1_DEPOSITS_BATCH_SIZE": "500",
        "INDEXER_OPTIMISM_L2_WITHDRAWALS_START_BLOCK": "1",

        # Configurable vars (set via additional_env_vars)
        # INDEXER_OPTIMISM_L1_PORTAL_CONTRACT
        # INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK
        # INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK
        # INDEXER_OPTIMISM_L1_BATCH_START_BLOCK
        # INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT
    } | additional_env_vars

def _get_base_env_vars(l2_el_context, database_url, verif_url, l2_network_name):
    return {
        "ETHEREUM_JSONRPC_VARIANT": "geth",
        "ETHEREUM_JSONRPC_HTTP_URL": l2_el_context.rpc_http_url,
        "ETHEREUM_JSONRPC_TRACE_URL": l2_el_context.rpc_http_url,
        "DATABASE_URL": database_url,
        "COIN": "opETH",
        "MICROSERVICE_SC_VERIFIER_ENABLED": "true",
        "MICROSERVICE_SC_VERIFIER_URL": verif_url,
        "MICROSERVICE_SC_VERIFIER_TYPE": "sc_verifier",
        "INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER": "true",
        "ECTO_USE_SSL": "false",
        "NETWORK": l2_network_name,
        "SUBNETWORK": l2_network_name,
        "API_V2_ENABLED": "true",
        "PORT": str(HTTP_PORT_NUMBER),
        "SECRET_KEY_BASE": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
    }

def _launch_blockscout(
        plan,
        l2_services_suffix,
        postgres_output,
        l1_el_context,
        l2_el_context,
        verif_url,
        l2_network_name,
        rollup_config,
):
    config = ServiceConfig(
        image=IMAGE_NAME_BLOCKSCOUT,
        ports=PORTS,
        cmd=[
            "/bin/sh",
            "-c",
            'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start',
        ],
        env_vars=_get_base_env_vars(l2_el_context, _build_database_url(postgres_output), verif_url, l2_network_name) |
                 _get_optimism_env_vars(l1_el_context, verif_url, rollup_config),
        min_cpu=BLOCKSCOUT_MIN_CPU,
        max_cpu=BLOCKSCOUT_MAX_CPU,
        min_memory=BLOCKSCOUT_MIN_MEMORY,
        max_memory=BLOCKSCOUT_MAX_MEMORY,
    )

    service_name = "{0}{1}".format(SERVICE_NAME, l2_services_suffix)
    blockscout_service = plan.add_service(service_name, config)
    plan.print(blockscout_service)
    return blockscout_service

def _build_database_url(postgres_output):
    return "postgresql://{user}:{password}@{hostname}:{port}/{database}".format(
        user=postgres_output.user,
        password=postgres_output.password,
        hostname=postgres_output.service.hostname,
        port=postgres_output.port.number,
        database=postgres_output.database,
    )

def _build_blockscout_url(service):
    return "http://{}:{}".format(service.hostname, service.ports["http"].number)
