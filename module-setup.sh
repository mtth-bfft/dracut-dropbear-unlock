#!/bin/bash

# Copyright (c) 2018 Matthieu Buffet
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

HOSTCONF="/etc/dropbear-initramfs"
INITRDCONF="/etc/dropbear"
ETCKEYS="/etc/ssh/authorized_keys"
ROOTKEYS="/root/.ssh/authorized_keys"
AUTHKEYS="$HOSTCONF/authorized_keys"

gethostkeys () {
	find "$HOSTCONF" -name 'dropbear_*_host_key' 2>/dev/null
}

check () {
	if ! require_binaries systemd-tty-ask-password-agent; then
		echo "This module only works with systemd's encrypt hook in initramfs."
		return 1
	elif ! require_binaries dropbear; then
		echo "Please install dropbear first."
		return 1
	elif [[ -z "$(gethostkeys)" ]] && ! require_binaries dropbearkey; then
		echo "Please generate a server key in $HOSTCONF first, or install dropbearkey first."
		return 1
	elif ! [ -s "$AUTHKEYS" ] && ! [ -s "$ETCKEYS" ] && ! [ -s "$ROOTKEYS" ]; then
		echo "Please setup authorized SSH keys in $ETCKEYS, $ROOTKEYS or $AUTHKEYS first."
		return 1
	fi
	return 255
}

depends () {
	echo "network crypt"
	return 0
}

install () {
	if [ -z "$(gethostkeys)" ]; then
		echo "You haven't generated SSH host keys in $HOSTCONF, generating a 4096-bit RSA one..."
		echo "WARNING: This key will be stored unencrypted in your initramfs."
		echo "         Do *not* reuse it anywhere else"
		mkdir -p "$HOSTCONF/"
		dropbearkey -t rsa -s 4096 -f "$HOSTCONF/dropbear_rsa_host_key"
	fi
	if ! [ -s "$AUTHKEYS" ] && [ -s "$ETCKEYS" ]; then
		echo "You haven't configured authorized SSH keys in $AUTHKEYS, using $ETCKEYS ones"
		cp "$ETCKEYS" "$AUTHKEYS"
	elif ! [ -s "$AUTHKEYS" ] && [ -s "$ROOTKEYS" ]; then
		echo "You haven't configured authorized SSH keys in $AUTHKEYS, using root's ones"
		cp "$ROOTKEYS" "$AUTHKEYS"
	fi
	mkdir -p "${initdir}/var/log/"
	touch "${initdir}/var/log/lastlog"
	inst_binary dropbear
	for hostkey in $(gethostkeys); do
		inst "$hostkey" "$INITRDCONF/$(basename "$hostkey")"
	done
	sed -r -i -e 's#^ssh#no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="/usr/bin/systemd-tty-ask-password-agent --watch" ssh#' "$AUTHKEYS"
	inst "$AUTHKEYS" "$ROOTKEYS"
	inst_hook initqueue 20 "$moddir/start.sh"
	inst_hook cleanup 05 "$moddir/stop.sh"
}
