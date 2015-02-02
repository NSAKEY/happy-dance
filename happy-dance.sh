#!/bin/bash

###
# happy-dance.sh by _NSAKEY
# Requirements: OpenSSH 6.5 or above, sudo access.
# This script just automates the steps laid out in stribika's Secure Secure Shell guide.
# Source: https://stribika.github.io/2015/01/04/secure-secure-shell.html
###

PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "This script will give you an ssh config for clients and servers that should force the NSA to work for a living. 
Use -h for help.
"

# The ssh_client function takes the time to check for the existence of keys because deleting or overwriting existing keys would be bad.

ssh_client() {
    echo "Replacing your ssh client configuration file..."
    sudo cp $PWD/etc/ssh/ssh_config /etc/ssh/ssh_config

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

# Meanwhile, the ssh_server function asks if you're sure you want to obliterate the public/private keypairs which make up the host keys.
# After that, /etc/ssh/module is either hardened or generated in a hardened state and then the ED26619 and 4096-bit RSA host keys are generated. As having passwords on host keys means that sshd won't start automatically, the choice of passwording them has been removed from the user.

ssh_server() {
    read -p "This option destroys all host keys. Are you sure want to proceed? (y/n)"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Replacing your ssh server configuration file..."
        sudo cp $PWD/etc/ssh/sshd_config /etc/ssh/sshd_config

        if [ ! -f /etc/ssh/moduli ]; then
            echo "Your OS doesn't have an /etc/ssh/moduli file, so we have to generate one. This might take a while."
            sudo ssh-keygen -G "${HOME}/moduli" -b 4096
            sudo ssh-keygen -T /etc/ssh/moduli -f "${HOME}/moduli"
            sudo rm "${HOME}/moduli"
        else
            echo "Modifying your /etc/ssh/module"
            sudo awk '$5 > 2000' /etc/ssh/moduli > "${HOME}/moduli"
            sudo mv "${HOME}/moduli" /etc/ssh/moduli
        fi

        cd /etc/ssh
        sudo rm ssh_host_*key*
        sudo ssh-keygen -t ed25519 -f ssh_host_ed25519_key -q -N "" < /dev/null
        sudo ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key -q -N "" < /dev/null
        sudo /etc/init.d/ssh restart
        echo "Without closing this ssh session, add your public key to ~/.ssh/authorized_keys if it isn't there already and try logging in. If it works, HAPPY DANCE!"
    else
        exit;
    fi
}

# This last bit of code just defines the flags.

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
