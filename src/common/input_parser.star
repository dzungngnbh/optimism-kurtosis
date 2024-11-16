sanity_check = import_module("./sanity_check.star")

DEFAULT_EL_IMAGES = {
    "op-geth": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
    "op-reth": "ghcr.io/paradigmxyz/op-reth:latest",
}

# TODOs: Change :develop to stable
DEFAULT_CL_IMAGES = {
    "op-node": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
}

DEFAULT_BATCHER_IMAGES = {
    "op-batcher": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:develop",
}

DEFAULT_PROPOSER_IMAGES = {
    "op-proposer": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:develop",
}

DEFAULT_ADDITIONAL_SERVICES = ["blockscout"]

# parse network_params.yaml input file
def input_parser(plan, input_args):
    # validate input_args
    sanity_check.sanity_check(plan, input_args)

    results = parse_network_params(plan, input_args)
    results["global_log_level"] = "info"
    results["global_node_selectors"] = {}
    results["global_tolerations"] = []
    results["persistent"] = False

    return struct(
        chains=[
            struct(
                participants=[
                    struct(
                        el_type=participant["el_type"],
                        el_image=participant["el_image"],
                        el_log_level=participant["el_log_level"],
                        el_extra_env_vars=participant["el_extra_env_vars"],
                        el_extra_labels=participant["el_extra_labels"],
                        el_extra_params=participant["el_extra_params"],
                        el_tolerations=participant["el_tolerations"],
                        el_volume_size=participant["el_volume_size"],
                        el_min_cpu=participant["el_min_cpu"],
                        el_max_cpu=participant["el_max_cpu"],
                        el_min_mem=participant["el_min_mem"],
                        el_max_mem=participant["el_max_mem"],
                        cl_type=participant["cl_type"],
                        cl_image=participant["cl_image"],
                        cl_log_level=participant["cl_log_level"],
                        cl_extra_env_vars=participant["cl_extra_env_vars"],
                        cl_extra_labels=participant["cl_extra_labels"],
                        cl_extra_params=participant["cl_extra_params"],
                        cl_tolerations=participant["cl_tolerations"],
                        cl_volume_size=participant["cl_volume_size"],
                        cl_min_cpu=participant["cl_min_cpu"],
                        cl_max_cpu=participant["cl_max_cpu"],
                        cl_min_mem=participant["cl_min_mem"],
                        cl_max_mem=participant["cl_max_mem"],
                        node_selectors=participant["node_selectors"],
                        tolerations=participant["tolerations"],
                        count=participant["count"],
                    )
                    for participant in result["participants"]
                ],
                network_params=struct(
                    network=result["network_params"]["network"],
                    network_id=result["network_params"]["network_id"],
                    seconds_per_slot=result["network_params"]["seconds_per_slot"],
                    name=result["network_params"]["name"],
                    fjord_time_offset=result["network_params"]["fjord_time_offset"],
                    granite_time_offset=result["network_params"]["granite_time_offset"],
                    holocene_time_offset=result["network_params"][
                        "holocene_time_offset"
                    ],
                    interop_time_offset=result["network_params"]["interop_time_offset"],
                    fund_dev_accounts=result["network_params"]["fund_dev_accounts"],
                ),
                batcher_params=struct(
                    image=result["batcher_params"]["image"],
                    extra_params=result["batcher_params"]["extra_params"],
                ),
                additional_services=result["additional_services"],
            )
            for result in results["chains"]
        ],
        op_contract_deployer_params=struct(
            image=results["op_contract_deployer_params"]["image"],
            artifacts_url=results["op_contract_deployer_params"]["artifacts_url"],
        ),
        global_log_level=results["global_log_level"],
        global_node_selectors=results["global_node_selectors"],
        global_tolerations=results["global_tolerations"],
        persistent=results["persistent"],
    )


