#!/bin/bash

# Wireguard VPN configuration management script
# 2019-2022, Laurent Ghigonis <ooookiwi@gmail.com>
# https://github.com/looran/wg-confgen

set -e

usageexit() {
    cat <<-_EOF
usage: $PROG (defaultconf | network | srvinit | peeradd | srvconf | srvdeploy) <arguments...>
defaultconf
    create a default wg-confgen.conf file
network
    display summary of server and peers IP addressing
srvinit <ipaddress>/<subnet>
    initialize server keys (local files)
peeradd <peername> "<ipaddress>/<subnet> [<ipaddress/subnet>]" [user_email]
    create a configuration file for a peer (local file)
srvconf
    generate server configuration with all peers (local file)
srvdeploy
    (active action) deploy server configuration and restart wg
help
    shows extended help
_EOF
	exit 1
}

trace() {
	echo "# $*"
	"$@"
}

err() {
	msg="$1"
	echo "ERROR: $1"
	exit 2
}

conf_load() {
	[ ! -e "$CONF" ] && err "wg-confgen.conf not found in current directory !"
	source "$CONF"
	[ $VPNSERVER_ENDPOINT = "A.B.C.D:51820" ] && echo "WARNING: configuration variable VPNSERVER_ENDPOINT was not modified, heading for trouble (file $CONF)"
	echo "[+] loaded $CONF"
}

PROG="$(basename $0)"
DIR="$(pwd)"
CONF="$DIR/wg-confgen.conf"
SERVER_DIR="$DIR/server"
SERVER_PUBKEY_FILE="$SERVER_DIR/publickey"
SERVER_IP_FILE="$SERVER_DIR/ip"
SERVER_PRIVKEY_FILE="$SERVER_DIR/privatekey"
SERVER_PUBKEY_FILE="$SERVER_DIR/publickey"
NOW="$(date "+%Y%m%d_%H%M")"

[ $# -lt 1 ] && usageexit
umask 077

action="$1"

shift
case $action in
defaultconf)
	path="$DIR/wg-confgen.conf"
	[ -e $path ] && err "configuration file already exists: $path"
	cat > $path <<-_EOF
# this is a configuration file for wg-confgen,
# a Wireguard configuration management script
# https://github.com/looran/wg-confgen

# vpn arbitrary name
VPNNAME="Wireguard VPN"
# name for the wg interface
VPNIFACE="wgvpn"
# wg server IP and port
VPNSERVER_ENDPOINT="A.B.C.D:51820"
# used only for 'wg-confgen srvdeploy'
VPNSERVER_SSH_HOST="A.B.C.D|ssh-alias"
# included in wg server configuration
VPNSERVER_EXTRACONF=""
# included in each wg client configuration
VPNCLIENT_ALLOWEDIPS="172.16.99.0/24"
# included in each wg client configuration
VPNCLIENT_EXTRACONF="Table = off"
# included wg client server peer configuration
VPNCLIENT_PERSISTENTKEEPALIVE="0"
# email template body content, generated for new clients
EMAIL_BODY=""
# email template signature, generated for new clients
EMAIL_FOOTER="Enjoy,
the admin"

# example : use the VPN as internet gateway for clients:
# VPNSERVER_EXTRACONF="PostUp = sysctl -w net.ipv4.conf.%i.forwarding=1
# PostUp = sysctl -w net.ipv4.conf.<internet_interface>.forwarding=1
# PostUp = iptables -t nat -A POSTROUTING -o <internet_interface> -j MASQUERADE
# PreDown = iptables -t nat -D POSTROUTING -o <internet_interface> -j MASQUERADE"
# VPNCLIENT_ALLOWEDIPS="0.0.0.0/0"
# VPNCLIENT_EXTRACONF=""

# example : set MTU on all peers:
# VPNSERVER_EXTRACONF="MTU = 1300"
# VPNCLIENT_EXTRACONF="MTU = 1300"

# example : ensure peers don't timeout behind NAT
# VPNCLIENT_PERSISTENTKEEPALIVE="25"
_EOF
    echo "[*] DONE created $path"
	;;

network)
	conf_load
	echo "server:"
	if [ -e $SERVER_IP_FILE ]; then
		echo "   $(cat $SERVER_IP_FILE)"
	else
		echo "   no server, use '$PROG srvinit'"
	fi
	if [ -e peer_* ]; then
		for p in peer_*; do
			echo "   $p: $(grep AllowedIPs $p/serveraddition.conf)"
		done
		for p in peer_*; do
			echo "$p"
			echo "   $(grep PublicKey $p/serveraddition.conf)"
			echo "   $(grep Address $p/$VPNIFACE.conf)"
			echo "   $(grep AllowedIPs $p/$VPNIFACE.conf)"
		done
	else
		echo "no peers, use '$PROG peeradd'"
	fi
	;;

