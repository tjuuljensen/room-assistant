#!/bin/bash

# Took the good bits from sdesalas/node-pi-zero/
# Switches to unofficial repo since armv6 was removed from main downloads
#
# Script modified by tjuuljensen (April 2023)

PI_ARM_VERSION=$(
   uname -a | 
   egrep 'armv[0-9]+l' -o
);

if [[ "$PI_ARM_VERSION" == ""armv6l"" ]]; then
	LATEST_BASE_URL="https://unofficial-builds.nodejs.org/download/release"
	LATEST_NODEJS_INDEX="${LATEST_BASE_URL}/index.json"
else
	LATEST_BASE_URL="https://nodejs.org/dist"
	LATEST_NODEJS_INDEX="${LATEST_BASE_URL}/index.json"
fi 

#VERSION=$(curl -sS $LATEST_NODEJS_INDEX | egrep $PI_ARM_VERSION | egrep '"lts":("[a-zA-Z]+")' | head -n 1 | egrep -o  '("version":")(v[0-9]+.[0-9]+.[0-9]+)"' | sed 's/"version"://' | tr -d '"')
# As there is a restriction on which version can run (must be <17) a new config has been added
VERSION=$(curl -sS $LATEST_NODEJS_INDEX | egrep $PI_ARM_VERSION | egrep '"lts":"Gallium"' | head -n 1 | egrep -o  '("version":")(v[0-9]+.[0-9]+.[0-9]+)"' | sed 's/"version"://' | tr -d '"')

# Creates directory for downloads, and downloads node
TEMPDIR="$(mktemp -d)"
cd $TEMPDIR;
wget "${LATEST_BASE_URL}/${VERSION}/node-${VERSION}-linux-${PI_ARM_VERSION}.tar.gz"
tar -xzf node-$VERSION-linux-$PI_ARM_VERSION.tar.gz;

# This line will clear existing nodejs
sudo rm -rf /opt/nodejs;

# This next line will copy Node over to the appropriate folder.
sudo mv node-$VERSION-linux-$PI_ARM_VERSION /opt/nodejs/;

# Create symlinks to node && npm
sudo ln -fs /opt/nodejs/bin/node /usr/bin/node;
sudo ln -fs /opt/nodejs/bin/node /usr/sbin/node;
sudo ln -fs /opt/nodejs/bin/node /sbin/node;
sudo ln -fs /opt/nodejs/bin/node /usr/local/bin/node;
sudo ln -fs /opt/nodejs/bin/npm /usr/bin/npm;
sudo ln -fs /opt/nodejs/bin/npm /usr/sbin/npm;
sudo ln -fs /opt/nodejs/bin/npm /sbin/npm;
sudo ln -fs /opt/nodejs/bin/npm /usr/local/bin/npm;
