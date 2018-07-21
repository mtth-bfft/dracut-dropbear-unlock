#!/bin/sh

SSHD_PORT=2222
if ! [ -e /tmp/dropbear.pid ]; then
	dropbear -s -j -k -p "$SSHD_PORT" -P /tmp/dropbear.pid -E >/tmp/dropbear.log 2>&1
	err=$?
	if [ $err -ne 0 ]; then
		warn "Failed to start SSH server: error code $err"
		warn "$(cat /tmp/dropbear.log)"
	fi
fi
