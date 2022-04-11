#!/bin/sh

D="$(realpath $(dirname $0))"
F="$D/README.md"
trace() { echo "# $*"; "$@"; }

[ -e $F ] && trace cp $F $F.bak

cat > $F <<-_EOF
### wg-confgen - simple Wireguard configuration management tool

wg-confgen generate Wireguard configuration files to be used with wg-quick.
It is meant for deployments where a single server will have multiple clients.

features:
* wg server configuration automatically updated (\`wg-confgen srvconf\`) when creating new clients (\`wg-confgen peeradd\`)
* wg server configuration automated deployment (\`wg-confgen srvdeploy\`)
* wg clients configuration filled-in with correct keys/IPs (\`wg-confgen peeradd\`)
* VPN instructions generated for each new client (\`wg-confgen peeradd\`)

Wireguard server/clients settings are created based on [wg-confgen.conf](#wg-confgen.conf default) file.

#### usage 

\`\`\`
$ wg-confgen
$($D/wg-confgen.sh)
\`\`\`

#### wg-confgen.conf default

\`\`\`
$ wg-confgen defaultconf
\`\`\`

creates the following wg-confgen.conf file:

\`\`\`
$(d=$(mktemp --tmpdir -d tmp.wgconfgenreadme.XXX) \
	&& cd $d \
	&& $D/wg-confgen.sh defaultconf >/dev/null \
	&& cat wg-confgen.conf \
	&& rm $d/wg-confgen.conf \
	&& rmdir $d)
\`\`\`

### extended help

\`\`\`
$ wg-confgen help
$($D/wg-confgen.sh help)
\`\`\`
_EOF

echo "[*] generated $F"
