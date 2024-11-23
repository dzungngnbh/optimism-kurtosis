def _validate_participant_params(participant):
    allowed_params = [
        "el_type", "el_image", "el_log_level", "el_extra_env_vars",
        "el_extra_labels", "el_extra_params", "el_tolerations",
        "el_volume_size", "el_min_cpu", "el_max_cpu", "el_min_mem",
        "el_max_mem", "cl_type", "cl_image", "cl_log_level",
        "cl_extra_env_vars", "cl_extra_labels", "cl_extra_params",
        "cl_tolerations", "cl_volume_size", "cl_min_cpu", "cl_max_cpu",
        "cl_min_mem", "cl_max_mem", "node_selectors", "tolerations", "count"
    ]

    for key in participant:
        if key not in allowed_params:
            fail("Invalid participant parameter: %s" % key)

def _validate_network_params(network_params):
    allowed_params = [
        "network", "network_id", "seconds_per_slot", "name",
        "fjord_time_offset", "granite_time_offset", "holocene_time_offset",
        "interop_time_offset", "fund_dev_accounts"
    ]

    if not network_params:
        return

    for key in network_params:
        if key not in allowed_params:
            fail("Invalid network parameter: %s" % key)

def _validate_batcher_params(batcher_params):
    allowed_params = ["image", "extra_params"]

    if not batcher_params:
        return

    for key in batcher_params:
        if key not in allowed_params:
            fail("Invalid batcher parameter: %s" % key)

def _validate_additional_services(services):
    allowed_services = ["blockscout"]

    if not services:
        return

    for service in services:
        if service not in allowed_services:
            fail("Invalid additional service: %s" % service)

def _validate_chain(chain):
    allowed_chain_params = [
        "participants",
        "additional_services",
        "network_params",
        "batcher_params",
        "op_contract_deployer_params"
    ]

    # Validate chain level parameters
    for key in chain:
        if key not in allowed_chain_params:
            fail("Invalid chain parameter: %s" % key)

    # Validate participants
    if "participants" in chain:
        for participant in chain["participants"]:
            _validate_participant_params(participant)

    # Validate network params
    if "network_params" in chain:
        _validate_network_params(chain["network_params"])

    # Validate batcher params
    if "batcher_params" in chain:
        _validate_batcher_params(chain["batcher_params"])

    # Validate additional services
    if "additional_services" in chain:
        _validate_additional_services(chain["additional_services"])

def sanity_check(plan, config):
    """
    Main entry point for configuration validation
    Args:
        plan: The execution plan
        config: The configuration dictionary to validate
    """
    if type(config) != "dict":
        fail("Configuration must be a dictionary")

    # Validate root level parameters
    allowed_root_params = [
        "chains",
        "op_contract_deployer_params",
        "global_log_level",
        "global_node_selectors",
        "global_tolerations",
        "persistent"
    ]

    for key in config:
        if key not in allowed_root_params:
            fail("Invalid root parameter: %s" % key)

    # Validate chains
    if "chains" not in config:
        fail("Configuration must include 'chains'")

    if type(config["chains"]) != "list":
        fail("'chains' must be a list")

    # Validate each chain
    for chain in config["chains"]:
        _validate_chain(chain)

    # Validate contract deployer params if present
    if "op_contract_deployer_params" in config:
        allowed_deployer_params = ["image", "artifacts_url"]
        for key in config["op_contract_deployer_params"]:
            if key not in allowed_deployer_params:
                fail("Invalid contract deployer parameter: %s" % key)

    plan.print("[PASSED] Sanity check for OP package.")