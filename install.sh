#!/bin/bash

#
# Check if user is root
#
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use the root user to install the software."
    exit 1
fi

if [ ! -f /etc/debian_version ]; then 
    echo "Unsupported Linux Distribution. Prepared for Debian"
    exit 1
fi

#############################################################################
# What do we need anyway
apt-get update
apt-get -y upgrade
apt-get -y install dnsutils unzip whiptail git build-essential alsa-base alsa-utils stunnel4 html2text curl

install_basic (){
#############################################################################
# Set hostname, FQDN, add to sources list

sed -e 's/127.0.0.1       localhost/127.0.0.1       localhost.localdomain   localhost/g' -i /etc/hosts
cat >> /etc/hosts <<EOF
${serverIP} ${HOSTNAMEFQDN} ${HOSTNAMESHORT}
EOF

#New User
adduser Cubietruck
usermod -aG sudo Cubietruck


echo "$HOSTNAMESHORT" > /etc/hostname
/etc/init.d/hostname.sh start >/dev/null 2>&1
}
#############################################################################

install_samba (){
#############################################################################
# install Samba file sharing
#
# Reade samba user
#
SMBUSER=$(whiptail --inputbox "What is your samba username?" 8 78 $SMBUSER --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
#
# Reade samba pass
#
SMBPASS=$(whiptail --inputbox "What is your samba password?" 8 78 $SMBPASS --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi
#
# Reade samba group
#
SMBGROUP=$(whiptail --inputbox "What is your samba group?" 8 78 $SMBGROUP --title "$SECTION" 3>&1 1>&2 2>&3)
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi

apt-get -y install samba samba-common-bin
useradd $SMBUSER
echo -ne "$SMBPASS\n$SMBPASS\n" | passwd $SMBUSER
echo -ne "$SMBPASS\n$SMBPASS\n" | smbpasswd -a -s $SMBUSER
service samba stop
 cat > /etc/samba/smb.conf <<"EOF"
[global]
	workgroup = SMBGROUP
	server string = %h server
	hosts allow = SUBNET
	log file = /var/log/samba/log.%m
	max log size = 1000
	syslog = 0
	panic action = /usr/share/samba/panic-action %d
	load printers = yes
	printing = cups
	printcap name = cups
	netbios name = HOSTNAMESHORT
	
[printers]
	comment = All Printers
	path = /var/spool/samba
	browseable = no
	public = yes
	guest ok = yes
	writable = no
	printable = yes
	printer admin = SMBUSER

[print$]
	comment = Printer Drivers
	path = /etc/samba/drivers
	browseable = yes
	guest ok = no
	read only = yes
	write list = SMBUSER
	
[data]
	comment = Storage	
	path = /mnt/data/data
	writable = yes
	public = no
	valid users = SMBUSER
	force create mode = 0777
	force directory mode = 0777

[homes]
   comment = Home Directories
   browseable = no
   read only = no
   create mask = 0700
   directory mask = 0700
   valid users = %S

[fhem]
	comment = fhem Verzeichnis
	path = /opt/fhem
	valid users = SMBUSER
	read only = No
	create mask = 0777
	directory mask = 0777

#[www]
#	comment = www (htdocs) Verzeichnis
#	path = /var/www
#	valid users = alex
#	read only = No#z
#	create mask = 0777
#	directory mask = 0777
EOF
sed -i "s/SMBGROUP/$SMBGROUP/" /etc/samba/smb.conf
sed -i "s/SMBUSER/$SMBUSER/" /etc/samba/smb.conf
sed -i "s/SUBNET/$SUBNET/" /etc/samba/smb.conf
sed -i "s/HOSTNAMESHORT/$HOSTNAMESHORT/" /etc/samba/smb.conf
mkdir /ext
chmod -R 777 /ext
service samba start
}
#############################################################################

install_cups (){
#############################################################################
#Install printer system
apt-get -y install cups lpr foomatic-filters
sed -e 's/Listen localhost:631/Listen 631/g' -i /etc/cups/cupsd.conf
sed -e 's/<Location \/>/<Location \/>\nallow $SUBNET/g' -i /etc/cups/cupsd.conf
sed -e 's/<Location \/admin>/<Location \/admin>\nallow $SUBNET/g' -i /etc/cups/cupsd.conf
sed -e 's/<Location \/admin\/conf>/<Location \/admin\/conf>\nallow $SUBNET/g' -i /etc/cups/cupsd.conf
service cups restart
service samba restart
} 
#############################################################################

install_rpimonitor (){
#############################################################################
if !(grep -qs XavierBerger "/etc/apt/sources.list");then
cat >> /etc/apt/sources.list <<EOF
# RPi-Monitor official repository
deb https://github.com XavierBerger/RPi-Monitor-deb/raw/master/repo/
EOF
fi
apt-get update
apt-get -y install rpimonitor
}
#############################################################################

install_temper (){
#############################################################################
#Install USB temperature sensor
apt-get -y install libusb-dev libusb-1.0-0-dev
wget https://github.com/igorpecovnik/Debian-micro-home-server/blob/master/src/temper_v14_altered.tgz
tar xvfz temper_v14_altered.tgz
cd temperv14
make
make rules-install
cp temperv14 /usr/bin/temper
}
#############################################################################

install_scaner_and_scanbuttons (){
#############################################################################
#Install Scanner buttons
apt-get -y install pdftk libusb-dev sane sane-utils libudev-dev imagemagick 
# wget http://wp.psyx.us/wp-content/uploads/2010/10/scanbuttond-0.2.3.genesys.tar.gz
wget https://github.com/igorpecovnik/Debian-micro-home-server/blob/master/src/scanbuttond-0.2.3.genesys.tar.gz
tar xvfz scanbuttond-0.2.3.genesys.tar.gz
rm scanbuttond-0.2.3.genesys.tar.gz
cd scanbuttond-0.2.3.genesys
chmod +x configure
make clean 
./configure --prefix=/usr --sysconfdir=/etc
make
make install
echo "sane-find-scanner" >> /etc/scanbuttond/initscanner.sh
sed -e 's/does nothing./does nothing.\n\/usr\/bin\/scanbuttond/g' -i /etc/rc.local
} 
#############################################################################

install_ocr (){
#############################################################################
# Install OCR
# get script from here https://github.com/gkovacs/pdfocr
wget https://raw2.github.com/gkovacs/pdfocr/master/pdfocr.rb
mv pdfocr.rb /usr/local/bin/pdfocr
chmod +x /usr/local/bin/pdfocr
apt-get -y install ruby tesseract-ocr libtiff-tools
} 
#############################################################################

install_Virus (){
#############################################################################
#Install Amavisd-new, SpamAssassin, And Clamav
apt-get -y install amavisd-new spamassassin clamav clamav-daemon zoo unzip bzip2 arj nomarch lzop cabextract apt-listchanges libnet-ldap-perl libauthen-sasl-perl clamav-docs daemon libio-string-perl libio-socket-ssl-perl libnet-ident-perl zip libnet-dns-perl
/etc/init.d/spamassassin stop
insserv -rf spamassassin
}
#############################################################################

install_FHEM (){
#############################################################################
#Install PERL
#apt-get install -f
apt-get -y install perl libdevice-serialport-perl libio-socket-ssl-perl libwww-perl
#
#Install FHEM 5.5
cd /tmp
wget http://fhem.de/fhem-5.5.deb 
dpkg -i fhem-5.5.deb
rm fhem-5.5.deb
chmod -R a+w /opt/fhem
usermod -aG tty fhem
# Jabber-Perl-Module
sudo cpan Net::Jabber
# Jawbone-Perl-Module
sudo cpan -i WWW::Jawbone::Up
}

install_HMLAND () {
cd /opt/
apt-get install build-essential libusb-1.0-0-dev make gcc git-core
git clone git://git.zerfleddert.de/hmcfgusb
cd hmcfgusb
make
cat > /etc/init.d/hmland <<"EOF"
# simple init for hmland

pidfile=/var/run/hmland.pid
port=1234

case "$1" in
 start|"")
	chrt 50 /opt/hmcfgusb/hmland -r 03:30 -d -P -l 127.0.0.1 -p $port 2>&1 | perl -ne '$|=1; print localtime . ": [hmland] $_"' >> /var/log/hmland.log &
	;;
 restart|reload|force-reload)
	echo "Error: argument '$1' not supported" >&2
	exit 3
	;;
 stop)
	killall hmland
	;;
 status)
	if [ ! -e $pidfile ]; then
		echo "No pid"
		exit 1
	fi
	pid=`cat $pidfile`
	if kill -0 $pid &>1 > /dev/null; then
		echo "Running"
		exit 0
	else
		rm $pidfile
		echo "Not running"
		exit 1
	fi

	;;
 *)
	echo "Usage: hmland [start|stop|status]" >&2
	exit 3
	;;
