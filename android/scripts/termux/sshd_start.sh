#!/data/data/com.termux/files/usr/bin/bash

pidof sshd >/dev/null 2>&1 || (echo "Starting sshd" && sshd -D)