srvinit)
    [ $# -lt 1 ] && usageexit
	ipaddress="$1"

	conf_load
    [ -e $SERVER_DIR ] && err "server directory already exists : $SERVER_DIR"
    trace mkdir $SERVER_DIR
	echo "$ipaddress" > $SERVER_IP_FILE
    echo "[+] generating keys"
    wg genkey |tee "$SERVER_PRIVKEY_FILE" |wg pubkey > "$SERVER_PUBKEY_FILE"
    echo "[*] DONE generated Wireguard server keys in $SERVER_DIR"
    ;;

peeradd)
    [ $# -lt 2 ] && usageexit

	conf_load
    [ ! -e $SERVER_PUBKEY_FILE ] && err "server public key not found ! file $SERVER_PUBKEY_FILE"
    peername="$1"
    ipaddress="$2"
	email="$3"
    peerdir="$DIR/peer_${peername}"
    privatekey="$peerdir/privatekey"
    publickey="$peerdir/publickey"
    pskkey="$peerdir/psk"
    conf="$peerdir/$VPNIFACE.conf"
    confsrv="$peerdir/serveraddition.conf"
	instructions="$peerdir/instructions.txt"
    [ -e $peerdir ] && err "peer directory already exists : $peerdir"
    mkdir $peerdir
    cat <<-_EOF
peer public key    : $publickey
peer private key   : $privatekey
psk key            : $pskkey
configuration file : $conf
_EOF

    echo "[+] generating keys"
    wg genkey |tee "$privatekey" |wg pubkey > "$publickey"
    wg genpsk > $pskkey

    echo "[+] creating configuration file"
    cat > "$conf" <<-_EOF
# $VPNNAME wireguard configuration for peer $peername, created on $NOW
[Interface]
PrivateKey = $(cat "$privatekey")
Address = $ipaddress
${VPNCLIENT_EXTRACONF}
[Peer]
PublicKey = $(cat "$SERVER_PUBKEY_FILE")
AllowedIPs = ${VPNCLIENT_ALLOWEDIPS}
EndPoint = ${VPNSERVER_ENDPOINT}
PresharedKey = $(cat $pskkey)
PersistentKeepalive = ${VPNCLIENT_PERSISTENTKEEPALIVE}
_EOF

    echo "[+] creating configuration file addition for server"
    cat > "$confsrv" <<-_EOF
# peer $peername, added on $NOW
[Peer]
PublicKey = $(cat "$publickey")
AllowedIPs = $ipaddress
PresharedKey = $(cat $pskkey)

_EOF

	INSTRUCTION_SEND="Send the following message to user of peer ${peername}, with this configuration attached:
$conf
"
	if [ ! -z "$email" ]; then
		confgpg="$conf.asc"
		INSTRUCTION_SEND="Send the following message to user of peer ${peername}, with GPG encrypted configuration attached:
$confgpg
To:
$email"
		gpg -a -e -r "$email" -o $confgpg $conf
	fi

    cat > "$instructions" <<-_EOF
---INSTRUCTION#1 : Update Wireguard Server configuration ---------------------------

On "$VPNNAME" wg server, you have to update $VPNIFACE configuration

To do so you have 2 options:
A. automated: use the command '$PROG srvconf' then '$PROG srvdeploy'
B: manual: on "$VPNNAME" wg server add the following to configuration /etc/wireguard/$VPNIFACE.conf, then restart wg:

(from $confsrv)
$(cat "$confsrv")

wg-quick down $VPNIFACE
wg-quick up $VPNIFACE

---INSTRUCTION#2 : Send Wireguard client configuration the user ---------------------

$INSTRUCTION_SEND
Subject:
$VPNNAME configuration for user $peername
>>>>>>>>>>>>>>>>>>>>>>>>>
Hello ${peername},

Attached is your Wireguard configuration for $VPNNAME.
Save it in /etc/wireguard/
You can start the VPN with 'wg-quick up $(basename $conf .conf)', and turning it down using 'wg-quick down $(basename $conf .conf)'.

In this $VPNNAME your IP address will be ${ipaddress}.
$EMAIL_BODY

For more informations regarding Wireguard:
* check wg(8) and wg-quick(8) manual pages
* For installation   : https://www.wireguard.com/install/
* For quick overview : https://www.wireguard.com/#conceptual-overview

$EMAIL_FOOTER
<<<<<<<<<<<<<<<<<<<<<<<<<

---INSTRUCTION#END--------------------------------------------------------------------
_EOF

    echo "[*] DONE added peer $peername in $peerdir/"
	echo "[*] check instructions in $instructions"
    ;;

srvconf)
    [ $# -ne 0 ] && usageexit
    [ ! -e $SERVER_DIR ] && err "server directory does not exist, use '$PROG srvinit' first"
	conf_load

    echo "[+] generating server configuration file"
	conf="$SERVER_DIR/$VPNIFACE.conf"
	[ -e $conf ] && trace cp $conf ${conf}.bak
	cat > $conf <<-_EOF
# auto-generated wireguard server configuration
# name: $VPNNAME
# tool: $PROG
# user: $(whoami)@$(hostname)
# path: $DIR
# time: $NOW
# DO NOT MODIFY THIS FILE

[Interface]
ListenPort = $(echo $VPNSERVER_ENDPOINT |cut -d':' -f2)
PrivateKey = $(cat $SERVER_PRIVKEY_FILE)
Address = $(cat $SERVER_IP_FILE)
${VPNSERVER_EXTRACONF}

_EOF
	[ -z "$(ls peer_*/serveraddition.conf 2>/dev/null)" ] && err "no peers found, use '$PROG peeradd' first"
	cat peer_*/serveraddition.conf >> $conf
	cat $conf
	echo "[*] DONE, generated server configuration in $conf"
	;;

srvdeploy)
    [ $# -ne 0 ] && usageexit
    [ ! -e $SERVER_DIR ] && err "server directory does not exist, use '$PROG srvinit' first"
	conf_load

	conf="$SERVER_DIR/$VPNIFACE.conf"
	[ ! -e $conf ] && err "server configuration does not exist, use '$PROG srvconf' first"
	[ -z "$VPNSERVER_SSH_HOST" ] && err "no ssh host defined (VPNSERVER_SSH_HOST) in configuration $conf"
	trace ssh $VPNSERVER_SSH_HOST "cp /etc/wireguard/$VPNIFACE.conf /etc/wireguard/$VPNIFACE.conf.bak.$NOW" ||true
	trace scp $conf $VPNSERVER_SSH_HOST:/etc/wireguard/
	trace ssh $VPNSERVER_SSH_HOST "wg-quick down $VPNIFACE; wg-quick up $VPNIFACE"
	echo "[*] DONE deployed configuration to $VPNSERVER_SSH_HOST and restarted $VPNIFACE wg interface"
	;;

help)
	cat <<-_EOF
