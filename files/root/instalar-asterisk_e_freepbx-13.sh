#!/bin/bash
sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/sysconfig/selinux
sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config
[[ $(/sbin/sestatus | egrep -i "^selinux status:.*disabled") ]] && echo "SELINUX já está desabilitado - tudo certo"
[[ ! $(/sbin/sestatus | egrep -i "^selinux status:.*disabled") ]] && echo "SELINUX foi desabilitado - É necessario reiniciar para aplicar alteração. Pressione CTRL+C para cancelar reinicio em 5s"
sleep 5
[[ ! $(/sbin/sestatus | egrep -i "^selinux status:.*disabled") ]] && reboot

yum -y update
yum -y groupinstall core base "Development Tools"

yum -y install lynx mariadb-server mariadb php php-mysql php-mbstring tftp-server \
  httpd ncurses-devel sendmail sendmail-cf sox newt-devel libxml2-devel libtiff-devel \
  audiofile-devel gtk2-devel subversion kernel-devel git php-process crontabs cronie \
  cronie-anacron wget vim php-xml uuid-devel sqlite-devel net-tools gnutls-devel php-pear unixODBC mysql-connector-odbc \
  iksemel-devel iksemel

pear install Console_Getopt
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --reload
systemctl enable mariadb.service
systemctl start mariadb
mysql_secure_installation < /root/config-mariadb.conf
systemctl enable httpd.service
systemctl start httpd.service
adduser asterisk -m -c "Asterisk User"
cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/libpri/libpri-current.tar.gz
#wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-13-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/certified-asterisk/asterisk-certified-13.13-current.tar.gz
wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.7.tar.gz
wget http://www.pjsip.org/release/2.4/pjproject-2.4.tar.bz2

cd /usr/src
tar xvfz dahdi-linux-complete-current.tar.gz
tar xvfz libpri-current.tar.gz
rm -f dahdi-linux-complete-current.tar.gz libpri-current.tar.gz
cd dahdi-linux-complete-*
make all
make install
make config
cd /usr/src/libpri-*
make
make install

cd /usr/src
tar -xjvf pjproject-2.4.tar.bz2
rm -f pjproject-2.4.tar.bz2
cd pjproject-2.4
CFLAGS='-DPJ_HAS_IPV6=1' ./configure --prefix=/usr --enable-shared --disable-sound\
  --disable-resample --disable-video --disable-opencore-amr --libdir=/usr/lib64
make dep
make
make install

cd /usr/src
tar vxfz jansson.tar.gz
rm -f jansson.tar.gz
cd jansson-*
autoreconf -i
./configure --libdir=/usr/lib64
make
make install

cd /usr/src
tar xvfz asterisk-*.tar.gz
rm -f asterisk-*.tar.gz
cd asterisk-*
echo `pwd`| rev | cut -d"/" -f 1 | rev| sed "s/asterisk[a-zA-Z_-]*//g" > .version
contrib/scripts/install_prereq install
./configure --libdir=/usr/lib64
contrib/scripts/get_mp3_source.sh
make menuselect.makeopts
menuselect/menuselect --enable format_mp3 menuselect.makeopts
make
make install
make config
make install-logrotate
ldconfig
chkconfig asterisk off

wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-g722-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-g722-current.tar.gz
tar xfz asterisk-extra-sounds-en-g722-current.tar.gz
rm -f asterisk-extra-sounds-en-g722-current.tar.gz
tar xfz asterisk-core-sounds-en-g722-current.tar.gz
rm -f asterisk-core-sounds-en-g722-current.tar.gz

chown asterisk. /var/run/asterisk
chown -R asterisk. /etc/asterisk
chown -R asterisk. /var/{lib,log,spool}/asterisk
chown -R asterisk. /usr/lib64/asterisk
chown -R asterisk. /var/www/

sed -i 's/\(^upload_max_filesize = \).*/\120M/' /etc/php.ini
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/httpd/conf/httpd.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/httpd/conf/httpd.conf
systemctl restart httpd.service

cd /usr/src
wget http://mirror.freepbx.org/modules/packages/freepbx/freepbx-13.0-latest.tgz
tar xfz freepbx-13.0-latest.tgz
rm -f freepbx-13.0-latest.tgz
cd freepbx
./start_asterisk start
./install -n
