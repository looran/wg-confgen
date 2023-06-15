### wg-confgen - simple Wireguard configuration management tool

wg-confgen generate Wireguard configuration files to be used with wg-quick.
It is meant for deployments where a single server will have multiple clients.

features:
* wg server configuration automatically updated (`wg-confgen srvconf`) when creating new clients (`wg-confgen peeradd`)
* wg server configuration automated deployment (`wg-confgen srvdeploy`)
* wg clients configuration filled-in with correct keys/IPs (`wg-confgen peeradd`)
* VPN instructions generated for each new client (`wg-confgen peeradd`)

Wireguard server/clients settings are created based on [wg-confgen.conf](#wg-confgen.conf default) file.

#### usage 

```
$ wg-confgen
usage: wg-confgen.sh (defaultconf | network | srvinit | peeradd | srvconf | srvdeploy) <arguments...>
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
```

#### wg-confgen.conf default

```
$ wg-confgen defaultconf
```

creates the following wg-confgen.conf file:

```
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
```

### extended help

```
$ wg-confgen help
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
```
