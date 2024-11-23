sanity_check = import_module("./sanity_check.star")

OP_VERSION = "latest"

BASE_OP_DOCKER_PATH = "us-docker.pkg.dev/oplabs-tools-artifacts/images"

EL_IMAGES = {
    "op-geth": "{0}/op-geth:{1}".format(BASE_OP_DOCKER_PATH, OP_VERSION),
    "op-reth": "ghcr.io/paradigmxyz/op-reth:latest",
}

CL_IMAGES = {
    "op-node": "{0}/op-node:{1}".format(BASE_OP_DOCKER_PATH, OP_VERSION),
}

BATCHER_IMAGES = {
    "op-batcher": "{0}/op-batcher:{1}".format(BASE_OP_DOCKER_PATH, OP_VERSION),
}

PROPOSER_IMAGES = {
    "op-proposer": "{0}/op-proposer:{1}".format(BASE_OP_DOCKER_PATH, OP_VERSION),
}

ADDITIONAL_SERVICES = ["blockscout"]

def input_parser(plan, input_args):
    """Parse and validate input arguments for chain configuration.

    Args:
        plan: The execution plan
        input_args: Raw input arguments to parse

    Returns:
        struct: Parsed and validated configuration
    """
    # Validate input arguments
    sanity_check.sanity_check(plan, input_args)

    # Parse network parameters
    results = parse_network_params(plan, input_args)

    # Set global defaults
    results = _set_global_defaults(results)

    return _create_chain_struct(results)

def _set_global_defaults(results):
    """Set global default values for configuration.

    Args:
        results: Parsed configuration dictionary

    Returns:
        dict: Configuration with global defaults
    """
    results["global_log_level"] = "info"
    results["global_node_selectors"] = {}
    results["global_tolerations"] = []
    results["persistent"] = False
    return results

def _create_chain_struct(results):
    """Create a struct containing chain configuration.

    Args:
        results: Parsed configuration dictionary

    Returns:
        struct: Chain configuration struct
    """
    return struct(
        chains = [
            _create_chain_config(result)
            for result in results["chains"]
        ],
        op_contract_deployer_params = _create_deployer_params(results),
        global_log_level = results["global_log_level"],
        global_node_selectors = results["global_node_selectors"],
        global_tolerations = results["global_tolerations"],
        persistent = results["persistent"],
    )

def _create_chain_config(result):
    """Create a struct for a single chain configuration.

    Args:
        result: Single chain configuration dictionary

    Returns:
        struct: Chain configuration struct
    """
    return struct(
        participants = [
            _create_participant_struct(participant)
            for participant in result["participants"]
        ],
        network_params = _create_network_params_struct(result["network_params"]),
        batcher_params = _create_batcher_params_struct(result["batcher_params"]),
        additional_services = result["additional_services"],
    )

def _create_participant_struct(participant):
    """Create a struct for participant configuration.

    Args:
        participant: Participant configuration dictionary

    Returns:
        struct: Participant configuration struct
    """
    return struct(
        el_type = participant["el_type"],
        el_image = participant["el_image"],
        el_log_level = participant["el_log_level"],
        el_extra_env_vars = participant["el_extra_env_vars"],
        el_extra_labels = participant["el_extra_labels"],
        el_extra_params = participant["el_extra_params"],
        el_tolerations = participant["el_tolerations"],
        el_volume_size = participant["el_volume_size"],
        el_min_cpu = participant["el_min_cpu"],
        el_max_cpu = participant["el_max_cpu"],
        el_min_mem = participant["el_min_mem"],
        el_max_mem = participant["el_max_mem"],
        cl_type = participant["cl_type"],
        cl_image = participant["cl_image"],
        cl_log_level = participant["cl_log_level"],
        cl_extra_env_vars = participant["cl_extra_env_vars"],
        cl_extra_labels = participant["cl_extra_labels"],
        cl_extra_params = participant["cl_extra_params"],
        cl_tolerations = participant["cl_tolerations"],
        cl_volume_size = participant["cl_volume_size"],
        cl_min_cpu = participant["cl_min_cpu"],
        cl_max_cpu = participant["cl_max_cpu"],
        cl_min_mem = participant["cl_min_mem"],
        cl_max_mem = participant["cl_max_mem"],
        node_selectors = participant["node_selectors"],
        tolerations = participant["tolerations"],
        count = participant["count"],
    )

