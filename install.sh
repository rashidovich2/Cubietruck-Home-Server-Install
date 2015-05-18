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
sudo service shairport-sync stop
cat > /etc/init.d/shairport-sync <<"EOF"
#! /bin/sh
### BEGIN INIT INFO
# Provides:          shairport-sync
# Required-Start:    $all
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Shairport Synchronous AirPlay
# Description:       Implements a synchronous (multi-room-capable) AirPlay receiver
### END INIT INFO

# Author: Mike Brady <mikebrady@eircom.net>
#
# Do NOT "set -e"

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="AirPlay Synchronous Audio Service"
NAME=shairport-sync
DAEMON=/usr/local/bin/$NAME

# We don't use the DAEMON_ARGS variable here because some of the identifiers may have spaces in them, and so are
# impossible to pass as arguments.

# Instead, we add the arguments directly to the relevant line in the do_start() function below

PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

# Load the VERBOSE setting and other rcS variables
. /lib/init/vars.sh

# Define LSB log_* functions.
# Depend on lsb-base (>= 3.2-14) to ensure that this file is present
# and status_of_proc is working.
. /lib/lsb/init-functions

#
# Function that starts the daemon/service
#
do_start()
{
	# Return
	#   0 if daemon has been started
	#   1 if daemon was already running
	#   2 if daemon could not be started
	start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
		|| return 1

# This script is set to start running after all other services have started.
# However, if you find that Shairport Sync is still being started before what it needs is ready,
# uncomment the next line to get the script to wait for three seconds before attempting to start Shairport Sync.
#	sleep 3

# Uncomment just one of the following start-stop-daemon lines, or comment them all out and add your own.
# In the default script, the first line is uncommented, selecting daemon mode (-d), the default device and software volume control
# BTW, if you're using software volume control, you may have to use alsamixer or similar to set the output device's volume to its maximum level first
# BTW2, you can use alsamixer to find device identifiers (e.g. hw:1) and mixer names (e.g. "Speaker"). No need to change ALSA's defaults.
# BTW3, the argument after -a is simply the name the shairport service will be visible as.
	start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- -d -a "Wohnzimmer" || return 2
#	start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- -d -a "Topping TP30 or Griffin iMic on Raspberry Pi" -- -d hw:1 -t hardware -c "PCM" || return 2
#	start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- -d -a "'3D Sound' USB Soundcard on Raspberry Pi" -- -d hw:1 -t hardware -c "Speaker" || return 2
# BTW, that "3D Sound" USB soundcard sometimes has the mixer name "Headphone" rather than "Speaker" -- use alsamixer to check.
#	start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- -d -a "IQaudIO" -- -d hw:1 -t hardware -c "Playback Digital" || return 2
# BTW, newer versions of IQaudIO have a different mixer name -- use alsamixer to check.
	# Add code here, if necessary, that waits for the process to be ready
	# to handle requests from services started subsequently which depend
	# on this one.  As a last resort, sleep for some time.
}

#
# Function that stops the daemon/service
#
do_stop()
{
	# Return
	#   0 if daemon has been stopped
	#   1 if daemon was already stopped
	#   2 if daemon could not be stopped
	#   other if a failure occurred
	start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile $PIDFILE --name $NAME
	RETVAL="$?"
	[ "$RETVAL" = 2 ] && return 2
	# Wait for children to finish too if this is a daemon that forks
	# and if the daemon is only ever run from this initscript.
	# If the above conditions are not satisfied then add some other code
	# that waits for the process to drop all resources that could be
	# needed by services started subsequently.  A last resort is to
	# sleep for some time.
	start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
	[ "$?" = 2 ] && return 2
	# Many daemons don't delete their pidfiles when they exit.
	rm -f $PIDFILE
	return "$RETVAL"
}

