def new_port_spec(
    number,
    transport_protocol="TCP",
    application_protocol="http",
    wait="15s", # default wait to 15s
):
    return PortSpec(
        number=number,
        transport_protocol=transport_protocol,
        application_protocol=application_protocol,
        wait=wait,
    )

def label_maker(client, client_type, image, connected_client, extra_labels):
    labels = {
        "ethereum-package.client": client,
        "ethereum-package.client-type": client_type,
        "ethereum-package.client-image": image.replace("/", "-").replace(":", "-"),
        "ethereum-package.connected-client": connected_client,
    }
    labels.update(extra_labels)  # Add extra_labels to the labels dictionary
    return labels

def read_network_config_value(plan, network_config_file, json_file, json_path):
    mounts = {"/network-data": network_config_file}
    return read_json_value(
        plan, "/network-data/{0}.json".format(json_file), json_path, mounts
    )

DEPLOYMENT_UTILS_IMAGE = "mslipper/deployment-utils:latest"
def read_json_value(plan, json_file, json_path, mounts=None):
    run = plan.run_sh(
        description="Read JSON value",
        image=DEPLOYMENT_UTILS_IMAGE,
        files=mounts,
        run="cat {0} | jq -j '{1}'".format(json_file, json_path),
    )
    return run.output

def to_hex_chain_id(chain_id):
    out = "%x" % int(chain_id)
    pad = 64 - len(out)
    return "0x" + "0" * pad + out

def zfill_custom(value, width):
    return ("0" * (width - len(str(value)))) + str(value)
