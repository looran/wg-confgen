wg-confgen - simple Wireguard configuration management tool

```
usage: wg-confgen.sh (srvinit | peeradd | srvconf | srvdeploy) <arguments...>
srvinit <ipaddress>
    create server base connfiguration (local file)
peeradd <peername> <ipaddress> [user_email]
    create a configuration file for a peer (local file)
srvconf
    generate server configuration with all peers (local file)
srvdeploy
(optional) deploy server configuration and restart wg

You need to have and fill the following configuration file in your current directory:
./wg-confgen.conf

srvinit will create a base wireguard configuration for the server stored in the following local files:
./server
./server/publickey
./server/privatekey
./server/vpn-name.base.conf

peeradd will create the following local configuration files for a new wireguard peer:
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
* scp ./server/vpn-name.conf to wg server in file /etc/wireguard/vpn-name.conf
wg server ssh host is set by configuration variable VPNSERVER_SSH_HOST
* restart wg interface on wg server host using wg-quick
```