#
# Function that sends a SIGHUP to the daemon/service
#
do_reload() {
	#
	# If the daemon can reload its configuration without
	# restarting (for example, when it is sent a SIGHUP),
	# then implement that here.
	#
	start-stop-daemon --stop --signal 1 --quiet --pidfile $PIDFILE --name $NAME
	return 0
}

case "$1" in
  start)
	[ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
	do_start
	case "$?" in
		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
	;;
  stop)
	[ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
	do_stop
	case "$?" in
		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
	;;
  status)
	status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
	;;
  #reload|force-reload)
	#
	# If do_reload() is not implemented then leave this commented out
	# and leave 'force-reload' as an alias for 'restart'.
	#
	#log_daemon_msg "Reloading $DESC" "$NAME"
	#do_reload
	#log_end_msg $?
	#;;
  restart|force-reload)
	#
	# If the "reload" option is implemented then remove the
	# 'force-reload' alias
	#
	log_daemon_msg "Restarting $DESC" "$NAME"
	do_stop
	case "$?" in
	  0|1)
		do_start
		case "$?" in
			0) log_end_msg 0 ;;
			1) log_end_msg 1 ;; # Old process is still running
			*) log_end_msg 1 ;; # Failed to start
		esac
		;;
	  *)
		# Failed to stop
		log_end_msg 1
		;;
	esac
	;;
  *)
	#echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload}" >&2
	echo "Usage: $SCRIPTNAME {start|stop|status|restart|force-reload}" >&2
	exit 3
	;;
esac

:

EOF
sudo service shairport-sync start
}
#############################################################################

install_AudioOutonToslink (){
#############################################################################
#Config Audio Output on Toslink
cat > /etc/modules <<"EOF"
# /etc/modules: kernel modules to load at boot time.
#
# This file contains the names of kernel modules that should be loaded
# at boot time, one per line. Lines beginning with "#" are ignored.
# Parameters can be specified after the module name.

sndspdif
sunxi-sndspdif
sunxi-spdif
sunxi-spdma
hci_uart
gpio_sunxi
bt_gpio
wifi_gpio
rfcomm
hidp
sunxi-ir
bonding
spi_sun7i
bcmdhd

EOF

cat > /etc/asound.conf <<"EOF"
pcm.!default {
type hw
card 1
device 0
}
ctl.!default {
type hw
card 1
}

EOF
}
#############################################################################