def parse_network_params(plan, input_args):
    results = {}
    chains = []

    seen_names = {}
    seen_network_ids = {}
    for chain in input_args.get("chains", default_chains()):
        network_params = default_network_params()
        network_params.update(chain.get("network_params", {}))

        batcher_params = default_batcher_params()
        batcher_params.update(chain.get("batcher_params", {}))

        network_name = network_params["name"]
        network_id = network_params["network_id"]

        if network_name in seen_names:
            fail("Network name {0} is duplicated".format(network_name))

        if network_id in seen_network_ids:
            fail("Network id {0} is duplicated".format(network_id))

        participants = []
        for i, p in enumerate(chain.get("participants", [default_participant()])):
            participant = default_participant()
            participant.update(p)

            el_type = participant["el_type"]
            cl_type = participant["cl_type"]
            el_image = participant["el_image"]
            if el_image == "":
                default_image = DEFAULT_EL_IMAGES.get(el_type, "")
                if default_image == "":
                    fail(
                        "{0} received an empty image name and we don't have a default for it".format(
                            el_type
                        )
                    )
                participant["el_image"] = default_image

            cl_image = participant["cl_image"]
            if cl_image == "":
                default_image = DEFAULT_CL_IMAGES.get(cl_type, "")
                if default_image == "":
                    fail(
                        "{0} received an empty image name and we don't have a default for it".format(
                            cl_type
                        )
                    )
                participant["cl_image"] = default_image

            participants.append(participant)

        result = {
            "participants": participants,
            "network_params": network_params,
            "batcher_params": batcher_params,
            "additional_services": chain.get(
                "additional_services", DEFAULT_ADDITIONAL_SERVICES
            ),
        }
        chains.append(result)

    results["chains"] = chains
    results["op_contract_deployer_params"] = default_op_contract_deployer_params()
    results["op_contract_deployer_params"].update(
        input_args.get("op_contract_deployer_params", {})
    )
    results["global_log_level"] = input_args.get("global_log_level", "info")

    return results

# TODO: refactor
def get_client_log_level_or_default(
    participant_log_level, global_log_level, client_log_levels
):
    log_level = client_log_levels.get(participant_log_level, "")
    if log_level == "":
        log_level = client_log_levels.get(global_log_level, "")
        if log_level == "":
            fail(
                "No participant log level defined, and the client log level has no mapping for global log level '{0}'".format(
                    global_log_level
                )
            )
    return log_level

def get_client_node_selectors(participant_node_selectors, global_node_selectors):
    node_selectors = {}
    node_selectors = participant_node_selectors if participant_node_selectors else {}
    if node_selectors == {}:
        node_selectors = global_node_selectors if global_node_selectors else {}

    return node_selectors

def get_client_tolerations(
    specific_container_toleration, participant_tolerations, global_tolerations
):
    toleration_list = []
    tolerations = []
    tolerations = specific_container_toleration if specific_container_toleration else []
    if not tolerations:
        tolerations = participant_tolerations if participant_tolerations else []
        if not tolerations:
            tolerations = global_tolerations if global_tolerations else []

    if tolerations != []:
        for toleration_data in tolerations:
            if toleration_data.get("toleration_seconds"):
                toleration_list.append(
                    Toleration(
                        key=toleration_data.get("key", ""),
                        value=toleration_data.get("value", ""),
                        operator=toleration_data.get("operator", ""),
                        effect=toleration_data.get("effect", ""),
                        toleration_seconds=toleration_data.get("toleration_seconds"),
                    )
                )
            # Gyani has to fix this in the future
            # https://github.com/kurtosis-tech/kurtosis/issues/2093
            else:
                toleration_list.append(
                    Toleration(
                        key=toleration_data.get("key", ""),
                        value=toleration_data.get("value", ""),
                        operator=toleration_data.get("operator", ""),
                        effect=toleration_data.get("effect", ""),
                    )
                )

    return toleration_list

def default_optimism_args():
    return {
        "chains": default_chains(),
        "op_contract_deployer_params": default_op_contract_deployer_params(),
        "global_log_level": "info",
        "global_node_selectors": {},
        "global_tolerations": [],
        "persistent": False,
    }


def default_chains():
    return [
        {
            "participants": [default_participant()],
            "network_params": default_network_params(),
            "batcher_params": default_batcher_params(),
            "additional_services": DEFAULT_ADDITIONAL_SERVICES,
        }
    ]


def default_network_params():
    return {
        "network": "kurtosis",
        "network_id": "2151908",
        "name": "op-kurtosis",
        "seconds_per_slot": 2,
        "fjord_time_offset": 0,
        "granite_time_offset": None,
        "holocene_time_offset": None,
        "interop_time_offset": None,
        "fund_dev_accounts": True,
    }


def default_batcher_params():
    return {
        "image": "",
        "extra_params": [],
    }


def default_participant():
    return {
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
        "node_selectors": {},
        "tolerations": [],
        "count": 1,
    }


def default_op_contract_deployer_params():
    return {
        "image": "mslipper/op-deployer:latest",
        "artifacts_url": "https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-4accd01f0c35c26f24d2aa71aba898dd7e5085a2ce5daadc8a84b10caf113409.tar.gz",
    }


def default_ethereum_package_network_params():
    return {
        "network_params": {
            "preset": "minimal",
            "genesis_delay": 5,
            # Preload the Arachnid CREATE2 deployer
            "additional_preloaded_contracts": json.encode(
                {
                    "0x4e59b44847b379578588920cA78FbF26c0B4956C": {
                        "balance": "0ETH",
                        "code": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
                        "storage": {},
                        "nonce": "1",
                    }
                }
            ),
        }
    }