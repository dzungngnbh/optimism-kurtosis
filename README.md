## Welcome to Optimism Package
The default package for Optimism

```yaml
optimism_package:
  chains:
    - participants:
        - el_type: op-geth
          cl_type: op-node
        - el_type: op-reth
ethereum_package:
  network_params:
    preset: minimal
```

Please note, by default your network will be running a `minimal` preset Ethereum network. Click [here](https://github.com/ethereum/consensus-specs/blob/dev/configs/minimal.yaml) to learn more about minimal preset. You can [customize](https://github.com/ethpandaops/ethereum-package) the L1 Ethereum network by modifying the `ethereum_package` configuration.

You can also completely remove `ethereum_package` from your configuration in which case it will default to a `minimal` preset Ethereum network.

## Quickstart
#### Run with your own configuration

Kurtosis packages are parameterizable, meaning you can customize your network and its behavior to suit your needs by storing parameters in a file that you can pass in at runtime like so:

```bash
kurtosis run . --args-file network_params.yaml
```

For `--args-file` you can pass a local file path or a URL to a file.

To clean up running enclaves and data, you can run:

```bash
kurtosis clean -a
```

This will stop and remove all running enclaves and **delete all data**.

# L2 Contract deployer
The enclave will automatically deploy an optimism L2 contract on the L1 network. The contract address will be printed in the logs. You can use this contract address to interact with the L2 network.

Please refer to this Dockerfile if you want to see how the contract deployer image is built: [Dockerfile](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/op-contract-deployer/Dockerfile)


## Config
The default configuration with comments is `network_params_template.yaml`, you should copy to your own.


### Additional configuration recommendations

It is required you to launch an L1 Ethereum node to interact with the L2 network. You can use the `ethereum_package` to launch an Ethereum node. The `ethereum_package` configuration is as follows:

```yaml
optimism_package:
  chains:
    - participants:
        - el_type: op-geth
          cl_type: op-node
      additional_services:
        - blockscout
ethereum_package:
  participants:
    - el_type: geth
    - el_type: reth
  network_params:
    preset: minimal
  additional_services:
    - dora
    - blockscout
```

Additionally, you can spin up multiple L2 networks by providing a list of L2 configuration parameters like so:

```yaml
optimism_package:
  chains:
    - participants:
        - el_type: op-geth
      network_params:
        name: op-rollup-one
        network_id: "3151909"
      additional_services:
        - blockscout
    - participants:
        - el_type: op-geth
      network_params:
        name: op-rollup-two
        network_id: "3151910"
      additional_services:
        - blockscout
ethereum_package:
  participants:
    - el_type: geth
    - el_type: reth
  network_params:
    preset: minimal
  additional_services:
    - dora
    - blockscout
```
Note: if configuring multiple L2s, make sure that the `network_id` and `name` are set to differentiate networks.

### Additional configurations
Please find examples of additional configurations in the [test folder](.github/tests/).
