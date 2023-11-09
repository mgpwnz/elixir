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
#docker install
cd
touch $HOME/.bash_profile
if ! docker --version; then
		echo -e "${C_LGn}Docker installation...${RES}"
		sudo apt update
		sudo apt upgrade -y
		sudo apt install curl apt-transport-https ca-certificates gnupg lsb-release -y
		. /etc/*-release
		wget -qO- "https://download.docker.com/linux/${DISTRIB_ID,,}/gpg" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		sudo apt update
		sudo apt install docker-ce docker-ce-cli containerd.io -y
		docker_version=`apt-cache madison docker-ce | grep -oPm1 "(?<=docker-ce \| )([^_]+)(?= \| https)"`
		sudo apt install docker-ce="$docker_version" docker-ce-cli="$docker_version" containerd.io -y
	fi
	if ! docker-compose --version; then
		echo -e "${C_LGn}Docker Сompose installation...${RES}"
		sudo apt update
		sudo apt upgrade -y
		sudo apt install wget jq -y
		local docker_compose_version=`wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name"`
		sudo wget -O /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-`uname -s`-`uname -m`"
		sudo chmod +x /usr/bin/docker-compose
		. $HOME/.bash_profile
	fi
cd $HOME
mkdir elixir && cd elixir
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
sudo systemctl disable subspace-farmer.service
sudo systemctl disable subspace-node.service
sudo rm /etc/systemd/system/subspace-farmer.service /etc/systemd/system/subspace-node.service
sudo rm /usr/local/bin/subspace-farmer /usr/local/bin/subspace-node 
sudo rm -rf $HOME/subspace_adv $HOME/.local/share/subspace-node/
echo "Done"
cd $HOME
}
update() {
cd $HOME
sudo apt update &> /dev/null
sudo apt install wget -y &> /dev/null
sudo apt-get install libgomp1 -y &> /dev/null
#download cli
wget https://github.com/subspace/subspace/releases/download/${version}/subspace-node-ubuntu-x86_64-skylake-${version} &> /dev/null
wget https://github.com/subspace/subspace/releases/download/${version}/subspace-farmer-ubuntu-x86_64-skylake-${version} &> /dev/null
sleep 1
sudo mv subspace-node-ubuntu-x86_64-skylake-${version} /usr/local/bin/subspace-node
sudo mv subspace-farmer-ubuntu-x86_64-skylake-${version} /usr/local/bin/subspace-farmer
sudo chmod +x /usr/local/bin/subspace*
sleep 1
# Enabling services
    sudo systemctl daemon-reload
# Starting services
    sudo systemctl restart subspace-node.service
    sudo systemctl restart subspace-farmer.service
echo -e "Your subspace node \e[32mUpdate\e[39m!"
cd $HOME
}
# Actions
sudo apt install wget -y &>/dev/null
cd
$function
