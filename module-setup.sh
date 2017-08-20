#!/bin/bash

# Copyright (c) 2017 Matthieu Buffet
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

ROOTCONF="/etc/dropbear-initramfs"
INITRDCONF="/etc/dropbear"
ROOTKEYS="/root/.ssh/authorized_keys"
AUTHKEYS="$ROOTCONF/authorized_keys"

gethostkeys () {
	find "$ROOTCONF" -name 'dropbear_*_host_key' 2>/dev/null
}

check () {
	if ! require_binaries systemd-tty-ask-password-agent; then
		echo "This module only works with systemd's encrypt hook in initramfs."
		return 1
	elif ! require_binaries dropbear || ! [ -z "$(gethostkeys)" ] && ! require_binaries ssh-keygen dropbearconvert; then
		echo "Please install dropbear and generate host keys first."
		return 1
	elif ! [ -f "$AUTHKEYS" ] && ! [ -s "$ROOTKEYS" ]; then
		echo "Please set up authorized SSH keys in $AUTHKEYS first."
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
		echo "You haven't generated SSH host keys in $ROOTCONF, generating a 4096-bit RSA one..."
		echo "WARNING: This key will be stored in cleartext in your initramfs."
		echo "         Do *not* reuse it anywhere else"
		mkdir -p "$ROOTCONF/"
		ssh-keygen -t rsa -b 4096 -N '' -f /tmp/dropbear_openssh >/dev/null
		dropbearconvert openssh dropbear /tmp/dropbear_openssh "$ROOTCONF/dropbear_rsa_host_key"
		shred -f /tmp/dropbear_openssh 2>/dev/null
		rm -f /tmp/dropbear_openssh
	fi
	if ! [ -e "$AUTHKEYS" ]; then
		echo "You haven't configured authorized SSH keys in $AUTHKEYS, using root's ones"
		cp "$ROOTKEYS" "$AUTHKEYS"
		sed -ire 's#^ssh#command="/usr/bin/systemd-tty-ask-password-agent --watch" ssh#' "$AUTHKEYS"
	fi
	mkdir -p "${initdir}/var/log/"
	touch "${initdir}/var/log/lastlog"
	inst_binary dropbear
	inst_binary chroot
	for hostkey in $(gethostkeys); do
		inst "$hostkey" "$INITRDCONF/$(basename "$hostkey")"
	done
	inst "$AUTHKEYS" "/root/.ssh/authorized_keys"
	inst_hook initqueue 20 "$moddir/start.sh"
	inst_hook cleanup 05 "$moddir/stop.sh"
}