Extended help:

'wg-confgen defaultconf' will generate a default wg-confgen.conf file in your current directory.
Edit this file with your VPN settings.
Then use wg-confgen to generate wireguard configuration for server and clients, as explained bellow.

'wg-confgen srvinit' will initialize wireguard server keys and store ip address in the following local files:
./server
./server/publickey
./server/privatekey
./server/ip

'wg-confgen peeradd' will create the following local configuration files for a new peer:
./peer_<peer-name>
./peer_<peer-name>/vpn-name.conf       # wg configuration
./peer_<peer-name>/vpn-name.conf.asc   # GPG encrypted wg configuration, only created if user_email argument was present
./peer_<peer-name>/instructions.txt    # instructions to be sent to the user on how to use the wg configuration
./peer_<peer-name>/serveraddition.conf
./peer_<peer-name>/publickey
./peer_<peer-name>/psk
./peer_<peer-name>/privatekey

'wg-confgen srvconf' will generate the wg server configuration in this local file:
./server/<vpn-name>.conf

'wg-confgen srvdeploy' (optional) will:
* scp ./server/<vpn-name>.conf to wg server host in /etc/wireguard/vpn-name.conf
* restart wg interface on wg server host using wg-quick

For example:
$ wg-confgen defaultconf
# go and edit wg-confgen.conf
$ wg-confgen srvinit 172.16.99.1/24
$ wg-confgen peeradd user1 172.16.99.2/24
$ wg-confgen peeradd user2 172.16.99.3/24 user2@mail.com
$ wg-confgen srvconf
$ wg-confgen srvdeploy 
wireguard is up and running on the server !
_EOF
	;;

*)
	usageexit
	;;

esac
