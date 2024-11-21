#!/bin/bash

# Default variables
function="install"
network="mainnet"

# Options processing
while test $# -gt 0; do
    case "$1" in
        -in|--install|-mn|--mainnet)
            function="install"
            ;;
        -up|--update)
            function="update"
            ;;
        -un|--uninstall)
            function="uninstall"
            ;;
        -sw|--switch)
            function="switch"
            ;;
        *)
            break
            ;;
    esac
    shift
done

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."
    sudo apt update
    sudo apt install docker.io -y
    sudo systemctl enable docker --now
fi

# Function for checking empty input
check_empty() {
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

# Function for confirming input
confirm_input() {
  echo "You have entered the following information:"
  echo "Node Name: $NAME"
  echo "Wallet Address: $WA"
  echo "Private Key: $PK"
  
  read -p "Is this information correct? (yes/no): " CONFIRM
  CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
  
  if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    echo "Let's try again..."
    return 1 
  fi
  return 0 
}

# Function to handle the installation process
install() {
    cd $HOME
    . <(wget -qO- https://raw.githubusercontent.com/mgpwnz/VS/main/docker.sh)

    mkdir -p $HOME/elixir

    while true; do
        NAME=""
        WA=""
        PK=""

        check_empty NAME "Enter node NAME: "
        check_empty WA "Wallet Address: "
        check_empty PK "Private Key: "

        echo "Choose network configuration:"
        select network in "mainnet" "testnet"; do
            case $network in
                mainnet)
                    break
                    ;;
                testnet)
                    break
                    ;;
            esac
        done
        
        if confirm_input; then break; fi
    done

    # Set CONFIRM_CHAINS based on selected network
    if [ "$network" == "mainnet" ]; then
        REPO='latest'
        ENV='prod'
    else
        REPO='v3'
        ENV='testnet'
    fi

# Create script 
tee $HOME/elixir/docker-compose.yml > /dev/null <<EOF
services:
  node:
    image: elixirprotocol/validator:$REPO
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

# Create .env
tee $HOME/elixir/.env > /dev/null <<EOF
ENV=$ENV

STRATEGY_EXECUTOR_IP_ADDRESS=`wget -qO- eth0.me`
STRATEGY_EXECUTOR_DISPLAY_NAME=$NAME
STRATEGY_EXECUTOR_BENEFICIARY=$WA
SIGNER_PRIVATE_KEY=$PK
EOF

    # Run the node
    docker compose -f $HOME/elixir/docker-compose.yml up -d
    echo "Node has been installed and started."
}

# Function to switch between networks
switch_network() {
    if [ ! -f "$HOME/elixir/.env" ]; then
        echo "Configuration file not found. Please run install first."
        return
    fi

    echo "Current configuration:"
    grep "ENV" "$HOME/elixir/.env"
    grep "image:" "$HOME/elixir/docker-compose.yml"

    # Switch network configuration
    read -p "Choose network (mainnet/testnet): " NETWORK
    NETWORK=$(echo "$NETWORK" | tr '[:upper:]' '[:lower:]')

    if [[ "$NETWORK" == "mainnet" ]]; then
        NEW_ENV="prod"
        NEW_REPO="latest"
    elif [[ "$NETWORK" == "testnet" ]]; then
        NEW_ENV="testnet"
        NEW_REPO="v3"
    else
        echo "Invalid choice. Please choose 'mainnet' or 'testnet'."
        return
    fi

    # Update .env file with the new network environment
    sed -i "s/^ENV=.*/ENV=$NEW_ENV/" "$HOME/elixir/.env"

    # Update docker-compose.yml with the new image repository
    sed -i "s|image: elixirprotocol/validator:.*|image: elixirprotocol/validator:$NEW_REPO|" "$HOME/elixir/docker-compose.yml"

    echo "Switched to $NETWORK configuration."

    # Restart Docker with the new configuration
    docker compose -f $HOME/elixir/docker-compose.yml down
    docker compose -f $HOME/elixir/docker-compose.yml pull
    docker compose -f $HOME/elixir/docker-compose.yml up -d
}

# Main functions for update and uninstall
update() {
    
    if grep -q "ENV=testnet" "$HOME/elixir/.env"; then
        REPO="elixirprotocol/validator:testnet"
    else
        REPO="elixirprotocol/validator"
    fi

    echo "Updating node to latest version for $REPO..."

    docker compose -f $HOME/elixir/docker-compose.yml down

    docker pull $REPO

    sed -i "s|image: elixirprotocol/validator:.*|image: $REPO|" "$HOME/elixir/docker-compose.yml"

    docker compose -f $HOME/elixir/docker-compose.yml up -d

    echo "Node has been updated successfully."
}


uninstall() {
    if [ -d "$HOME/elixir" ]; then
        read -r -p "Wipe all DATA? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                docker compose -f $HOME/elixir/docker-compose.yml down -v
                rm -rf $HOME/elixir
                ;;
            *)
                echo "Canceled"
                ;;
        esac
    fi
}

# Install wget if not present
sudo apt install wget -y &>/dev/null
cd

# Execute the selected function
if [ "$function" == "install" ]; then
    install
elif [ "$function" == "switch" ]; then
    switch_network
else
    $function
fi
