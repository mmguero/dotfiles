#!/data/data/com.termux/files/usr/bin/bash

wormhole --transit-helper tcp:example.org:4001 send "$@"