def _create_network_params_struct(network_params):
    """Create a struct for network parameters.

    Args:
        network_params: Network parameters dictionary

    Returns:
        struct: Network parameters struct
    """
    return struct(
        network = network_params["network"],
        network_id = network_params["network_id"],
        seconds_per_slot = network_params["seconds_per_slot"],
        name = network_params["name"],
        fjord_time_offset = network_params["fjord_time_offset"],
        granite_time_offset = network_params["granite_time_offset"],
        holocene_time_offset = network_params["holocene_time_offset"],
        interop_time_offset = network_params["interop_time_offset"],
        fund_dev_accounts = network_params["fund_dev_accounts"],
    )

def _create_batcher_params_struct(batcher_params):
    """Create a struct for batcher parameters.

    Args:
        batcher_params: Batcher parameters dictionary

    Returns:
        struct: Batcher parameters struct
    """
    return struct(
        image = batcher_params["image"],
        extra_params = batcher_params["extra_params"],
    )

def _create_deployer_params(results):
    """Create a struct for deployer parameters.

    Args:
        results: Configuration dictionary containing deployer parameters

    Returns:
        struct: Deployer parameters struct
    """
    return struct(
        image = results["op_contract_deployer_params"]["image"],
        artifacts_url = results["op_contract_deployer_params"]["artifacts_url"],
    )

def parse_network_params(plan, input_args):
    """Parse and validate network parameters from input arguments.

    Args:
        plan: The execution plan
        input_args: Dictionary containing chain configurations and parameters

    Returns:
        dict: Parsed and validated network configuration
    """
    return {
        "chains": _parse_chain_configurations(input_args),
        "op_contract_deployer_params": _parse_deployer_params(input_args),
        "global_log_level": input_args.get("global_log_level", "info")
    }

def _parse_chain_configurations(input_args):
    """Parse and validate chain configurations.

    Args:
        input_args: Dictionary containing chain configurations

    Returns:
        list: List of parsed chain configurations
    """
    seen_names = {}
    seen_network_ids = {}
    chains = []

    for chain in input_args.get("chains", default_chains()):
        parsed_chain = _parse_single_chain(chain, seen_names, seen_network_ids)
        chains.append(parsed_chain)

    return chains

def _parse_single_chain(chain, seen_names, seen_network_ids):
    """Parse a single chain configuration and validate its uniqueness.

    Args:
        chain: Single chain configuration
        seen_names: Dictionary of previously seen network names
        seen_network_ids: Dictionary of previously seen network IDs

    Returns:
        dict: Parsed chain configuration

    Fails:
        If network name or ID is duplicated
    """
    network_params = _parse_network_params(chain)
    _validate_network_uniqueness(network_params, seen_names, seen_network_ids)

    return {
        "participants": _parse_chain_participants(chain),
        "network_params": network_params,
        "batcher_params": _parse_batcher_params(chain),
        "additional_services": chain.get("additional_services", ADDITIONAL_SERVICES)
    }

def _parse_network_params(chain):
    """Parse network parameters with defaults.

    Args:
        chain: Chain configuration

    Returns:
        dict: Network parameters with defaults applied
    """
    network_params = default_network_params()
    network_params.update(chain.get("network_params", {}))
    return network_params

def _validate_network_uniqueness(network_params, seen_names, seen_network_ids):
    """Validate network name and ID uniqueness.

    Args:
        network_params: Network parameters to validate
        seen_names: Dictionary of previously seen network names
        seen_network_ids: Dictionary of previously seen network IDs

    Fails:
        If network name or ID is duplicated
    """
    network_name = network_params["name"]
    network_id = network_params["network_id"]

    if network_name in seen_names:
        fail("Network name {0} is duplicated".format(network_name))
    if network_id in seen_network_ids:
        fail("Network id {0} is duplicated".format(network_id))

    seen_names[network_name] = True
    seen_network_ids[network_id] = True