esac
EOF
sudo chmod 755 /etc/init.d/hmland
sudo update-rc.d hmland defaults
service hmland start
}
#############################################################################

install_ShairportSync (){
#############################################################################
#Install ShairportSync
apt-get install build-essential
apt-get install avahi-daemon autoconf libtool libdaemon-dev libssl-dev libavahi-client-dev libasound2-dev
apt-get install libpopt-dev
apt-get install mpd
cd /opt
git clone https://github.com/mikebrady/shairport-sync.git
cd /opt/shairport-sync
autoreconf -i -f
./configure --with-alsa --with-avahi --with-ssl=openssl
make
make install
cd /etc/init.d
chmod a+x shairport-sync
update-rc.d shairport-sync defaults
useradd -g audio shairport-sync
sudo /etc/init.d/shairport-sync start
}
#############################################################################

install_Netatalk (){
#############################################################################
#Install Netatalk
apt-get install avahi-daemon
apt-get install netatalk
}
#############################################################################

install_Netatalk (){
#############################################################################
#Install Netatalk
apt-get install hfsplus hfsutils hfsprogs
}
#############################################################################

SECTION="Basic configuration"
#
# Read IP address
#
serverIP=$(ip route get 8.8.8.8 | awk '{ print $NF; exit }')
serverIP=$(whiptail --inputbox "What is your IP?" 8 78 $serverIP --title "$SECTION" 3>&1 1>&2 2>&3)
set ${serverIP//./ }
SUBNET="$1.$2.$3."
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi

#
# Read full qualified hostname
#
HOSTNAMEFQDN=$(hostname -f)
HOSTNAMEFQDN=$(whiptail --inputbox "What is your full qualified hostname?" 8 78 $HOSTNAMEFQDN --title "$SECTION" 3>&1 1>&2 2>&3)
set ${HOSTNAMEFQDN//./ }
HOSTNAMESHORT="$1"
exitstatus=$?; if [ $exitstatus = 1 ]; then exit 1; fi




install_basic
install_hfs+
install_Netatalk
#install_samba
install_rpimonitor
#install_temper
#install_Virus
#install_scaner_and_scanbuttons
#install_ocr
#install_cups
#apt-get -y install socat
#install_ShairportSync
#install_HMLAND
#install_FHEM
#reboot
