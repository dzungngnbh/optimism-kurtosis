## Welcome to Gelato Optimism Kurtosis
This deploys full L1 and op-stack testnet on a node.

## Default configuration
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

## How does this run
The flow is to push the whole code base to a node with kurtosis installed and we will provision the node with the command `make install`