def _parse_chain_participants(chain):
    """Parse chain participants with defaults.

    Args:
        chain: Chain configuration

    Returns:
        list: List of parsed participant configurations
    """
    participants = []
    for participant in chain.get("participants", [default_participant()]):
        parsed_participant = _parse_participant(participant)
        participants.append(parsed_participant)
    return participants

def _parse_participant(participant):
    """Parse a single participant configuration.

    Args:
        participant: Participant configuration

    Returns:
        dict: Parsed participant configuration
    """
    parsed = default_participant()
    parsed.update(participant)

    _set_default_client_image(parsed, "el")
    _set_default_client_image(parsed, "cl")

    return parsed

def _set_default_client_image(participant, client_type):
    """Set default image for a client type if not specified.

    Args:
        participant: Participant configuration
        client_type: Type of client ("el" or "cl")
    """
    image_key = client_type + "_image"
    type_key = client_type + "_type"
    default_images = EL_IMAGES if client_type == "el" else CL_IMAGES

    if participant[image_key] == "":
        client_type_value = participant[type_key]
        default_image = default_images.get(client_type_value, "")
        if default_image == "":
            fail(
                "{0} received an empty image name and we don't have a default for it".format(
                    client_type_value
                )
            )
        participant[image_key] = default_image

def _parse_batcher_params(chain):
    """Parse batcher parameters with defaults.

    Args:
        chain: Chain configuration

    Returns:
        dict: Parsed batcher parameters
    """
    batcher_params = default_batcher_params()
    batcher_params.update(chain.get("batcher_params", {}))
    return batcher_params

def _parse_deployer_params(input_args):
    """Parse contract deployer parameters with defaults.

    Args:
        input_args: Input arguments containing deployer parameters

    Returns:
        dict: Parsed deployer parameters
    """
    deployer_params = default_op_contract_deployer_params()
    deployer_params.update(input_args.get("op_contract_deployer_params", {}))
    return deployer_params


def get_client_log_level_or_default(
    participant_log_level, global_log_level, client_log_levels
):
    # Try participant-specific log level first
    log_level = client_log_levels.get(participant_log_level)
    if log_level:
        return log_level

    # Fall back to global log level
    log_level = client_log_levels.get(global_log_level)
    if log_level:
        return log_level

    # No valid log level found
    fail(
        "No participant log level defined, and the client log level has no mapping for global log level '{0}'".format(
            global_log_level
        )
    )

def get_client_node_selectors(participant_node_selectors, global_node_selectors):
    """Get node selectors with priority given to participant-specific selectors."""
    if participant_node_selectors:
        return participant_node_selectors

    if global_node_selectors:
        return global_node_selectors

    return {}

def get_client_tolerations(specific_container_toleration, participant_tolerations, global_tolerations):
    """Get tolerations with priority hierarchy: specific > participant > global.

    Args:
        specific_container_toleration: Tolerations specific to a container
        participant_tolerations: Tolerations specific to a participant
        global_tolerations: Default tolerations for all participants

    Returns:
        list: List of Toleration objects based on priority hierarchy
    """
    tolerations = (specific_container_toleration or
                   participant_tolerations or
                   global_tolerations or
                   [])

    return _create_toleration_list(tolerations)

def _create_toleration_list(tolerations):
    """Create list of Toleration objects from toleration data.

    Args:
        tolerations: List of toleration configurations

    Returns:
        list: List of Toleration objects
    """
    toleration_list = []

    for toleration_data in tolerations:
        toleration = _create_single_toleration(toleration_data)
        toleration_list.append(toleration)

    return toleration_list

