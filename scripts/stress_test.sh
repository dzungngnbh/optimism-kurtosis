#!/usr/bin/env bash

#RPC="http://127.0.0.1:8080/anothertestt"
#jq -ncM '{method: "POST", url: "$RPC", body: "Punch!" | @base64, header: {"Content-Type": ["application/json"]}}' |
echo "stress testing http_rpc"
cat http_rpc.vegeta | vegeta attack -rate=30/s -duration=30s | tee results.bin | vegeta report