#!/bin/sh

[ -f /tpm/dropbear.pid ] || exit 0
info "Stopping SSH server"
kill "$(cat /tmp/dropbear.pid)"
info "$(cat /tmp/dropbear.log)"
