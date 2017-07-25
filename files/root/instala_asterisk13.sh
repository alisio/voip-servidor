#!/bin/bash
# Autor: Antonio alisio de Meneses Cordeiro
# Descricao: este script instala a aplicacao asterisk e iptables, assim como dependencias.
# instalacao do asterisk 11 para CentOS   7
# Necessario acesso a internet
versao=20170724
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/.local/bin:/root/bin"


sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/sysconfig/selinux
sed -i 's/\(^SELINUX=\).*/\SELINUX=disabled/' /etc/selinux/config

yum -y update
yum -y groupinstall core base "Development Tools"
yum -y install lynx mariadb-server mariadb php php-mysql php-mbstring tftp-server \
  httpd ncurses-devel sendmail sendmail-cf sox newt-devel libxml2-devel libtiff-devel \
  audiofile-devel gtk2-devel subversion kernel-devel git php-process crontabs cronie \
  cronie-anacron wget vim php-xml uuid-devel sqlite-devel net-tools gnutls-devel php-pear unixODBC mysql-connector-odbc
#
# pear install Console_Getopt
#
# firewall-cmd --zone=public --add-port=80/tcp --permanent
# firewall-cmd --reload
#
# systemctl enable mariadb.service
# systemctl start mariadb
#
# mysql_secure_installation
#
# systemctl enable httpd.service
# systemctl start httpd.service
#adduser asterisk -m -c "Asterisk User"

cd /usr/src/

sudo /usr/bin/wget http://downloads.asterisk.org/pub/telephony/libpri/libpri-1.6.0.tar.gz
sudo /usr/bin/wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-2.11.1+2.11.1.tar.gz
sudo /usr/bin/wget http://downloads.asterisk.org/pub/telephony/certified-asterisk/asterisk-certified-13.13-cert4.tar.gz
#sudo /usr/bin/wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-13-current.tar.gz

sudo /usr/bin/tar -xvf asterisk*
sudo /usr/bin/tar -xvf dahdi*
sudo /usr/bin/tar -xvf libpri*

rm -f /usr/src/dahdi-*.tar.gz
cd /usr/src/dahdi-*
make all
make install
make config

rm -f /usr/src/libpri-*.tar.gz
cd /usr/src/libpri*
make
make install

# sudo /usr/bin/wget http://www.pjsip.org/release/2.4/pjproject-2.4.tar.bz2
# sudo /usr/bin/tar -xvf pjproject-*
# cd /usr/src/pjproject-*
# CFLAGS='-DPJ_HAS_IPV6=1' ./configure --prefix=/usr --enable-shared --disable-sound --disable-resample --disable-video --disable-opencore-amr --libdir=/usr/lib64
# make dep
# make
# make install

#sudo /usr/bin/wget -O jansson.tar.gz https://github.com/akheron/jansson/archive/v2.7.tar.gz
#sudo /usr/bin/tar -xvf jansson*
# cd /usr/src/jansson-*
# autoreconf -i
# ./configure --libdir=/usr/lib64
# make
# make install

adduser asterisk -m -c "Asterisk User"
rm -f /usr/src/asterisk-*.tar.gz
cd /usr/src/asterisk*
echo `pwd`| rev | cut -d"/" -f 1 | rev| sed "s/asterisk[a-zA-Z_-]*//g" > .version
contrib/scripts/install_prereq install
./configure --libdir=/usr/lib64
contrib/scripts/get_mp3_source.sh
#make clean && make distclean
make menuselect.makeopts
ITF=" "
opcoesEnable="chan_console chan_dahdi format_mp3 chan_oss chan_sip res_fax app_fax res_srtp cdr_csv chan_ooh323 res_config_mysql app_mysql cdr_mysql app_amd app_chanisavail app_fax app_minivm app_waitforsilence cdr_sqlite3_custom chan_sip chan_pjsip chan_iax2 res_corosync res_fax_spandsp aelparse conf2ael agi-test.agi CORE-SOUNDS-EN-GSM MOH-OPSOUND-WAV"
for opcao in $opcoesEnable; do
  menuselect/menuselect --enable $opcao menuselect.makeopts
done
# opcoesDisable="chan_pjsip func_pjsip_aor func_pjsip_contact func_pjsip_endpoint res_pjproject res_pjsip res_pjsip_acl res_pjsip_authenticator_digest res_pjsip_caller_id res_pjsip_config_wizard res_pjsip_dialog_info_body_generator res_pjsip_diversion res_pjsip_dlg_options res_pjsip_dtmf_info res_pjsip_empty_info res_pjsip_endpoint_identifier_anonymous res_pjsip_endpoint_identifier_ip res_pjsip_endpoint_identifier_user res_pjsip_exten_state res_pjsip_header_funcs res_pjsip_logger res_pjsip_messaging res_pjsip_mwi res_pjsip_mwi_body_generator res_pjsip_nat res_pjsip_notify res_pjsip_one_touch_record_info res_pjsip_outbound_authenticator_digest res_pjsip_outbound_publish res_pjsip_outbound_registration res_pjsip_path res_pjsip_pidf_body_generator res_pjsip_pidf_digium_body_supplement res_pjsip_pidf_eyebeam_body_supplement res_pjsip_publish_asterisk res_pjsip_pubsub res_pjsip_refer res_pjsip_registrar res_pjsip_registrar_expire res_pjsip_rfc3326 res_pjsip_sdp_rtp res_pjsip_send_to_voicemail res_pjsip_session res_pjsip_sips_contact res_pjsip_t38 res_pjsip_transport_management res_pjsip_transport_websocket res_pjsip_xpidf_body_generator"
# for opcao in $opcoesDisable; do
#   menuselect/menuselect --disable $opcoesDisable menuselect.makeopts
# done
make && make install
#make samples
make config
ldconfig
chkconfig asterisk off
make install-logrotate
systemctl daemon-reload
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-core-sounds-en-g722-current.tar.gz
wget http://downloads.asterisk.org/pub/telephony/sounds/asterisk-extra-sounds-en-g722-current.tar.gz
tar xfz asterisk-extra-sounds-en-g722-current.tar.gz
rm -f asterisk-extra-sounds-en-g722-current.tar.gz
tar xfz asterisk-core-sounds-en-g722-current.tar.gz
rm -f asterisk-core-sounds-en-g722-current.tar.gz
chown -R asterisk.asterisk /etc/asterisk
chown asterisk.asterisk /var/run/asterisk
chown -R asterisk.asterisk /var/{lib,log,spool}/asterisk
chown -R asterisk.asterisk /usr/lib64/asterisk
