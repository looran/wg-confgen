wg-confgen - simple Wireguard configuration management tool

```
$ wg-confgen
usage: wg-confgen (srvinit | peeradd | srvconf | srvdeploy) <arguments...>
srvinit <ipaddress>
    create server base configuration (local file)
peeradd <peername> <ipaddress> [user_email]
    create a configuration file for a peer (local file)
srvconf
    generate server configuration with all peers (local file)
srvdeploy
    (active action) deploy server configuration and restart wg
help
    shows extended help
```

```
$ wg-confgen help
Extended help:

To use wg-confgen, you need to fill the following file in your current directory:
./wg-confgen.conf
Then you will use this script to generate wireguard configuration for server and clients.

'wg-confgen srvinit' will create a base wireguard server configuration stored in the following local files:
./server
./server/publickey
./server/privatekey
./server/vpn-name.base.conf

'wg-confgen peeradd' will create the following local configuration files for a new peer:
./peer_peer-name
./peer_peer-name/serveraddition.conf
./peer_peer-name/vpn-name.conf
./peer_peer-name/vpn-name.conf.asc    # GPG encrypted, only created if user_email argument was present
./peer_peer-name/publickey
./peer_peer-name/psk
./peer_peer-name/privatekey

'wg-confgen srvconf' will generate the wg server configuration in this local file:
./server/vpn-name.conf

'wg-confgen srvdeploy' (optional) will:
* scp ./server/vpn-name.conf to wg server host in /etc/wireguard/vpn-name.conf
* restart wg interface on wg server host using wg-quick

For example:
$ wg-confgen srvinit 172.16.99.1
$ wg-confgen peeradd user1 172.16.99.2
$ wg-confgen peeradd user2 172.16.99.3 user2@mail.com
$ wg-confgen peeradd laptop1 172.16.99.4
$ wg-confgen srvconf
$ wg-confgen srvdeploy 
wireguard is up and running on the server !
```
