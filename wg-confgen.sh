#!/bin/sh

# Wireguard VPN configuration management script
# 2019, Laurent Ghigonis

set -e

usageexit() {
    cat <<-_EOF
usage: $PROG (srvinit | peeradd | srvconf | srvdeploy) <arguments...>
srvinit <ipaddress>
    create server base connfiguration (local file)
peeradd <peername> <ipaddress> [user_email]
    create a configuration file for a peer (local file)
srvconf
    generate server configuration with all peers (local file)
srvdeploy
	(optional) deploy server configuration and restart wg

You need to have and fill the following file in your current directory:
./wg-confgen.conf

srvinit will create a base wireguard server configuration stored in the following local files:
./server
./server/publickey
./server/privatekey
./server/vpn-name.base.conf

peeradd will create the following local configuration files for a new peer:
./peer_peer-name
./peer_peer-name/serveraddition.conf
./peer_peer-name/vpn-name.conf
./peer_peer-name/vpn-name.conf.asc    # GPG encrypted, only created if user_email argument was present
./peer_peer-name/publickey
./peer_peer-name/psk
./peer_peer-name/privatekey

srvconf will generate the wg server configuration in this local file:
./server/vpn-name.conf

srvdeploy (optional) will:
* scp ./server/vpn-name.conf to wg server host in /etc/wireguard/vpn-name.conf
* restart wg interface on wg server host using wg-quick
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

PROG="$(basename $0)"
DIR="$(pwd)"
CONF="$DIR/wg-confgen.conf"

[ $# -lt 1 ] && usageexit
[ ! -e "$CONF" ] && err "wg-confgen.conf not found in current directory !"
source "$CONF"
[ -z "$VPNSERVER_NAME" ] && err "VPNSERVER_NAME variable not set in configuration ! (file $CONF)"
VPNSERVER_PUBLICKEY="$DIR/server/publickey"
NOW="$(date "+%Y%m%d_%H%M")"
umask 077

action="$1"

shift
case $action in

srvinit)
    [ $# -lt 1 ] && usageexit
	ipaddress="$1"

	serverdir="$DIR/server"
    [ -e $serverdir ] && err "server directory already exists : $serverdir"
    trace mkdir $serverdir
    privatekey="$serverdir/privatekey"
    publickey="$serverdir/publickey"
	baseconf="$serverdir/$VPNNAME.base.conf"
    echo "[+] generating keys"
    wg genkey |tee "$privatekey" |wg pubkey > "$publickey"
    echo "[+] creating base configuration file"
	cat > $baseconf <<-_EOF
# server base configuration created on $NOW
[Interface]
ListenPort = $(echo $VPNSERVER_ENDPOINT |cut -d':' -f2)
PrivateKey = $(cat $privatekey)
Address = $(echo $ipaddress)/$SUBNET
PostUp = sysctl -w net.ipv4.conf.%i.forwarding=1
${VPNCLIENT_EXTRACONF}

_EOF
    echo "[*] DONE generated Wireguard base configuration to $baseconf"
    ;;

peeradd)
    [ $# -lt 2 ] && usageexit

    [ ! -e $VPNSERVER_PUBLICKEY ] && err "server public key not found ! file $VPNSERVER_PUBLICKEY"
    peername="$1"
    ipaddress="$2"
	email="$3"
    peerdir="$DIR/peer_${peername}"
    privatekey="$peerdir/privatekey"
    publickey="$peerdir/publickey"
    pskkey="$peerdir/psk"
    conf="$peerdir/$VPNNAME.conf"
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
# $BRAND configuration for peer $peername, created on $NOW
[Interface]
PrivateKey = $(cat "$privatekey")
Address = $ipaddress/$SUBNET
${VPNCLIENT_EXTRACONF}
[Peer]
PublicKey = $(cat "$VPNSERVER_PUBLICKEY")
AllowedIPs = ${VPNSERVER_ALLOWEDIPS}
EndPoint = ${VPNSERVER_ENDPOINT}
PresharedKey = $(cat $pskkey)
_EOF

    echo "[+] creating configuration file addition for server"
    cat > "$confsrv" <<-_EOF
# peer $peername, added on $NOW
[Peer]
PublicKey = $(cat "$publickey")
AllowedIPs = $ipaddress/32
PresharedKey = $(cat $pskkey)

_EOF

	INSTRUCTION_SEND="Send the following message to user of peer ${peername}, with configuration attached:
$conf

Use encryption to share the configuration, like PGP.
"
	if [ ! -z "$email" ]; then
		confgpg="$conf.asc"
		INSTRUCTION_SEND="Send the following message to user of peer ${peername}, with GPG encrypted configuration attached:
$confgpg
To:
$email"
		gpg -a -e -r "$email" -o $confgpg $conf
	fi

    echo
    cat > "$instructions" <<-_EOF
---INSTRUCTION#1 : Update Wireguard Server configuration ---------------------------

On $VPNSERVER_NAME wg server, you have to update $VPNNAME configuration

To do so you have 2 options:
A. automated: use the command '$PROG srvconf' then '$PROG srvdeploy'
B: manual: on $VPNSERVER_NAME add the following to configuration /etc/wireguard/$VPNNAME.conf, then restart wg:

$(cat "$confsrv")

wg-quick down $VPNNAME
wg-quick up $VPNNAME

---INSTRUCTION#2 : Send Wireguard client configuration to ower of peer ---------------------

$INSTRUCTION_SEND
Subject:
$BRAND configuration for user $peername
>>>>>>>>>>>>>>>>>>>>>>>>>
Hello ${peername},

Attached is your Wireguard configuration for $BRAND.
You can start the VPN with 'wg-quick up $(basename $conf)', and turning it down using 'wg-quick down $(basename $conf)'.

In this $BRAND your IP address will be ${ipaddress}.
$VPNINFORMATIONS

For more informations regarding Wireguard:
* check wg(8) and wg-quick(8) manual pages
* For installation   : https://www.wireguard.com/install/
* For quick overview : https://www.wireguard.com/#conceptual-overview

$FOOTER
<<<<<<<<<<<<<<<<<<<<<<<<<

---INSTRUCTION#END--------------------------------------------------------------------
_EOF
	cat "$instructions"

    echo
    echo "[*] DONE added peer $peername in $peerdir/, check instructions above"
    ;;

srvconf)
    [ $# -ne 0 ] && usageexit
	serverdir="$DIR/server"
    [ ! -e $serverdir ] && err "server directory does not exist, use '$PROG srvinit' first"
	conf="$serverdir/$VPNNAME.conf"
	[ -e $conf ] && trace cp $conf ${conf}.bak
	echo "[+] generating new server configuration"
	cat > $conf <<-_EOF
# $BRAND auto-generated configuration on $NOW
# tool: $PROG
# user: $(whoami)@$(hostname)
# path: $DIR
# DO NOT MODIFY THIS FILE

_EOF
	[ ! -e peer_*/serveraddition.conf ] && err "no peers found, use '$PROG peeradd' first"
	cat $serverdir/$VPNNAME.base.conf peer_*/serveraddition.conf >> $conf
	cat $conf
	echo "[*] DONE, generated server configuration in $conf"
	;;

srvdeploy)
	serverdir="$DIR/server"
    [ ! -e $serverdir ] && err "server directory does not exist, use '$PROG srvinit' first"
	conf="$serverdir/$VPNNAME.conf"
	[ ! -e $conf ] && err "server configuration does not exist, use '$PROG srvconf' first"
	[ -z "$VPNSERVER_SSH_HOST" ] && err "no ssh host defined (VPNSERVER_SSH_HOST) in configuration $conf"
	trace ssh $VPNSERVER_SSH_HOST "cp /etc/wireguard/$VPNNAME.conf /etc/wireguard/$VPNNAME.conf.bak.$NOW" ||true
	trace scp $conf $VPNSERVER_SSH_HOST:/etc/wireguard/
	trace ssh $VPNSERVER_SSH_HOST "wg-quick down $VPNNAME; wg-quick up $VPNNAME"
	echo "[*] DONE deployed configuration to $VPNSERVER_SSH_HOST and restarted $VPNNAME wg interface"
	;;

*)
	usageexit
	;;

esac
