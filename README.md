Happy Dance
===================

This project is based on OpenSSH-hardening advice offered by stribika. The general idea is to throw a wrench into the works of illegal mass surveillance. This is accomplished by:

1. Enforcing forward secrecy on the key exchange.
2. Dropping weak and/or tainted key algorithms (re: Anything with "DSA" in the name) in favor of 4096-bit RSA keys and ED25519.
3. Disable the use of weak and broken ciphers.
4. Sane settings related to message authentication codes.

DISCLAIMER: If the NSA or equivalent SIGINT agency is after you, this script won't prevent you from getting owned by other means, and it should not be assumed that this will even make your ssh sessions bullet-proof. This script is just a way to help others spit in the face of passive surveillance against ssh connections. Consider yourself warned.

If you want to take it a step further, you could install Tor, set up ssh as an authenticated hidden service (So the hidden service descriptor can't be readily harvested by bad actors and researchers), and then set your sshd's bind address to 127.0.0.1. It's probably the ultimate in security through obscurity.

Fun Fact: The client set-up this script provides is still (As of July 28th, 2015) too hardcore for github.com. I had to comment out the KexAlgorithms in /etc/ssh/ssh_config in order to push to github with ssh. 

To use this repository, OpenSSH 6.5 or higher is required. This scripts works on the following platforms:

- Debian Wheezy & Jessie (With ssh from wheezy-backports for Wheezy)
- Ubuntu 14.04 & 15.04
- CentOS 7
- Mac OS X Yosemite Niresh with brew's openssh
- FreeBSD 10 & 11
- OpenBSD 5.7
- NetBSD 7.0 RC 1
- Solaris 11.2 with CSWOpenSSH

If you're stuck using an older version of OpenSSH, I really can't help you. Here are the commands you'll want to run:

```sh
git clone https://github.com/NSAKEY/happy-dance.git
cd happy-dance-master
./happy-dance.sh
```

Credit goes to stribika for writing Secure Secure Shell. Source: https://stribika.github.io/2015/01/04/secure-secure-shell.html
