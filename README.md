# dracut-dropbear-unlock

A minimalist dracut module that allows you to remotely unlock an encrypted root partition during boot. The module script is kept simple, so you are strongly advised to read it and decide if it suits your needs.

With this module, this is was a typical boot sequence looks like:

```
    server$ reboot
    Connection closed by remote host.
    local$ ssh myserver.com
    ssh: connect to host myserver.com port 22: Connection refused
    local$ ssh myserver.com -p 2222
    [... enter passphrase]
    Please enter passphrase for disk <your disk> (luks-<your uuid>)! ****************
    Connection closed by remote host.
    local$ ssh myserver.com
    [... enter passphrase]
    server$
```

By default, the server uses port 2222, a 4096-bit RSA host key, only allows public key authentication, and only gives an encryption key prompt instead of a shell.

*Full-disk encryption doesn't protect you against someone with physical access to the machine*: the encryption key can be recovered from RAM at runtime (e.g. cold boot attacks), and since the boot time SSH server's key is stored unencrypted, man-in-the-middle attacks can also be carried out to recover the encryption key at boot time. Consider this in your threat model.

## Installation

For preliminary advice on how to encrypt your root partition, I can only recommend the [Arch wiki page on this topic](https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system).

1. Install Dracut's support for network-aware initramfs, *cryptsetup*, and *dropbear* (e.g. `yum install epel-release ; yum install openssh cryptsetup dropbear dracut-network`)

2. Add SSH keys to your `/root/.ssh/authorized_keys` or `/etc/ssh/authorized_keys`, depending on your needs.

2. Modify your kernel commandline to set up minimal networking during boot. If you use Grub2, you need to add this to your `GRUB_CMDLINE_LINUX` in `/etc/default/grub`, for instance:

```
    # Static IP and gateway on a specific interface (use a MAC address, not unstable interface names which might change while interfaces are being brought up)
    rd.neednet=1 ifname=ethmain:<MAC> ip=<static IP>::<static gateway IP>:<netmask>::ethmain:off

    # or just autoconfigure with DHCP on all interfaces
    rd.neednet=1 ip=dhcp
```

3. Install this dracut module

```
    git clone https://github.com/mtth-bfft/dracut-dropbear-unlock
    sudo mv dracut-dropbear-unlock /usr/lib/dracut/modules.d/99dropbear-unlock
    echo add_dracutmodules+="dropbear-unlock" > /etc/dracut.conf.d/dropbear-unlock.conf
```

4. Install your new Grub2 settings and rebuild your initramfs:

```
    grub2-mkconfig -o /boot/grub2/grub.cfg
    dracut -f
```

Just a side note if you're running CentOS (other distros might have an equivalent service): you might need to `systemctl mask rhel-import-state` to prevent it from overwriting your `/etc/resolv.conf` and `/etc/sysconfig/network-scripts/` with the kernel cmdline settings at each boot (if you want more complex settings during normal runtime than during unlock.)

## Contributing

Open an issue or send a pull request. For questions/comments/ideas, I'm on Twitter ([@mtth_bfft](https://twitter.com/mtth_bfft))