install_Netatalk (){
#############################################################################
#Install Netatalk
apt-get install avahi-daemon libavahi-client-dev libdb-dev db-util libgcrypt11 libgcrypt11-dev
apt-get install netatalk
sudo chmod 777 /mnt/TimeCapsule
sudo chown -R cubie.users /mnt/TimeCapsule
cat > /etc/netatalk/afpd.conf <<"EOF"
#
# CONFIGURATION FOR AFPD
#
# Each single line defines a virtual server that should be available.
# Though, using "\" character, newline escaping is supported.
# Empty lines and lines beginning with `#' are ignored.
# Options in this file will override both compiled-in defaults
# and command line options.
#
#
# Format:
#  - [options]               to specify options for the default server
#  "Server name" [options]   to specify an additional server
#
#
# The following options are available:
#   Transport Protocols:
#     -[no]tcp       Make "AFP over TCP" [not] available
#     -[no]ddp       Make "AFP over AppleTalk" [not] available.
#                    If you have -proxy specified, specify -uamlist "" to 
#                    prevent ddp connections from working.
#
#     -transall      Make both available
#
#   Transport Options:
#     -ipaddr <ipaddress> Specifies the IP address that the server should
#                         advertise and listens to. The default is advertise
#                         the first IP address of the system, but to listen
#                         for any incoming request. The network address may
#                         be specified either in dotted-decimal format for
#                         IPv4 or in hexadecimal format for IPv6.
#                         This option also allows to use one machine to
#                         advertise the AFP-over-TCP/IP settings of another
#                         machine via NBP when used together with the -proxy
#                         option.
#     -server_quantum <number> 
#                         Specifies the DSI server quantum. The minimum
#                         value is 1MB. The max value is 0xFFFFFFFF. If you 
#                         specify a value that is out of range, you'll get 
#                         the default value (currently the minimum).
#     -admingroup <groupname>
#                         Specifies the group of administrators who should
#                         all be seen as the superuser when they log in.
#                         Default is disabled.
#     -ddpaddr x.y        Specifies the DDP address of the server.
#                         the  default is to auto-assign an address (0.0).
#                         this is only useful if you're running on
#                         a multihomed host.
#     -port <number>      Specifies the TCP port the server should respond
#                         to (default is 548)
#     -fqdn <name:port>   specify a fully-qualified domain name (+optional
#                         port). this gets discarded if the server can't
#                         resolve it. this is not honored by appleshare
#                         clients <= 3.8.3 (default: none)
#     -hostname <name>    Use this instead of the result from calling
#                         hostname for dertermening which IP address to
#                         advertise, therfore the hostname is resolved to
#                         an IP which is the advertised. This is NOT used for
#                         listening and it is also overwritten by -ipaddr.
#     -proxy              Run an AppleTalk proxy server for specified
#                         AFP/TCP server (if address/port aren't given,
#                         then first IP address of the system/548 will
#                         be used).
#                         if you don't want the proxy server to act as
#                         a ddp server as well, set -uamlist to an empty
#                         string.
#     -dsireadbuf [number]
#                         Scale factor that determines the size of the
#                         DSI/TCP readahead buffer, default is 12. This is
#                         multiplies with the DSI server quantum (default
#                         ~300k) to give the size of the buffer. Increasing
#                         this value might increase throughput in fast local
#                         networks for volume to volume copies.  Note: This
#                         buffer is allocated per afpd child process, so
#                         specifying large values will eat up large amount of
#                         memory (buffer size * number of clients).
#     -tcprcvbuf [number]
#                         Try to set TCP receive buffer using setsockpt().
#                         Often OSes impose restrictions on the applications
#                         ability to set this value.
#     -tcpsndbuf [number]
#                         Try to set TCP send buffer using setsockpt().
#                         Often OSes impose restrictions on the applications
#                         ability to set this value.
#     -slp                Register this server with the Service Location
#                         Protocol (if SLP support was compiled in).
#     -nozeroconf         Don't register this server with the Multicats
#                         DNS Protocol.
#     -advertise_ssh      Allows Mac OS X clients (10.3.3-10.4) to
#                         automagically establish a tunneled AFP connection
#                         through SSH. This option is not so significant
#                         for the recent Mac OS X. See the Netatalk Manual
#                         in detail.
#
#
#   Authentication Methods:
#     -uampath <path>  Use this path to look for User Authentication Modules.
#                      (default: /usr/lib/netatalk)
#     -uamlist <a,b,c> Comma-separated list of UAMs.
#                      (default: uams_dhx.so,uams_dhx2.so)
#
#                      some commonly available UAMs:
#                      uams_guest.so: Allow guest logins
#
#                      uams_clrtxt.so: (uams_pam.so or uams_passwd.so)
#                                     Allow logins with passwords
#                                     transmitted in the clear. 
#
#                      uams_randnum.so: Allow Random Number and Two-Way
#                                      Random Number exchange for
#                                      authentication.
#
#                      uams_dhx.so: (uams_dhx_pam.so or uams_dhx_passwd.so)
#                                  Allow Diffie-Hellman eXchange
#                                  (DHX) for authentication.
#
#                      uams_dhx2.so: (uams_dhx2_pam.so or uams_dhx2_passwd.so)
#                                   Allow Diffie-Hellman eXchange 2
#                                   (DHX2) for authentication.
#
#   Password Options:
#     -[no]savepassword   [Don't] Allow clients to save password locally
#     -passwdfile <path>  Use this path to store Randnum passwords.
#                         (Default: /etc/netatalk/afppasswd. The only other
#                         useful value is ~/.passwd. See 'man afppasswd'
#                         for details.)
#     -passwdminlen <#>   minimum password length. may be ignored.
#     -[no]setpassword    [Don't] Allow clients to change their passwords.
#     -loginmaxfail <#>   maximum number of failed logins. this may be
#                         ignored if the uam can't handle it.
#
#   AppleVolumes files:
#     -defaultvol <path>  Specifies path to AppleVolumes.default file
#                         (default /etc/netatalk/AppleVolumes.default,
#                         same as -f on command line)
#     -systemvol <path>   Specifies path to AppleVolumes.system file
#                         (default /etc/netatalk/AppleVolumes.system,
#                         same as -s on command line)
#     -[no]uservolfirst   [Don't] read the user's ~/AppleVolumes or
#                         ~/.AppleVolumes before reading
#                         /etc/netatalk/AppleVolumes.default
#                         (same as -u on command line)
#     -[no]uservol        [Don't] Read the user's volume file
#     -closevol           Immediately unmount volumes removed from
#                         AppleVolumes files on SIGHUP sent to the afp
#                         master process.
#
#   Miscellaneous:
#     -authprintdir <path> Specifies the path to be used (per server) to 
#                          store the files required to do CAP-style
#                          print authentication which papd will examine
#                          to determine if a print job should be allowed.
#                          These files are created at login and if they
#                          are to be properly removed, this directory
#                          probably needs to be umode 1777
#     -guestname "user"   Specifies the user name for the guest login
#                         (default "nobody", same as -g on command line)
#     -loginmesg "Message"  Client will display "Message" upon logging in
#                         (no default, same as -l "Message" on commandline)
#     -nodebug            Switch off debugging
#     -client_polling     With this switch enabled, afpd won't advertise
#                         that it is capable of server notifications, so that
#                         connected clients poll the server every 10 seconds
#                         to detect changes in opened server windows.
#                         Note: Depending on the number of simultaneously
#                         connected clients and the network's speed, this can
#                         lead to a significant higher load on your network!
#     -sleep   <number>   AFP 3.x wait number hours before disconnecting
#                         clients in sleep mode. Default 10 hours
#     -tickleval <number> Specify the tickle timeout interval (in seconds).
#                         Note, this defaults to 30 seconds, and really 
#                         shouldn't be changed.  If you want to control
#                         the server idle timeout, use the -timeout option.
#     -timeout <number>   Specify the number of tickles to send before
#                         timing out a connection.
#                         The default is 4, therefore a connection will
#                         timeout in 2 minutes.
#     -[no]icon           [Don't] Use the platform-specific icon. Recent
#                         Mac OS don't display it any longer.
#     -volnamelen <number>
#                         Max length of UTF8-MAC volume name for Mac OS X.
#                         Note that Hangul is especially sensitive to this.
#                           255: limit of spec
#                           80:  limit of generic Mac OS X (default)
#                           73:  limit of Mac OS X 10.1, if >= 74
#                                Finder crashed and restart repeatedly.
#                         Mac OS 9 and earlier is not influenced by this,
#                         Maccharset volume names are always limitted to 27.
#     -[un]setuplog "<logtype> <loglevel> [<filename>]"
#                         Specify that any message of a loglevel up to the
#                         given loglevel should be logged to the given file.
#                         If the filename is ommited the loglevel applies to
#                         messages passed to syslog.
#
#                         By default (no explicit -setuplog and no buildtime
#                         configure flag --with-logfile) afpd logs to syslog
#                         with a default logging setup equivalent to
#                         "-setuplog default log_info".
#
#                         If build with --with-logfile[=somefile]
#                         (default logfile /var/log/netatalk.log) afpd
#                         defaults to a setup that is equivalent to
#                         "-setuplog default log_info [netatalk.log|somefile]"
#
#                         logtypes:  Default, AFPDaemon, Logger, UAMSDaemon
#                         loglevels: LOG_SEVERE, LOG_ERROR, LOG_WARN,
#                                    LOG_NOTE, LOG_INFO, LOG_DEBUG,
#                                    LOG_DEBUG6, LOG_DEBUG7, LOG_DEBUG8,
#                                    LOG_DEBUG9, LOG_MAXDEBUG
#
#                Example: Useful default config
#                         -setuplog "default log_info /var/log/afpd.log"
#
#                         Debugging config
#                         -setuplog "default log_maxdebug /var/log/afpd.log"
#
#     -signature { user:<text> | auto }
#                         Specify a server signature. This option is useful
#                         while running multiple independent instances of
#                         afpd on one machine (eg. in clustered environments,
#                         to provide fault isolation etc.).
#                         Default is "auto".
#                         "auto" signature type allows afpd generating
#                         signature and saving it to afp_signature.conf
#                         automatically (based on random number).
#                         "host" signature type switches back to "auto"
#                         because it is obsoleted.
#                         "user" signature type allows administrator to
#                         set up a signature string manually.
#                         Examples: three servers running on one machine:
#                               first   -signature user:USERS
#                               second  -signature user:USERS
#                               third   -signature user:ADMINS
#                         First two servers will act as one logical AFP
#                         service. If user logs in to first one and then
#                         connects to second one, session will be
#                         automatically redirected to the first one. But if
#                         client connects to first and then to third, 
#                         will be asked for password twice and will see
#                         resources of both servers.
#                         Traditional method of signature generation causes
#                         two independent afpd instances to have the same
#                         signature and thus cause clients to be redirected
#                         automatically to server (s)he logged in first.
#     -k5keytab <path>
#     -k5service <service>
#     -k5realm <realm>
#                         These are required if the server supports
#                         Kerberos 5 authentication
#     -ntdomain
#     -ntseparator
#                         Use for eg. winbind authentication, prepends
#                         both strings before the username from login and
#                         then tries to authenticate with the result
#                         through the availabel and active UAM authentication
#                         modules.
#     -dircachesize entries
#                         Maximum possible entries in the directory cache.
#                         The cache stores directories and files. It is used
#                         to cache the full path to directories and CNIDs
#                         which considerably speeds up directory enumeration.
#                         Default size is 8192, maximum size is 131072. Given
#                         value is rounded up to nearest power of 2. Each
#                         entry takes about 100 bytes, which is not much, but
#                         remember that every afpd child process for every
#                         connected user has its cache.
#     -fcelistener host[:port]
#                         Enables sending FCE events to the specified host,
#                         default port is 12250 if not specified. Specifying
#                         mutliple listeners is done by having this option
#                         once for each of them.
#     -fceevents fmod,fdel,ddel,fcre,dcre,tmsz
#                         Speficies which FCE events are active, default is
#                         fmod,fdel,ddel,fcre,dcre.
#     -fcecoalesce all|delete|create
#                         Coalesce FCE events.
#     -fceholdfmod seconds
#                         This determines the time delay in seconds which is
#                         always waited if another file modification for the
#                         same file is done by a client before sending an FCE
#                         file modification event (fmod). For example saving
#                         a file in Photoshop would generate multiple events
#                         by itself because the application is opening,
#                         modifying and closing a file mutliple times for
#                         every "save". Defautl: 60 seconds.
#     -keepsessions       Enable "Continuous AFP Service". This means the
#                         ability to stop the master afpd process with a
#                         SIGQUIT signal, possibly install an afpd update and
#                         start the afpd process. Existing AFP sessions afpd
#                         processes will remain unaffected. Technically they
#                         will be notified of the master afpd shutdown, sleep
#                         15-20 seconds and then try to reconnect their IPC
#                         channel to the master afpd process. If this
#                         reconnect fails, the sessions are in an undefined
#                         state. Therefor it's absolutely critical to restart
#                         the master process in time!
#     -noacl2maccess      Don't map filesystem ACLs to effective permissions.
#
#   Codepage Options:
#     -unixcodepage <CODEPAGE>  Specifies the servers unix codepage,
#                               e.g. "ISO-8859-15" or "UTF8".
#                               This is used to convert strings to/from
#                               the systems locale, e.g. for authenthication.
#                               Defaults to LOCALE if your system supports it,
#                               otherwise ASCII will be used.
#
#     -maccodepage <CODEPAGE>   Specifies the legacy clients (<= Mac OS 9)
#                               codepage, e.g. "MAC_ROMAN".
#                               This is used to convert strings to the
#                               systems locale, e.g. for authenthication
#                               and SIGUSR2 messaging. This will also be
#                               the default for volumes maccharset.
#
#   CNID related options:
#     -cnidserver <ipaddress:port>
#                               Specifies the IP address and port of a
#                               cnid_metad server, required for CNID dbd
#                               backend. Defaults to localhost:4700.
#                               The network address may be specified either
#                               in dotted-decimal format for IPv4 or in
#                               hexadecimal format for IPv6.
#
#   Avahi (Bonjour) related options:
#     -mimicmodel <model>
#                               Specifies the icon model that appears on
#                               clients. Defaults to off. Examples: RackMac
#                               (same as Xserve), PowerBook, PowerMac, Macmini,
#                               iMac, MacBook, MacBookPro, MacBookAir, MacPro,
#                               AppleTV1,1, AirPort
#
#
# Some examples:
#
#       The simplest case is to not have an afpd.conf.
#
#       4 servers w/ names server1-3 and one w/ the hostname. servers
#       1-3 get routed to different ports with server 3 being bound 
#       specifically to address 192.168.1.3
#
#           -
#           server1 -port 12000
#           server2 -port 12001
#           server3 -port 12002 -ipaddr 192.168.1.3
#
#       a dedicated guest server, a user server, and a special
#       AppleTalk-only server:
#
#           "Guest Server" -uamlist uams_guest.so \
#                   -loginmesg "Welcome guest! I'm a public server."
#           "User Server" -uamlist uams_dhx2.so -port 12000
#           "special" -ddp -notcp -defaultvol <path> -systemvol <path>
#
# default:
# - -tcp -noddp -uamlist uams_dhx.so,uams_dhx2.so -nosavepassword
- -tcp -noddp -uamlist uams_dhx2.so -nosavepassword

EOF

cat > /etc/netatalk/AppleVolumes.default <<"EOF"
# volume format:
# :DEFAULT: [all of the default options except volume name]
# path [name] [casefold:x] [options:z,l,j] \
#   [allow:a,@b,c,d] [deny:a,@b,c,d] [dbpath:path] [password:p] \
#   [rwlist:a,@b,c,d] [rolist:a,@b,c,d] [limitsize:value in bytes] \
#   [preexec:cmd] [root_preexec:cmd] [postexec:cmd]  [root_postexec:cmd] \
#   [allowed_hosts:IPv4 address[/IPv4 netmask bits]] \
#   [denied_hosts:IPv4 address[/IPv4 netmask bits]] \
#   ... more, see below ...
#   
# name:      volume name. it can't include the ':' character
#
#
# variable substitutions:
# you can use variables for both <path> and <name> now. here are the
# rules:
#     1) if you specify an unknown variable, it will not get converted. 
#     2) if you specify a known variable, but that variable doesn't have
#        a value, it will get ignored.
#
# the variables:
# $b   -> basename of path
# $c   -> client's ip or appletalk address
# $d   -> volume pathname on server    
# $f   -> full name (whatever's in the gecos field)
# $g   -> group
# $h   -> hostname 
# $i   -> client ip without tcp port or appletalk network   
# $s   -> server name (can be the hostname)
# $u   -> username (if guest, it's whatever user guest is running as)
# $v   -> volume name (either ADEID_NAME or basename of path)
# $z   -> zone (may not exist)
# $$   -> $
#
#
# casefold options [syntax: casefold:option]:
# tolower    -> lowercases names in both directions
# toupper    -> uppercases names in both directions
# xlatelower -> client sees lowercase, server sees uppercase
# xlateupper -> client sees uppercase, server sees lowercase
#
# allow/deny/rwlist/rolist format [syntax: allow:user1,@group]:
# user1,@group,user2  -> allows/denies access from listed users/groups
#                        rwlist/rolist control whether or not the
#                        volume is ro for those users.
# allowed_hosts       -> Only listed hosts and networks are allowed,
#                        all others are rejected. Example:
#                        allowed_hosts:10.1.0.0/16,10.2.1.100
# denied_hosts        -> Listed hosts and nets are rejected,
#                        all others are allowed. Example:
#                        denied_hosts: 192.168.100/24,10.1.1.1
# preexec             -> command to be run when the volume is mounted,
#                        ignore for user defined volumes
# root_preexec        -> command to be run as root when the volume is mounted,
#                        ignore for user defined volumes
# postexec            -> command to be run when the volume is closed,
#                        ignore for user defined volumes
# root_postexec       -> command to be run as root when the volume is closed,
#                        ignore for user defined volumes
# veto                -> hide files and directories,where the path matches
#                        one of the "/" delimited vetoed names. Matches are
#                        partial, e.g. path is /abc/def/file and veto:/abc/
#                        will hide the file.
# adouble             -> specify the format of the metadata files.
#                        default is "v2". netatalk 1.x used "v1".
#                        "osx" cannot be treated normally any longer.
# volsizelimit        -> size in MiB.  Useful for TimeMachine: limits the
#                         reported volume size, thus preventing TM from using
#                         the whole real disk space for backup.
#                         Example: "volsizelimit:1000" would limit the
#                         reported disk space to 1 GB.
#
# codepage options [syntax: options:charsetname]
# volcharset          -> specifies the charset to be used
#                        as the volume codepage
#                        e.g. "UTF8", "UTF8-MAC", "ISO-8859-15"
# maccharset          -> specifies the charset to be used
#                        as the legacy client (<=Mac OS 9) codepage
#                        e.g. "MAC_ROMAN", "MAC_CYRILLIC"
#
# perm                -> default permission value
#                        OR with the client requested perm
#                        Use with options:upriv
# dperm               -> default permission value for directories
#                        OR with the client requested perm
#                        Use with options:upriv
# fperm               -> default permission value for files
#                        OR with the client requested perm
#                        Use with options:upriv
# umask               -> set perm mask
#                        Use with options:upriv
# dbpath:path         -> store the database stuff in the following path.
# cnidserver:server[:port]
#                     -> Query this servername or IP address
#                        (default:localhost) and port (default: 4700)
#                        for CNIDs. Only used with CNID backend "dbd".
#                        This option here overrides any setting from
#                        afpd.conf:cnidserver.
# password:password   -> set a volume password (8 characters max)
# cnidscheme:scheme   -> set the cnid scheme for the volume,
#                        default is [dbd]
#                        available schemes: [dbd last tdb]
# ea                  -> none|auto|sys|ad
#                        Specify how Extended Attributes are stores. default
#                        is auto.
#                        auto: try "sys" (by setting an EA on the shared
#                              directory itself), fallback to "ad".  Requires
#                              writable volume for performing the test.
#                              Note: options:ro overwrites "auto" with "none."
#                        sys:  Use filesystem EAs
#                        ad:   Use files in AppleDouble directories
#                        none: No EA support
#
#
# miscellaneous options [syntax: options:option1,option2]:
# tm                  -> enable TimeMachine support
# prodos              -> make compatible with appleII clients.
# crlf                -> enable crlf translation for TEXT files.
# noadouble           -> don't create .AppleDouble unless a resource
#                        fork needs to be created.
# ro                  -> mount the volume as read-only.
# mswindows           -> enforce filename restrictions imposed by MS
#                        Windows. this will also invoke a default
#                        codepage (iso8859-1) if one isn't already 
#                        specified.
# nohex               -> don't do :hex translations for anything
#                        except dot files. specify usedots as well if
#                        you want that turned off. note: this option
#                         makes the / character illegal.
# usedots             -> don't do :hex translation for dot files. note: when 
#                        this option gets set, certain file names
#                        become illegal. these are .Parent and
#                        anything that starts with .Apple.
# invisibledots       -> don't do :hex translation for dot files. note: when 
#                        this option gets set, certain file names
#                        become illegal. these are .Parent and
#                        anything that starts with .Apple. also, dot
#                        files created on the unix side are marked invisible. 
# limitsize           -> limit disk size reporting to 2GB. this is
#                        here for older macintoshes using newer
#                        appleshare clients. yucko.
# nofileid            -> don't advertise createfileid, resolveid, deleteid 
#                        calls
# root_preexec_close  -> a non-zero return code from root_preexec close the 
#                        volume being mounted.
# preexec_close       -> a non-zero return code from preexec close the 
#                        volume being mounted.
# nostat              -> don't stat volume path when enumerating volumes list
# upriv               -> use unix privilege.  
# illegalseq          -> encode illegal sequence in filename asis,
#                        ex "\217-", which is not a valid SHIFT-JIS char,
#                        is encoded  as U\217 -
# nocnidcache         -> Don't store and read CNID to/from AppleDouble file.
#                        This should not be used as it also prevents a CNID
#                        database rebuild with `dbd`!
# caseinsensitive     -> The underlying FS is case insensitive (only 
#                        test with JFS in OS2 mode)
# dropbox             -> Allows a volume to be declared as being a "dropbox."
#                        Note that netatalk must be compiled with dropkludge
#                        support for this to function. Warning: This option
#                        is deprecated and might not work as expected.
# dropkludge          -> same as "dropbox"
# nodev               -> always use 0 for device number, helps when the
#                        device number is not constant across a reboot,
#                        cluster, ...
#

# The line below sets some DEFAULT, starting with Netatalk 2.1.
:DEFAULT: options:upriv,usedots

# By default all users have access to their home directories.
#~/			"Home Directory"

# End of File
/mnt/TimeCapsule TimeCapsule options:tm,usedots,upriv

EOF

cat > /etc/avahi/services/afpd.service <<"EOF"
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
    <name replace-wildcards="yes">%h</name>
    <service>
        <type>_afpovertcp._tcp</type>
        <port>548</port>
    </service>
    <service>
        <type>_device-info._tcp</type>
        <port>0</port>
        <txt-record>model=TimeCapsule</txt-record>
    </service>
</service-group>

EOF
service netatalk restart
service avahi-daemon restart
}
#############################################################################

install_HFS (){
#############################################################################
#Install HFS+
apt-get install hfsplus hfsutils hfsprogs
}
#############################################################################

install_MountExistingHdd (){
#############################################################################
#Mount existing Harddrive
#TimeCapsule Freigabe
sudo mkdir /mnt/TimeCapsule
sudo mount /dev/sda1 /mnt/TimeCapsule
cat > /etc/fstab <<"EOF"
# UNCONFIGURED FSTAB FOR BASE SYSTEM
/dev/mmcblk0p1  /           ext4    defaults,noatime,nodiratime,data=writeback,commit=600,errors=remount-ro        0       0
UUID=986f807d-c199-4e02-9d44-f640dd0545b5 /mnt/TimeCapsule ext4 defaults 0 0

EOF
}
#############################################################################

install_Seafile (){
#############################################################################
#Install Seafile
apt-get install python2.7 python-setuptools python-simplejson python-imaging sqlite3
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
install_hfs
install_Netatalk
#install_Seafile
#install_samba
#install_rpimonitor
#install_temper
install_Virus
install_scaner_and_scanbuttons
install_ocr
install_cups
#apt-get -y install socat
install_AudioOutonToslink
install_ShairportSync
install_HMLAND
install_FHEM
#reboot
