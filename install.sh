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
	    -up|--update)
            function="update"
            shift
            ;;
        *|--)
		break
		;;
	esac
done
install() {
cd $HOME
mkdir $HOME/elixir && cd $HOME/elixir
wget -q O- Dockerfile https://files.elixir.finance/Dockerfile 
read -p "Enter wallet address: " EVM_WALLET_ADDRESS
sed -i -e "s%ENV ADDRESS=0x.*%ENV ADDRESS=$EVM_WALLET_ADDRESS%g" $HOME/elixir/Dockerfile
read -p "Enter Private Key: " EVM_PK
sed -i -e "s%ENV PRIVATE_KEY=0x.*%ENV PRIVATE_KEY=0x$EVM_PK%g" $HOME/elixir/Dockerfile
read -p "Enter Validator Name: " Name
sed -i -e "s%ENV VALIDATOR_NAME=AnonValidator.*%ENV VALIDATOR_NAME=$Name%g" $HOME/elixir/Dockerfile
docker build . -f Dockerfile -t elixir-validator &&\
docker run -d --restart unless-stopped --name ev elixir-validator
sleep 2
cd
echo Done!

}
uninstall() {
cd $HOME
docker kill ev &&\
docker rm ev &&\
rm -rf $HOME/elixir
cd $HOME
echo Done!
}
update() {
sudo apt update &> /dev/null
cd $HOME/elixir
docker kill ev
docker rm ev
docker pull elixirprotocol/validator:testnet-2
docker build . -f Dockerfile -t elixir-validator &&\
docker run -d --restart unless-stopped --name ev elixir-validator
cd $HOME
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function