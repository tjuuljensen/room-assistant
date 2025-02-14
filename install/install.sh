#!/bin/bash

### Installing dependencies
echo '### Installing dependencies'
sudo apt-get update 
sudo apt-get install build-essential libavahi-compat-libdnssd-dev libsystemd-dev bluetooth libbluetooth-dev libudev-dev libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev

### Installing unattended upgrades
echo '### Installing unattended upgrades'
sudo apt install -y unattended-upgrades 
echo '### Creating unattended configuration file in /etc/apt/apt.conf.d/'
echo 'Unattended-Upgrade::Origins-Pattern {
//      Fix missing Rasbian sources.
        "origin=Debian,codename=${distro_codename},label=Debian";
        "origin=Debian,codename=${distro_codename},label=Debian-Security";
        "origin=Raspbian,codename=${distro_codename},label=Raspbian";
        "origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";
};

// Automatically reboot *WITHOUT CONFIRMATION* if
//  the file /var/run/reboot-required is found after the upgrade
Unattended-Upgrade::Automatic-Reboot "true";

// If automatic reboot is enabled and needed, reboot at the specific
// time instead of immediately
//  Default: "now"
Unattended-Upgrade::Automatic-Reboot-Time "03:00";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-raspbian

echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "3";
APT::Periodic::Verbose "1";
APT::Periodic::Unattended-Upgrade "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades

# Set autoanswer unattended upgrade mode
sudo dpkg-reconfigure --priority=medium unattended-upgrades
# INFO: Unattended-updates result can be tested using this command:
# sudo unattended-upgrade -d -v --dry-run


### Installing NodeJS
echo '### Installing NodeJS'

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

# Creates directory and downloads Node
TEMPDIR="$(mktemp -d)"
cd $TEMPDIR;
wget "${LATEST_BASE_URL}/${VERSION}/node-${VERSION}-linux-${PI_ARM_VERSION}.tar.gz"
tar -xzf node-$VERSION-linux-$PI_ARM_VERSION.tar.gz;

# This line will remove existing nodejs directory
sudo rm -rf /opt/nodejs;

# Copy Node over to the appropriate folder.
sudo mv node-$VERSION-linux-$PI_ARM_VERSION /opt/nodejs/;

# Create symlinks to node & npm
sudo ln -fs /opt/nodejs/bin/node /usr/bin/node;
sudo ln -fs /opt/nodejs/bin/node /usr/sbin/node;
sudo ln -fs /opt/nodejs/bin/node /sbin/node;
sudo ln -fs /opt/nodejs/bin/node /usr/local/bin/node;
sudo ln -fs /opt/nodejs/bin/npm /usr/bin/npm;
sudo ln -fs /opt/nodejs/bin/npm /usr/sbin/npm;
sudo ln -fs /opt/nodejs/bin/npm /sbin/npm;
sudo ln -fs /opt/nodejs/bin/npm /usr/local/bin/npm;


### Adding path to .profile
echo '### Adding NodeJS to PATH in .profile'
echo "PATH=""$PATH:/opt/nodejs/bin""" >> ~/.profile
source ~/.profile


### Setting permissions for bluetooth integrations
echo '### Setting permissions for bluetooth integrations'
sudo setcap cap_net_raw+eip $(eval readlink -f `which node`)
sudo setcap cap_net_raw+eip $(eval readlink -f `which hcitool`)
sudo setcap cap_net_admin+eip $(eval readlink -f `which hciconfig`)


### Creating sample config file
CONFIGDIR=~/room-assistant/config
CONFIGFILE=$CONFIGDIR/local.yml
SAMPLEFILE=$CONFIGFILE.example
echo "### Creating Room Assistant example config file in $CONFIGDIR"
mkdir -p $CONFIGDIR

echo "global:
  integrations:
    - homeAssistant
    - bluetoothClassic
homeAssistant:
  mqttUrl: 'mqtt://homeassistant.local:1883'
  mqttOptions:
    username: youruser
    password: yourpass
bluetoothClassic:
  interval: 20
  addresses:
  - <bluetooth-mac-of-device-to-track>
  minRssi:
    <bluetooth-mac-of-device-to-track>: -14
    default: -15
  entityOverrides:
    <bluetooth-mac-of-device-to-track>:
     id: phone_bt
     name: Phone BT" >  $SAMPLEFILE


### Creating service file
SERVICEFILE=/etc/systemd/system/room-assistant.service
TMPFILE=$(mktemp room-assistant.service.XXX)

echo '### Creating service file'
echo "[Unit]
Description=room-assistant service

[Service]
Type=notify
ExecStart=/opt/nodejs/bin/room-assistant
WorkingDirectory=/home/pi/room-assistant
TimeoutStartSec=120
TimeoutStopSec=30
Restart=always
RestartSec=10
WatchdogSec=60
User=pi

[Install]
WantedBy=multi-user.target" > $TMPFILE

sudo mv $TMPFILE $SERVICEFILE
sudo chown root $SERVICEFILE


### Install Room Assistant
echo '### Installing Room Assistant'
sudo npm i --global --unsafe-perm room-assistant

if [[ -f $CONFIGFILE ]]; then
  echo '### Run check of room-assistant'
  # cd ~/room-assistant
  # room-assistant
  echo room-assistant is now ready to run...
else 
  echo No config file found in $CONFIGDIR. Please create one and run room-assistant from this directory.
fi


### Enabling service
if [[ -f $CONFIGFILE && -f $SERVICEFILE ]]; then
  echo "### Enabling and starting room assistant service..."
  sudo systemctl enable room-assistant.service
  sudo systemctl start room-assistant.service
else 
  echo \nRoom assistant service was not enabled...
  echo When configuration is done, please enable and start it using:
  echo   systemctl enable room-assistant.service
  echo   systemctl start room-assistant.service
fi


### If hostname is raspberrypi, ask to change hostname
if [[ $(hostname) == 'raspberrypi' ]] ; then
    echo '### Optional change of hostname'
    echo Current hostname is $HOSTNAME
    read -r -p "Enter NEW hostname (or <Enter> to continue unchanged): " NEWHOSTNAME
    if [ ! -z $NEWHOSTNAME ] ; then
    sudo hostnamectl set-hostname --static "$NEWHOSTNAME"
    fi
fi