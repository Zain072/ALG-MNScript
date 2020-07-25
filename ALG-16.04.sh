#!/bin/bash
# BitalGO Masternode Setup Script V2.0 for Ubuntu 16.04 LTS
#
# Script will attempt to autodetect primary public IP address
# and generate masternode private key unless specified in command line
#
# Usage:
# bash bitalgo.autoinstall.sh
#

#Color codes
RED='\033[0;91m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#TCP port
PORT=2706
RPC=2705

#Clear keyboard input buffer
function clear_stdin { while read -r -t 0; do read -r; done; }

#Delay script execution for N seconds
function delay { echo -e "${GREEN}Sleep for $1 seconds...${NC}"; sleep "$1"; }

#Stop daemon if it's already running
function stop_daemon {
    if pgrep -x 'bitalgod' > /dev/null; then
        echo -e "${YELLOW}Attempting to stop bitalgod${NC}"
        bitalgo-cli stop
        sleep 30
        if pgrep -x 'bitalgod' > /dev/null; then
            echo -e "${RED}bitalgod daemon is still running!${NC} \a"
            echo -e "${RED}Attempting to kill...${NC}"
            sudo pkill -9 bitalgod
            sleep 30
            if pgrep -x 'bitalgod' > /dev/null; then
                echo -e "${RED}Can't stop bitalgod! Reboot and try again...${NC} \a"
                exit 2
            fi
        fi
    fi
}
#Function detect_ubuntu

 if [[ $(lsb_release -d) == *16.04* ]]; then
   UBUNTU_VERSION=16
else
   echo -e "${RED}You are not running Ubuntu 16.04, Installation is cancelled.${NC}"
   exit 1

fi

#Process command line parameters
genkey=$1
clear

echo -e "${GREEN} ------- BitalGO MASTERNODE INSTALLER v2.0.0--------+
 |                                                  |
 |                                                  |::
 |       The installation will install and run      |::
 |        the masternode under a user BitalGO.         |::
 |                                                  |::
 |        This version of installer will setup      |::
 |           fail2ban and ufw for your safety.      |::
 |                                                  |::
 +------------------------------------------------+::
   ::::::::::::::::::::::::::::::::::::::::::::::::::S${NC}"
echo "Do you want me to generate a masternode private key for you?[y/n]"
read DOSETUP

if [[ $DOSETUP =~ "n" ]] ; then
          read -e -p "Enter your private key:" genkey;
              read -e -p "Confirm your private key: " genkey2;
    fi

#Confirming match
  if [ $genkey = $genkey2 ]; then
     echo -e "${GREEN}MATCH! ${NC} \a" 
else 
     echo -e "${RED} Error: Private keys do not match. Try again or let me generate one for you...${NC} \a";exit 1
fi
sleep .5
clear

# Determine primary public IP address
dpkg -s dnsutils 2>/dev/null >/dev/null || sudo apt-get -y install dnsutils
publicip=$(dig +short myip.opendns.com @resolver1.opendns.com)

if [ -n "$publicip" ]; then
    echo -e "${YELLOW}IP Address detected:" $publicip ${NC}
else
    echo -e "${RED}ERROR: Public IP Address was not detected!${NC} \a"
    clear_stdin
    read -e -p "Enter VPS Public IP Address: " publicip
    if [ -z "$publicip" ]; then
        echo -e "${RED}ERROR: Public IP Address must be provided. Try again...${NC} \a"
        exit 1
    fi
fi
if [ -d "/var/lib/fail2ban/" ]; 
then
    echo -e "${GREEN}Packages already installed...${NC}"
else
    echo -e "${GREEN}Updating system and installing required packages...${NC}"

sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt-get -y autoremove
sudo apt-get -y install wget nano htop jq
sudo apt-get install unzip
sudo apt -y install software-properties-common
   fi

#Generating Random Password for  JSON RPC
rpcuser=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

#Create 2GB swap file
if grep -q "SwapTotal" /proc/meminfo; then
    echo -e "${GREEN}Skipping disk swap configuration...${NC} \n"
else
    echo -e "${YELLOW}Creating 2GB disk swap file. \nThis may take a few minutes!${NC} \a"
    touch /var/swap.img
    chmod 600 swap.img
    dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
    mkswap /var/swap.img 2> /dev/null
    swapon /var/swap.img 2> /dev/null
    if [ $? -eq 0 ]; then
        echo '/var/swap.img none swap sw 0 0' >> /etc/fstab
        echo -e "${GREEN}Swap was created successfully!${NC} \n"
    else
        echo -e "${RED}Operation not permitted! Optional swap was not created.${NC} \a"
        rm /var/swap.img
    fi
fi
 
#Installing Daemon
cd ~
rm -rf /usr/local/bin/bitalgod*
wget https://github.com/BitalgoCOIN/BitalGO/releases/download/v2.0/BitalGO-v2.0-daemon-ubuntu-16.04.tar.gz
tar -xzvf BitalGO-v2.0-daemon-ubuntu-16.04.tar.gz
sudo chmod -R 755 bitalgo-cli
sudo chmod -R 755 bitalgod
cp -p -r bitalgod /usr/local/bin
cp -p -r bitalgo-cli /usr/local/bin

 bitalgo-cli stop
 sleep 5
 #Create datadir
 if [ ! -f ~/.bitalgo/bitalgo.conf ]; then 
 	sudo mkdir ~/.bitalgo
 fi

