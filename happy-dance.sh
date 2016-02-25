#!/bin/sh

###
# happy-dance.sh by _NSAKEY
# Requirements: OpenSSH 6.5 or above, sudo access.
# (But you should probably run as root anyway)
#
# This script automates everything laid out in stribika's Secure Secure Shell.
# Source: https://stribika.github.io/2015/01/04/secure-secure-shell.html
#
# Tested on the following platforms:
# - Debian Wheezy & Jessie (With ssh from wheezy-backports for Wheezy)
# - Ubuntu 14.04 & 15.04 (12.04 will work with a PPA according to https://github.com/NSAKEY/happy-dance/issues/1#issuecomment-128469412)
# - CentOS 7
# - Alpine Linux 3.3.1
# - Mac OS X Yosemite Niresh with Homebrew's openssh
# - FreeBSD 10 & 11
# - OpenBSD 5.7
# - NetBSD 7.0 RC 1
# - Solaris 11.2 with CSWOpenSSH and 11.3 Beta with OpenSSH from the package manager

# Notes:
# 1. OpenBSD/NetBSD users: /etc/moduli is the same as /etc/moduli on other
# platforms. You don't have to do anything extra to make the script work.
# Also, SHA256 fingerprints are now a thing for you.
#
# 2. Mac users: You need to install Homebrew. Once that's done, install openssh like so:
# "brew tap homebrew/dupes"
# "brew install openssh --with-brewed-openssl"
# This will give you a working version of OpenSSH with OpenSSL. Testing without
# OpenSSL failed miserably, so installing it is required.
#
# 3. Another Mac user note: The script drops "unset SSH_AUTH_SOCK" in your
# .bash_profile. This is needed so that you can connect to remote hosts. Check the
# comments below if you wish to know more.
#
# 4. Solaris users: The 11.3 beta has OpenSSH 6.5 in the package manager, but it's the only
# version of 6.5 I've ever seen that does NOT support ED25519 keys. It does, however, support
# the -o flag introduced in OpenSSH 6.5, so that's now used for the version check code.
# my process for switching to Oracle's OpenSSH, because they may add ED25519 support one day.
# The "OpenSSH in Solaris 11.3" blog post by Darren Moffat
# (Found here: https://blogs.oracle.com/darren/entry/openssh_in_solaris_11_3)
# states that both SunSSH and OpenSSH can be installed side by side. My experience is that
# if SunSSH is installed, it takes precedence over OpenSSH, and the only way I found around
# it is to uninstall SunSSH. I don't use Solaris daily (And only ported happy-dance to it for fun),
# so I'm certain there's a way to switch without uninstalling ssh. Suggestions are welcome.
#
# TO DO:
# 1. Ansible/chef/puppet support, for maximum devops deliciousness.
# 2. Windows 10 client support?
###

# Just setting some variables before we started.

UNAME=`uname`
KEYSIZE=`test -r ~/.ssh/id_rsa.pub && ssh-keygen -l -f ~/.ssh/id_rsa.pub | awk '{print $1}'` # A special thanks to akhepcat for the suggestion to test -r first. It catches an edge case that may throw an error message for some clients.
#VERSION=`ssh-keygen -t ed25519 -f /tmp/version.check -o -a 100 -q -N "" < /dev/null 2> /dev/null; echo $?` # Old version check.
VERSION=`ssh-keygen -t rsa -f /tmp/version.check -o -a 100 -q -N "" < /dev/null 2> /dev/null; echo $?` # Solaris 11.3's OpenSSH do not support ED25519 keys (Source: https://twitter.com/darrenmoffat/status/641568090581528576), but do support the option to use bcrypt to protect keys at rest. Since that option is common to all newer implementations of OpenSSH, that's what will be used for the version check from now on.

# What follows is just some introductory text.

printf "This script will give you an ssh config for clients and servers that should force the NSA to work for a living.

For an explanation of everything used in the configs, check out Secure Secure Shell:
https://stribika.github.io/2015/01/04/secure-secure-shell.html
Check out the README and the script's source if you want to see how the sausage is made.

