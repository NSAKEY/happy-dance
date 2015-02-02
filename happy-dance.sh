#!/bin/bash

###
# happy-dance.sh by _NSAKEY
# Requirements: OpenSSH 6.5 or above
# This script just automates the steps laid out in stribika's Secure Secure Shell guide.
# Source: https://stribika.github.io/2015/01/04/secure-secure-shell.html
###

PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "This script will give you an ssh config for clients and servers that should force the NSA to work for a living.
Use -h for help
"

ssh_client() {
    cp $PWD/etc/ssh/ssh_config /etc/ssh/ssh_config

    if [ ! -f $HOME/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -o -a 100
    else
        echo "You already have an ED25519 key!"
    fi

    if [ ! -f $HOME/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -o -a 100
    else
        echo "You already have an RSA key! If it's not at least 4096 bits, you should delete or move it and re-run this script!"
    fi
}

ssh_server() {
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
        read -p "This option destroys all host keys. Are you sure want to proceed? (y/n)"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp $PWD/etc/ssh/sshd_config /etc/ssh/sshd_config

        if [ ! -f /etc/ssh/moduli ]; then
            echo "Your OS doesn't have an /etc/ssh/module file, so we have to generate one. This might take a while."
            ssh-keygen -G "${HOME}/moduli" -b 4096
            ssh-keygen -T /etc/ssh/moduli -f "${HOME}/moduli"
            rm "${HOME}/moduli"
        else
            awk '$5 > 2000' /etc/ssh/moduli > "${HOME}/moduli"
            mv "${HOME}/moduli" /etc/ssh/moduli
        fi

        cd /etc/ssh
        rm ssh_host_*key*
        echo "Do NOT set passwords for the host keys! Otherwise sshd will not be able to start automatically."
        ssh-keygen -t ed25519 -f ssh_host_ed25519_key < /dev/null
        ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key < /dev/null
        /etc/init.d/ssh restart # YOLO
    else
        exit;
    fi
}

while getopts "hcs" opt; do
    case $opt in
        h)
            echo "Flags:
            -c  Set up a client
            -s  Set up a server
            "
        ;;
        c)
            ssh_client
        ;;
        s)
            ssh_server
        ;;
        \?)
            echo "$opt is invalid."
        ;;
    esac
done