def _create_single_toleration(toleration_data):
    """Create a single Toleration object from configuration data.

    Args:
        toleration_data: Dictionary containing toleration configuration

    Returns:
        Toleration: Configured toleration object
    """
    base_args = {
        "key": toleration_data.get("key", ""),
        "value": toleration_data.get("value", ""),
        "operator": toleration_data.get("operator", ""),
        "effect": toleration_data.get("effect", ""),
    }

    if "toleration_seconds" in toleration_data:
        base_args["toleration_seconds"] = toleration_data["toleration_seconds"]

    return Toleration(**base_args)

# -------------------- Default args

def default_optimism_args():
    """Get default configuration for Optimism network setup.

    Returns:
        dict: Default configuration with chains and global parameters
    """
    return {
        "chains": default_chains(),
        "op_contract_deployer_params": default_op_contract_deployer_params(),
        "global_log_level": "info",
        "global_node_selectors": {},
        "global_tolerations": [],
        "persistent": False,
    }

def default_chains():
    """Get default chain configuration.

    Returns:
        list: List containing default chain configuration
    """
    return [{
        "participants": [default_participant()],
        "network_params": default_network_params(),
        "batcher_params": default_batcher_params(),
        "additional_services": ADDITIONAL_SERVICES,
    }]

def default_network_params():
    """Get default network parameters.

    Returns:
        dict: Default network configuration parameters
    """
    return {
        "network": "kurtosis",
        "network_id": "2151908",
        "name": "op-kurtosis",
        "seconds_per_slot": 2,
        "fjord_time_offset": 0,
        "granite_time_offset": None,
        "holocene_time_offset": None, "interop_time_offset": None, "fund_dev_accounts": True,
    }

def default_batcher_params():
    """Get default batcher parameters.

    Returns:
        dict: Default batcher configuration
    """
    return {
        "image": "",
        "extra_params": [],
    }

def default_participant():
    """Get default participant configuration.

    Returns:
        dict: Default participant settings for execution and consensus layers
    """
    return {
        # Execution Layer (el) settings
        "el_type": "op-geth",
        "el_image": "",
        "el_log_level": "",
        "el_extra_env_vars": {},
        "el_extra_labels": {},
        "el_extra_params": [],
        "el_tolerations": [],
        "el_volume_size": 0,
        "el_min_cpu": 0,
        "el_max_cpu": 0,
        "el_min_mem": 0,
        "el_max_mem": 0,

        # Consensus Layer (cl) settings
        "cl_type": "op-node",
        "cl_image": "",
        "cl_log_level": "",
        "cl_extra_env_vars": {},
        "cl_extra_labels": {},
        "cl_extra_params": [],
        "cl_tolerations": [],
        "cl_volume_size": 0,
        "cl_min_cpu": 0,
        "cl_max_cpu": 0,
        "cl_min_mem": 0,
        "cl_max_mem": 0,

        # General settings
        "node_selectors": {},
        "tolerations": [],
        "count": 1,
    }

def default_op_contract_deployer_params():
    """Get default contract deployer parameters.

    Returns:
        dict: Default contract deployer configuration
    """
    return {
        "image": "mslipper/op-deployer:latest",
        "artifacts_url": "https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-4accd01f0c35c26f24d2aa71aba898dd7e5085a2ce5daadc8a84b10caf113409.tar.gz",
    }

def default_ethereum_package_network_params():
    """Get default Ethereum package network parameters.

    Returns:
        dict: Network parameters with CREATE2 deployer configuration
    """
    return {
        "network_params": {
            "preset": "minimal",
            "genesis_delay": 5,
            "additional_preloaded_contracts": _get_create2_deployer_config(),
        }
    }

def _get_create2_deployer_config():
    """Get CREATE2 deployer contract configuration.

    Returns:
        str: JSON-encoded configuration for the CREATE2 deployer contract
    """
    create2_config = {
        "0x4e59b44847b379578588920cA78FbF26c0B4956C": {
            "balance": "0ETH",
            "code": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
            "storage": {},
            "nonce": "1",
        }
    }

    return json.encode(create2_config)