Flags:
            -c  Set up a client. Use this if you're hardening your user config to make connections to remote hosts.
            -s  Set up a server. Use this flag if you're hardening the ssh config of a remote host to accept connections from users.

NOTE: Setting up a user config will require sudo access to give you a new ssh_config file.

"

# Before getting too carried away, we're going to check the SSH version in an
# informal but clear way. This script requires at least OpenSSH 6.5, so generating a
# test RSA key with the -o flag is the quickest and easiest way to do a version check.

if [ $VERSION -gt 0 ]; then
    printf "Your OpenSSH version is too old to run happy-dance. Upgrade to 6.5 or above.\n"
    exit;
else

    rm -rf /tmp/version.check* # Just doing some house keeping.

    generate_moduli() {
        printf "Your OS doesn't have an /etc/ssh/moduli file, so we have to generate one. This might take a while.\n"
        sudo ssh-keygen -G "${HOME}/moduli.all" -b 4096
        sudo ssh-keygen -T "${HOME}/moduli" -f "${HOME}/moduli.all"
        sudo rm "${HOME}/moduli.all"
    }

    # The ssh_client function takes the time to check for the existence of keys
    # because deleting or overwriting existing keys would be bad.

    print_for_solaris_users() {
        printf "\nSolaris 11.2 and older users need to install OpenSSH from OpenCSW in order for happy-dance to work.\n"
        printf "Solaris 11.3 users can get OpenSSH by running the following commands:\n"
        printf "pkg uninstall ssh\n"
        printf "pkg install openssh\n"
        printf "You can verify the ssh version before and after by running 'pkg mediator ssh' and looking at the 'IMPLEMENTATION' column or by running 'ssh -V' and reading the output.\n\n"
    }

    ssh_client() {
        while true; do
            if [ $UNAME = "OpenBSD" ] || [ $UNAME = "SunOS" ]; then # Needed for OpenBSD and Solaris support because the read command behaves differently on both.
                read yn?"This option replaces your ssh_config without backing up the original. Root or sudo access is requuired to do this. Are you sure you want to proceed? (y/n)"
            else
                read -p "This option replaces your ssh_config without backing up the original. Root or sudo access is required to do this. Are you sure you want to proceed? (y/n)" yn
            fi
            case $yn in
                [Yy]* ) printf "Replacing your ssh client configuration file...\n"
                    if [ -f /usr/local/etc/ssh/ssh_config ]; then
                        sudo cp etc/ssh/ssh_config /usr/local/etc/ssh/ssh_config
                    else
                        sudo cp etc/ssh/ssh_config /etc/ssh/ssh_config # Removed $PWD
                    fi

                    # If you don't already have ssh keys, they will be generated for you.
                    # If you do have keys, they won't be deleted, because that would be rude.

                   if [ ! -f $HOME/.ssh/id_ed25519 ]; then
                       ssh-keygen -t ed25519 -o -a 100
                   else
                       printf "You already have an ED25519 key!\n"
                   fi

                   if [ ! -f $HOME/.ssh/id_rsa ]; then
                       ssh-keygen -t rsa -b 4096 -o -a 100
                   else
                       if [ "$KEYSIZE" -ge 4096 ]; then
                           printf "You already have an RSA key!\n"
                       else
                           printf "You already have an RSA key, but it's only $KEYSIZE bits long. You should delete or move it and re-run this script, or generate another key by hand! The command to generate your own RSA key pair is:\n\n"
                           printf "ssh-keygen -t rsa -b 4096 -o -a 100\n"
                       fi
                   fi

                   # Just printing some info for Solaris users.

                   if [ $UNAME = "SunOS" ]; then
                       print_for_solaris_users
                   else
                       exit;
                   fi

                   # This rather hackish check for OS X is only done so that the user's .bash_profile can be modified to make outgoing ssh connections work.

                   if [ $UNAME = "Darwin" ]; then
                       if grep -qFx "unset SSH_AUTH_SOCK" ~/.bash_profile; then # This just keeps the user from having SSH_AUTH_SOCK unset multiple times. It's a matter of config file cleanliness.
                           printf "Refusing to duplicate effort in your .bash_profile\n"
                       else
                           printf "unset SSH_AUTH_SOCK\n" >> ~/.bash_profile
                       fi
                       printf "Since you use Mac OS X, you had to have a small modification to your .bash_profile in order to connect to remote hosts. Read here and follow the links to learn more: http:/serverfault.com/a/486048\n\n"
                       printf "OpenSSH will work the next time you log in. If you want to use OPenSH imediately, run the following command in your terminal:\n"
                       printf "unset SSH_SOCK_AUTH\n"
                       printf "You only have to run that command once. That line is in your .bash_profile and will automatically make OpenSSH work for you on all future logins.\n"
                   else
                       exit;
                   fi

                exit;;
                [Nn]* ) exit;; # This is what happens if you select no.
            esac
        done
    }

    # Meanwhile, the ssh_server function asks if you're sure you want to
    # obliterate the public/private keypairs which make up the host keys.
    # After that, /etc/ssh/moduli is either hardened or generated in a hardened
    # state and then the ED25519 and 4096-bit RSA host keys are generated. As
    # having passwords on host keys means that sshd won't start automatically,
    # the choice of passwording them has been removed from the user.

    ssh_server() {
        while true; do
            if [ $UNAME = "OpenBSD" ] || [ $UNAME = "SunOS" ]; then # Needed for OpenBSD and Solaris support because the read command behaves differently on both.
                read yn?"This option destroys all host keys and replaces your sshd_config file. Are you sure want to proceed? (y/n)"
            else
                read -p "This option destroys all host keys and replaces your sshd_config file. Are you sure want to proceed? (y/n)" yn
            fi
            case $yn in
                [Yy]* ) printf "Replacing your ssh server configuration file...\n"

            # Some platforms (Such as OpenBSD and NetBSD) store the moduli in /etc/moduli,
            # instead of /etc/ssh/moduli. I dislike nested ifs on principle, but this one
            # isn't too terrible.

                    if [ ! -f /etc/ssh/moduli ]; then
                        if [ ! -f /etc/moduli ]; then
                            generate_moduli
                            sudo mv "${HOME}/moduli" /etc/ssh/moduli
                        else
                            printf "Modifying your /etc/moduli\n"
                            sudo awk '$5 > 2000' /etc/moduli > "${HOME}/moduli"
                            LINES=$(wc -l "${HOME}/moduli" | awk '{print $1}')
                            if [ $LINES -eq 0 ]; then
                                generate_moduli
                            fi
                            sudo mv "${HOME}/moduli" /etc/moduli
                        fi
                    else
                        printf "Modifying your /etc/ssh/moduli\n"
                        sudo awk '$5 > 2000' /etc/ssh/moduli > "${HOME}/moduli"
                        LINES=$(wc -l "${HOME}/moduli" | awk '{print $1}')
                        if [ $LINES -eq 0 ]; then
                            generate_moduli
                        fi
                        sudo mv "${HOME}/moduli" /etc/ssh/moduli
                    fi

                    # Some platforms stuff the ssh config files under /usr/local, and this is also
                    # the case if you've built your own ssh binary. So instead of doing $UNAME checks,
                    # I just opted to check whether /usr/local/etc/ssh exists. I have yet to find a
                    # scenario in which one of these two dir paths aren't used, so there is no
                    # baked in error handling if /usr/local/etc/ssh and /etc/ssh don't exist.

                    # As for what the branches in the if do, they each copy over the hardened config,
                    # rm the host key files, generate new keys, then store those keys in variables
                    # for printing later. You should always verify host key fingerprints,
                    # and you are more likely to do it if this script makes it easy for you.
                    # The variables are set up so that if you're using OpenSSH 6.5-6-7, the script
                    # will print just the MD5 fingerprints. If you're using OpenSSH 6.8 and above,
                    # it will print both the MD5 and SHA256 fingerprints. This means you can
                    # easily verify the key fingerprints on your next login without having to
                    # worry about your OpenSSH version.

                    if [ -d /usr/local/etc/ssh ]; then
                        sudo sed 's/Hostkey \/etc\/ssh/Hostkey \/usr\/local\/etc\/ssh/g' etc/ssh/sshd_config > /usr/local/etc/ssh/sshd_config # The most portable way I could think of to account for users who build openssh from source.
                        cd /usr/local/etc/ssh
                        sudo rm ssh_host_*key*
                        sudo ssh-keygen -t ed25519 -f ssh_host_ed25519_key -q -N "" < /dev/null 2> /dev/null
                        sudo ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key -q -N "" < /dev/null
                        ED25519_fingerprint="$(ssh-keygen -l -f /usr/local/etc/ssh/ssh_host_ed25519_key.pub 2> /dev/null)"
                        RSA_fingerprint="$(ssh-keygen -l -f /usr/local/etc/ssh/ssh_host_rsa_key.pub)"
                        ED25519_fingerprint_MD5="$(ssh-keygen -l -E md5 -f /usr/local/etc/ssh/ssh_host_ed25519_key.pub 2> /dev/null)"
                        RSA_fingerprint_MD5="$(ssh-keygen -l -E md5 -f /usr/local/etc/ssh/ssh_host_rsa_key.pub 2> /dev/null)"
                    else
                        sudo cp etc/ssh/sshd_config /etc/ssh/sshd_config
                        cd /etc/ssh
                        sudo rm ssh_host_*key*
                        sudo ssh-keygen -t ed25519 -f ssh_host_ed25519_key -q -N "" < /dev/null 2> /dev/null
                        sudo ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key -q -N "" < /dev/null
                        ED25519_fingerprint="$(ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub 2> /dev/null)"
                        RSA_fingerprint="$(ssh-keygen -l -f /etc/ssh/ssh_host_rsa_key.pub)"
                        ED25519_fingerprint_MD5="$(ssh-keygen -l -E md5 -f /etc/ssh/ssh_host_ed25519_key.pub 2> /dev/null)"
                        RSA_fingerprint_MD5="$(ssh-keygen -l -E md5 -f /etc/ssh/ssh_host_rsa_key.pub 2> /dev/null)"
                    fi

                    # This next bit of code just prints the key fingerprints. if the *_MD5
                    # variables contain anything at all, they will print. Otherwise, that's
                    # 2 fewer lines printed in your terminal.

                    printf "Your new host key fingerprints are:\n"
                    printf "$ED25519_fingerprint\n" 2> /dev/null
                    printf "$RSA_fingerprint\n"
                    if [ -n "$ED25519_fingerprint_MD5" ]; then
                        printf "$ED25519_fingerprint_MD5\n" 2> /dev/null
                    fi

                    if [ -n "$RSA_fingerprint_MD5" ]; then
                        printf "$RSA_fingerprint_MD5\n"
                    fi
                    printf "Don't forget to verify these!\n"

                    if [ $UNAME = "SunOS" ]; then
                        print_for_solaris_users
                    else
                        exit;
                    fi

                    # Just some final instructions. Nothing too fancy.

                    printf "Without closing this ssh session, do the following:
                    1. Add your public key to ~/.ssh/authorized_keys if it isn't there already
                    2. Restart your sshd.
                    3. Remove the line from the ~/.ssh/known_hosts file on your computer which corresponds to this server.
                    4. Try logging in. If it works, HAPPY DANCE!\n"
                    exit;;
                [Nn]* ) exit;; # This is what happens if you select no.
            esac
        done
    }
fi

# This last bit of code just defines the flags.

while getopts "cs" opt; do
    case $opt in

        c)
            ssh_client
        ;;

        s)
            ssh_server
        ;;

        \?)
            printf "$opt is invalid.\n"
        ;;
    esac
done
