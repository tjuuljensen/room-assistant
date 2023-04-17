#!/bin/bash
# Install Room Assistant for presence detection on RPI Zero W
# https://www.room-assistant.io/guide/quickstart-pi-zero-w.html#installing-room-assistant
#
# Torsten Juul-Jensen

_help()
{
    SCRIPT_NAME=$(basename $0)
    echo "usage: $SCRIPT_NAME [--login-credentials <pi@ip.of.an.rpi>] [--ip <ip.of.an.rpi>] [--waitfor <seconds>] [--no-test]"
    # no-test
    exit 1
}

_waitForRaspberryPiHostName(){

  STEP=10
  STEPNO=$(expr $LISTENPERIOD / $STEP)

  # Listen for Raspberry pi on network
  echo "Looking for Raspbery Pi"
  echo "Will wait up to $LISTENPERIOD seconds..."
  i="0"
  while [ $i -lt $STEPNO ] ; do # do this  until LISTENPERIOD ends
    RASPBERRYPIIP=$(dig $REMOTEHOSTNAME +short)
    if [ -z $RASPBERRYPIIP ] ; then
      sleep $STEP
      i=$[$i+1]
    else
      break
    fi
  done

  if [ -z $RASPBERRYPIIP ] ; then
    echo No host found found.
    exit 1
  fi

  # return $RASPBERRYPIIP
}

_waitForRaspberryPiIP(){

  STEP=10
  STEPNO=$(expr $LISTENPERIOD / $STEP)

  # Listen for Raspberry pi on network
  echo "Looking for host at IP $RASPBERRYPIIP."
  echo "Waiting... (up to $LISTENPERIOD seconds)"
  i="0"
  while [ $i -lt $STEPNO ] ; do # do this x times
    IPISVALID=$(nmap $RASPBERRYPIIP -p 22 2>&1 | grep open )
    if  [[ ! $IPISVALID ]] ; then
      sleep $STEP
      i=$[$i+1]
    else
      break
    fi
  done

  if [[ -z $IPISVALID ]] ; then
    echo No host found on $RASPBERRYPIIP
    exit 1
  fi

  #return $RASPBERRYPIIP
}

_getLoginString() {

  if ($TESTPASS) ; then
    # Chech if the pi has default password
    PASSWORDVALID=$( ssh -J $REMOTEUSER:$REMOTEHOSTPASS@$RASPBERRYPIIP "exit" &>/dev/null )
    if ( $PASSWORDVALID ) ; then
      LOGINSTRING="$REMOTEUSER:$REMOTEHOSTPASS"
    else
      LOGINSTRING="$REMOTEUSER"
    fi
  fi
  #return $LOGINSTRING
}

_installRoomAssistant() {
  
  # Copy local.yml to host if it exist
  SCRIPTDIR=$( dirname $( realpath "${BASH_SOURCE[0]}" ))
  TEMPLATE_CONFIG=$SCRIPTDIR/local.yml
  CONFIGDIR=room-assistant/config
  CONFIGFILE=$CONFIGDIR/local.yml

  if [ -f $TEMPLATE_CONFIG ]; then 
    echo '### Transferring configuration file local.yml to host...'
    ssh $LOGINSTRING@$RASPBERRYPIIP "if [[ ! -d  $CONFIGDIR ]]; then mkdir -p $CONFIGDIR ;fi"
    scp $TEMPLATE_CONFIG $REMOTEUSER@$RASPBERRYPIIP:$CONFIGFILE
  fi
  
  ssh $LOGINSTRING@$RASPBERRYPIIP <<'EOF'

echo '### Installing NodeJS'
wget -O - https://raw.githubusercontent.com/tjuuljensen/room-assistant/main/install/install.sh | bash

EOF

}

_parseArguments () {

  declare -g -a LISTENPERIOD # seconds to listen for remote host
  declare -g -a RASPBERRYPIIP # remote host ip
  declare -g -a LOGINSTRING # remote host ip
  declare -g -a METHOD # determine hostname/ip method
  declare -g -a REMOTEHOSTNAME # remote hostname
  declare -g -a REMOTEHOSTPASS
  declare -g -a TESTPASS
  declare -g -a REMOTEUSER

  LISTENPERIOD=300 # Default value of 5 minutes
  METHOD="dns"
  REMOTEUSER="pi"
  REMOTEHOSTNAME="raspberrypi"
  REMOTEHOSTPASS="raspberry"
  TESTPASS=$(true)
  LOGINSTRING=$REMOTEUSER

      while [[ $# -gt 0 ]]
      do
        case $1 in
            -l | --login-credentials )
                if [[ $2 =~ "@" ]]; then
                  CREDS=${2%$"@"*}
                  REMOTEHOST=${2##${2%@*}"@"} # return everything after @

                  if [[ "$CREDS" =~ ":" ]]; then # a password has been supplied
                    REMOTEUSER=${CREDS%$":"*}
                    PASSWORD=${CREDS##${CREDS%:*}":"}
                    TESTPASS=$(false)
                    LOGINSTRING="$REMOTEUSER:$PASSWORD"
                  fi

                  if [[ $REMOTEHOST =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    RASPBERRYPIIP=$REMOTEHOST
                    METHOD="ip"
                  else
                    REMOTEHOSTNAME=$REMOTEHOST
                    METHOD="dns"
                  fi

                else
                  echo "When using -l or --login-credentials, credential must be supplied in the format UserName@[IpAddress | HostName]"
                  _help
                fi

                shift
                shift
                ;;
            -i | --ip)
              if [[ ! $2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo IP address must be a valid IP
                _help
              else
                RASPBERRYPIIP=$2
                METHOD="ip"
                # go and wait for ip to respond
              fi

              shift
              shift
              ;;
            -w | --waitfor)
              if [[ $2 =~ ^[0-9]+$ ]] ; then
                LISTENPERIOD=$2
              else
                echo No valid wait period entered
                _help
              fi
              shift
              shift
              ;;
            -n | --no-test )
              TESTPASS=$(false)
              shift
              ;;
            -h | --help )
              _help
              exit 1
              ;;
            * )
              if [[ $1 =~ "@" ]]; then
                CREDS=${1%$"@"*}
                REMOTEHOST=${1##${1%@*}"@"} # return everything after @

                if [[ "$CREDS" =~ ":" ]]; then # a password has been supplied
                  REMOTEUSER=${CREDS%$":"*}
                  PASSWORD=${CREDS##${CREDS%:*}":"}
                  TESTPASS=$(false)
                  LOGINSTRING="$REMOTEUSER:$PASSWORD"
                fi

                if [[ $REMOTEHOST =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    RASPBERRYPIIP=$REMOTEHOST
                    METHOD="ip"
                  else
                    REMOTEHOSTNAME=$REMOTEHOST
                    METHOD="dns"
                fi

              elif [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                RASPBERRYPIIP=$1
                METHOD="ip"
              else
                echo Could not parse commend line parameters.
                _help
              fi
             shift
        esac
    done
}

# Main

_parseArguments $@

if [ $METHOD == "dns" ]  ; then
  _waitForRaspberryPiHostName
elif [ $METHOD == "ip" ]  ; then
  _waitForRaspberryPiIP
fi
_getLoginString

_installRoomAssistant
