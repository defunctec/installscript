#!/bin/bash

# Usage: ./crown-server-install.sh [OPTION]...
#
# Setup crown server or update existing one

LATEST_RELEASE="0.13.2.0"

systemnode=false
masternode=false
help=false
install=false
unknown=()
appname=$(basename "$0")

print_help()
{
echo "Usage: $(basename "$0") [OPTION]...
Setup crown server or update existing one

  -m, --masternode                  create a masternode
  -s, --systemnode                  create a systemnode
  -p, --privkey=privkey             set private key
  -v, --version=version             set version, default will be the latest release
  -h, --help                        display this help and exit

"
}

handle_arguments()
{
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -h|--help)
                help=true
                shift
                ;;
            -m|--masternode)
                masternode=true
                shift
                ;;
            -s|--systemnode)
                systemnode=true
                shift
                ;;
            -p|--privkey)
                privkey="$2"
                shift
                shift
                ;;
            --privkey=*)
                privkey="${key#*=}"
                shift
                ;;
            -v|--version)
                LATEST_RELEASE="$2"
                shift
                shift
                ;;
            --version=*)
                LATEST_RELEASE="${key#*=}"
                shift
                ;;

            *)    # unknown option
                unknown+=("$1") # save it in an array
                shift
                ;;
        esac
    done
    if [ "$help" = true ] ; then
        print_help
        exit 0
    fi

    # Check if there are unknown arguments
    if [ ${#unknown[@]} -gt 0 ] ; then
        printf "$appname: unrecognized option '${unknown[0]}'\nTry '$appname --help' for more information.\n"
        exit 1
    fi

    # Check if only one of the options is set
    if [ "$masternode" = true ] && [ "$systemnode" = true ] ; then
        echo "'-m|masternode' and '-s|--systemnode' options are mutually exclusive."
        exit 1
    fi

    # Check if private key is set and not empty
    if [ ! -z ${privkey+x} ] && [ -z "$privkey" ]; then
        printf "$appname: option '-p|--privkey' requires an argument'\nTry '$appname --help' for more information.\n"
        exit 1
    fi

    # Check if '-m' or '-s' option is set with '-p'
    if [ ! -z "$privkey" ] && [ "$masternode" != true ] && [ "$systemnode" != true ] ; then
        printf "$appname: If private key is set '-m' or '-s' option is mandatory'\nTry '$appname --help' for more information.\n"
        exit 1
    fi

    # If private key is set then install otherwise update
    if [ ! -z "$privkey" ]; then
        install=true
    fi
    echo $LATEST_RELEASE
}

# Clear Screen
clear_screen() {
     clear
}

# Software install
install_dependencies() {
    echo Installing software...
    sleep 2
    sudo apt install ufw -y
    sudo apt install unzip -y
    sudo apt install nano -y
    sudo apt install p7zip -y
    sudo apt install curl -y
}

# Attempt to create 1GB swap ram
create_swap() {
    if [ `sudo swapon | wc -l` -lt 2 ]; then
        echo Creating swap...
        sleep 2
        sudo mkdir -p /var/cache/swap/   
        sudo dd if=/dev/zero of=/var/cache/swap/myswap bs=1M count=1024
        sudo chmod 600 /var/cache/swap/myswap
        sudo mkswap /var/cache/swap/myswap
        sudo swapon /var/cache/swap/myswap
        swap_line='/var/cache/swap/myswap   none    swap    sw  0   0'
        # Add the line only once 
        sudo grep -q -F "$swap_line" /etc/fstab || echo "$swap_line" | sudo tee --append /etc/fstab > /dev/null
        cat /etc/fstab
    fi
}

# Update OS
update_repos() {
    echo Updateing OS, please wait...
    sleep 2
    sudo apt update
    sudo DEBIAN_FRONTEND=noninteractive apt -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
}

# Download Crown client (Update link with new client)
download_package() {
    echo Downloading latest Crown client...
    sleep 2
    # Create temporary directory
    dir=`mktemp -d`
    if [ -z "$dir" ]; then
        # Create directory under $HOME if above operation failed
        dir=$HOME/crown-temp
        mkdir -p $dir
    fi
    # 32 or 64 bit? If getconf fails we'll assume 64
    BITS=$(getconf LONG_BIT 2>/dev/null)
    if [ $? -ne 0 ]; then
       BITS=64
    fi
    # Change this later to take latest release version.
    wget "https://github.com/Crowndev/crowncoin/releases/download/v0.13.2.0/Crown-$LATEST_RELEASE-Linux64.zip" -O $dir/crown.zip
}

# Install Crown client
install_package() {
    echo Installing Crown client...
    sleep 2
    sudo unzip -d $dir/crown $dir/crown.zip
    sudo cp -f $dir/crown/*/bin/* /usr/local/bin/
    sudo cp -f $dir/crown/*/lib/* /usr/local/lib/
    sudo rm -rf $dir
}

# Firewall
configure_firewall() {
    echo Setting up firewall...
    sleep 1
    sudo ufw allow ssh/tcp
    sudo ufw limit ssh/tcp
    sudo ufw allow 9340/tcp
    sudo ufw allow 21
    sudo ufw allow 22
    sudo ufw logging on
    sudo ufw --force enable
}

add_cron_job() {
    cron_line="@reboot /usr/local/bin/crownd"
    if [ `crontab -l 2>/dev/null | grep "$cron_line" | wc -l` -eq 0 ]; then
        (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    fi
}

# Maintenance scripts
maintenance_scripts() {
    echo Downloading scripts and other useful tools...
    sudo wget "https://www.dropbox.com/s/kucyc0fupop6vca/crwrestart.sh?dl=0" -O restart.sh | bash && sudo chmod +x restart.sh
    sudo wget "https://www.dropbox.com/s/gq4vxog7riom739/whatsmyip.sh?dl=0" -O whatsmyip.sh | bash && sudo chmod +x whatsmyip.sh
}

# Zabbix Install
zabbix_install() {
# Declare variable choice and assign value 4
echo Would you like to install a Zabbix agent?
choice=3
# Print to stdout
 echo "1. Yes"
 echo "2. No"
 echo -n "1 for Yes 2 for No [1 or 2]? "
# Loop while the variable choice is equal 4
# bash while loop
while [ $choice -eq 3 ]; do
 
# read user input
read choice
# bash nested if/else
if [ $choice -eq 1 ] ; then
 
        echo "You have chosen to install a Zabbix agent"
        sudo wget http://repo.zabbix.com/zabbix/3.4/debian/pool/main/z/zabbix-release/zabbix-release_3.4-1+stretch_all.deb
        sudo dpkg -i zabbix-release_3.4-1+stretch_all.deb
        sudo apt update -y
        sudo apt install zabbix-agent -y
        echo 1.Edit zabbix agent configuration file using 'nano /etc/zabbix/zabbix_agentd.conf'
        echo Server=[zabbix server ip] Hostname=[Hostname of Node] EG, Server=192.168.1.10 Hostname=MN1
        

else                   

        if [ $choice -eq 2 ] ; then
                 echo "Skip Zabbix agent installation"           
                 
        else
         
                if [ $choice -eq 3 ] ; then
                        echo "Would you like to install Zabbix agent?"
                else
                        echo "Please make a choice between Yes or No !"
                        echo "1. Yes"
                        echo "2. No"
                        echo -n "1 for Yes 2 for No [1 or 2]? "
                        choice=3
                fi   
        fi
fi
done
}

configure_conf() {
    cd $HOME
    mkdir -p .crown
    sudo mv .crown/crown.conf .crown/crown.bak
    touch .crown/crown.conf
    IP=$(curl http://checkip.amazonaws.com/)
    PW=$(< /dev/urandom tr -dc a-zA-Z0-9 | head -c32;echo;)
    echo "==========================================================="
    pwd
    echo "daemon=1" > .crown/crown.conf 
    echo "rpcallowip=127.0.0.1" >> .crown/crown.conf 
    echo "rpcuser=crowncoinrpc">> .crown/crown.conf 
    echo "rpcpassword="$PW >> .crown/crown.conf 
    echo "listen=1" >> .crown/crown.conf 
    echo "server=1" >>.crown/crown.conf 
    echo "externalip="$IP >>.crown/crown.conf 
    if [ "$systemnode" = true ] ; then
        echo "systemnode=1" >>.crown/crown.conf
        echo "systemnodeprivkey="$privkey >>.crown/crown.conf
    elif [ "$masternode" = true ] ; then
        echo "masternode=1" >>.crown/crown.conf
        echo "masternodeprivkey="$privkey >>.crown/crown.conf
    fi
    cat .crown/crown.conf
}

# Crown package
main() {
    # Clear screen
    clear_screen
    # (Quietly) Stop crownd (in case it's running)
    /usr/local/bin/crown-cli stop 2>/dev/null
    # Install Packages
    install_dependencies
    # Download the latest release
    download_package
    # Extract and install
    install_package
    # Create swap to help with sync
    if [ "$install" = true ] ; then
        # Create swap to help with sync
        create_swap
        # Create folder structures and configure crown.conf
        configure_conf
        # Configure firewall
        configure_firewall
    fi
    update_repos
    # Configure firewall
    add_cron_job
    # Maintenance Scripts
    maintenance_scripts
    # Install Zabbix
    zabbix_install
    # Install VPN
    vpn_install
}

handle_arguments "$@"
main