cd ~
clear
echo -e "${YELLOW}Creating bitalgo.conf...${NC}"

# If genkey was not supplied in command line, we will generate private key on the fly
if [ -z $genkey ]; then
    cat <<EOF > ~/.bitalgo/bitalgo.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
EOF

    sudo chmod 755 -R ~/.bitalgo/bitalgo.conf

    #Starting daemon first time just to generate masternode private key
    bitalgod -daemon
sleep 7
while true;do
    echo -e "${YELLOW}Generating masternode private key...${NC}"
    genkey=$(bitalgo-cli createmasternodekey)
    if [ "$genkey" ]; then
        break
    fi
sleep 7
done
    fi
    
    #Stopping daemon to create bitalgo.conf
    bitalgo-cli stop
    sleep 5
cd ~/.bitalgo/ && rm -rf blocks chainstate sporks
cd ~/.bitalgo/ && wget http://192.248.149.49/bootstrap.tar.gz
cd ~/.bitalgo/ && tar -xzvf bootstrap.tar.gz
sudo rm -rf ~/.bitalgo/bootstrap.tar.gz

# Create bitalgo.conf
cat <<EOF > ~/.bitalgo/bitalgo.conf
rpcuser=$rpcuser
rpcpassword=$rpcpassword
rpcallowip=127.0.0.1
rpcport=$RPC
port=$PORT
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
masternode=1
externalip=$publicip
bind=$publicip
masternodeaddr=$publicip
masternodeprivkey=$genkey
addnode=209.250.241.251
addnode=45.32.54.101
addnode=139.180.128.244
addnode=136.244.86.167
addnode=216.128.135.202
addnode=155.138.149.23
addnode=192.248.149.49


 
EOF
    bitalgod -daemon
#Finally, starting daemon with new bitalgo.conf
printf '#!/bin/bash\nif [ ! -f "~/.bitalgo/bitalgod.pid" ]; then /usr/local/bin/bitalgod -daemon ; fi' > /root/bitalgoauto.sh
chmod -R 755 bitalgoauto.sh
#Setting auto start cron job for bitalgod
if ! crontab -l | grep "bitalgoauto.sh"; then
    (crontab -l ; echo "*/5 * * * * /root/bitalgodauto.sh")| crontab -
fi

echo -e "========================================================================
${GREEN}Masternode setup is complete!${NC}
========================================================================
Masternode was installed with VPS IP Address: ${GREEN}$publicip${NC}
Masternode Private Key: ${GREEN}$genkey${NC}
Now you can add the following string to the masternode.conf file 
======================================================================== \a"
echo -e "${GREEN}bitalgod_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
echo -e "========================================================================
Use your mouse to copy the whole string above into the clipboard by
tripple-click + single-click (Dont use Ctrl-C) and then paste it 
into your ${GREEN}masternode.conf${NC} file and replace:
    ${GREEN}bitalgod_mn1${NC} - with your desired masternode name (alias)
    ${GREEN}TxId${NC} - with Transaction Id from masternode outputs
    ${GREEN}TxIdx${NC} - with Transaction Index (0 or 1)
     Remember to save the masternode.conf and restart the wallet!
To introduce your new masternode to the bitalgod network, you need to
issue a masternode start command from your wallet, which proves that
the collateral for this node is secured."

clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "Wait for the node wallet on this VPS to sync with the other nodes
on the network. Eventually the 'Is Synced' status will change
to 'true', which will indicate a complete sync, although it may take
from several minutes to several hours depending on the network state.
Your initial Masternode Status may read:
    ${GREEN}Node just started, not yet activated${NC} or
    ${GREEN}Node  is not in masternode list${NC}, which is normal and expected.
"
clear_stdin
read -p "*** Press any key to continue ***" -n1 -s

echo -e "
${GREEN}...scroll up to see previous screens...${NC}
Here are some useful commands and tools for masternode troubleshooting:
========================================================================
To view masternode configuration produced by this script in bitalgo.conf:
${GREEN}cat ~/.bitalgo/bitalgo.conf${NC}
Here is your bitalgo.conf generated by this script:
-------------------------------------------------${GREEN}"
echo -e "${GREEN}bitalgod_mn1 $publicip:$PORT $genkey TxId TxIdx${NC}"
cat ~/.bitalgo/bitalgo.conf
echo -e "${NC}-------------------------------------------------
NOTE: To edit bitalgo.conf, first stop the bitalgod daemon,
then edit the bitalgo.conf file and save it in nano: (Ctrl-X + Y + Enter),
then start the bitalgod daemon back up:
to stop:              ${GREEN}bitalgo-cli stop${NC}
to start:             ${GREEN}bitalgod${NC}
to edit:              ${GREEN}nano ~/.bitalgo/bitalgo.conf${NC}
to check mn status:   ${GREEN}bitalgo-cli masternode status${NC}
========================================================================
To monitor system resource utilization and running processes:
                   ${GREEN}htop${NC}
========================================================================
"