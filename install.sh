#!/bin/bash
# Default variables
function="install"
# Options
option_value(){ echo "$1" | sed -e 's%^--[^=]*=%%g; s%^-[^=]*=%%g'; }
while test $# -gt 0; do
        case "$1" in
        -in|--install)
            function="install"
            shift
            ;;
        -un|--uninstall)
            function="uninstall"
            shift
            ;;
        *|--)
    break
	;;
	esac
done
install() {
#docker install
cd $HOME
. <(wget -qO- https://raw.githubusercontent.com/mgpwnz/VS/main/docker.sh)
#create dir and config
if [ ! -d $HOME/elixir ]; then
  mkdir $HOME/elixir
fi
sleep 1

function check_empty {
  local varname=$1
  while [ -z "${!varname}" ]; do
    read -p "$2" input
    if [ -n "$input" ]; then
      eval $varname=\"$input\"
    else
      echo "The value cannot be empty. Please try again."
    fi
  done
}

function confirm_input {
  echo "You have entered the following information:"
  echo "Node Name: $NAME"
  echo "Wallet Adress: $WA"
  echo "Private Key: $PK"
  
  read -p "Is this information correct? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "Let's try again..."
    return 1 
  fi
  return 0 
}

while true; do
  NAME=""
  WA=""
  PK=""
  
  check_empty NAME "Enter node NAME: "
  check_empty WA "Wallet Adress: "
  check_empty PK "Private Key: "
  
  confirm_input
  if [ $? -eq 0 ]; then
    break 
  fi
done

echo "All data is confirmed. Proceeding..."

# Create script 
tee $HOME/elixir/docker-compose.yml > /dev/null <<EOF
version: "3.7"
name: elixir

services:
  node:
    image: elixirprotocol/validator:3.1.0
    restart: always
    env_file:
      - ./.env
    ports:
    - '17690:17690'
networks:
  default:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.200.0/24

EOF
#env
tee $HOME/chasm/.env > /dev/null <<EOF
ENV=testnet-3

STRATEGY_EXECUTOR_IP_ADDRESS=`wget -qO- eth0.me`
STRATEGY_EXECUTOR_DISPLAY_NAME=$NAME
STRATEGY_EXECUTOR_BENEFICIARY=$WA
SIGNER_PRIVATE_KEY=$PK
EOF
#Run nnode
docker compose -f $HOME/elixir/docker-compose.yml up -d
}
uninstall() {
if [ ! -d "$HOME/elixir" ]; then
    break
fi
read -r -p "Wipe all DATA? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
docker compose -f $HOME/elixir/docker-compose.yml down -v
rm -rf $HOME/elixir
        ;;
    *)
	echo Canceled
	break
        ;;
esac
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function