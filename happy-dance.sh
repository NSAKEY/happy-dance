#!/bin/sh

###
# happy-dance.sh by _NSAKEY
# Requirements: OpenSSH 6.5 or above, sudo access.
# Tested on the following platforms:
# - Debian Wheezy/Jessie (With ssh from wheezy-backports for Wheezy)
# - Ubuntu 14.04/15.04
# - CentOS 7
# - FreeBSD 10
# - NetBSD 7.0
# - Solaris 11.2 with CSWOpenSSH.

# Notes:
# 1. NetBSD users: /etc/ssh/module has to be generated. Since this is kind of
# annoying, I may just drop a known good /etc/ssh/moduli in this project and
# rework the script to automatically cp it over.
# 2. Solaris users: Change the shell to /bin/bash. After that, It Just Works.

# TO DO:
# 1. Test and rework to support OpenBSD, just because.
# 2. Eventually rework the configs to support new options in OpenSSH,
# like FingerprintHash in 6.8 and ChaCha20-poly1350@openssh.com in 6.9.

# This script automates everything laid out in stribika's Secure Secure Shell.
# Source: https://stribika.github.io/2015/01/04/secure-secure-shell.html
###

#PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # Breaks NetBSD 7.0. So much for being fancy about forcing full path names.

echo "This script will give you an ssh config for clients and servers that should force the NSA to work for a living.
Use -h for help.
For an explanation of everything, check out Secure Secure Shell:
https://stribika.github.io/2015/01/04/secure-secure-shell.html
"

# The ssh_client function takes the time to check for the existence of keys
# because deleting or overwriting existing keys would be bad.

ssh_client() {
    echo "Replacing your ssh client configuration file..."
    sudo cp etc/ssh/ssh_config /etc/ssh/ssh_config # Removed $PWD

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

# Meanwhile, the ssh_server function asks if you're sure you want to
# obliterate the public/private keypairs which make up the host keys.
# After that, /etc/ssh/moduli is either hardened or generated in a hardened
# state and then the ED25519 and 4096-bit RSA host keys are generated. As
# having passwords on host keys means that sshd won't start automatically,
# the choice of passwording them has been removed from the user.

ssh_server() {
    while true; do
        read -p "This option destroys all host keys. Are you sure want to proceed? (y/n)" yn
        case $yn in
            [Yy]* ) echo "Replacing your ssh server configuration file..."
                sudo cp etc/ssh/sshd_config /etc/ssh/sshd_config #Removed $PWD

                if [ ! -f /etc/ssh/moduli ]; then
                    echo "Your OS doesn't have an /etc/ssh/moduli file, so we have to generate one. This might take a while."
                    sudo ssh-keygen -G "${HOME}/moduli" -b 4096
                    sudo ssh-keygen -T /etc/ssh/moduli -f "${HOME}/moduli"
                    sudo rm "${HOME}/moduli"
                else
                    echo "Modifying your /etc/ssh/moduli"
                    sudo awk '$5 > 2000' /etc/ssh/moduli > "${HOME}/moduli"
                    sudo mv "${HOME}/moduli" /etc/ssh/moduli
                fi

                cd /etc/ssh
                sudo rm ssh_host_*key*
                sudo ssh-keygen -t ed25519 -f ssh_host_ed25519_key -q -N "" < /dev/null
                sudo ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key -q -N "" < /dev/null
                ED25519_fingerprint="$(ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub)"
                RSA_fingerprint="$(ssh-keygen -l -f /etc/ssh/ssh_host_rsa_key.pub)"
                echo ""
                echo "Your new host key fingerprints are:"
                echo $ED25519_fingerprint
                echo $RSA_fingerprint
                echo ""
                echo "Without closing this ssh session, do the following:
                1. Add your public key to ~/.ssh/authorized_keys if it isn't there already
                2. Restart your sshd.
                3. Remove the line from the ~/.ssh/known_hosts file on your computer which corresponds to this server.
                Try logging in. If it works, HAPPY DANCE!"
                break;;
            [Nn]* ) exit;;
        esac
    done
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

