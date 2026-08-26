#!/bin/sh
systemctl --user start hermes-gateway.service acp-relay.service
python3 $HOME/.hermes/bin/antigravity_bridge.py > /tmp/antigravity_bridge.log 2>&1 &
bridge_pid=$!
foot -a opencode-float --window-size-chars=110x45 hermes
kill $bridge_pid 2>/dev/null
systemctl --user stop hermes-gateway.service acp-relay.service
