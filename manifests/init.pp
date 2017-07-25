# == Class: voip-servidor
#
# Instalação do serviço de teleconia IP voip versão 2.0
#
# Sistema operacioanl: CentOS 7
# Motor: asterisk 13
# Gerência: FreePBX
#
# === Parameters
#
# Document parameters here.
#
# [*sample_parameter*]
#   Explanation of what this parameter affects and what it defaults to.
#   e.g. "Specify one or more upstream ntp servers as an array."
#
# === Variables
#
# PACOTES PARA INSTALACAO DO PJSIP E JANSSON A PARTIR DE PACOTES
# Senha de root do banco Mysql/MariaDB
$senhaDeRootdoBancoDeDados = $senha_randomica
# Variável que armazena o nome deste módulo
$moduloNome = 'voip-servidor'
#  Esta variável se refere ao fqdn (Fully Qualified Domain Name)
# e é utilizada na criação do certificado SSL do apache.
# Caso não seja setada assume o IP da primeira interface de rede
$fullyq = $ipaddress

$pacotes = ['audiofile-devel','cronie','cronie-anacron','crontabs','dhcp','epel-release','fail2ban','ffmpeg','git','gnutls-devel','gtk2-devel','httpd','iptables','jack-audio-connection-kit-devel','jansson','jansson-devel','lame','kernel-devel','libsrtp','libsrtp-devel','libtiff-devel','libuuid','libuuid-devel.x86_64','libxml2-devel','lsyncd','lynx','mariadb','mariadb-server','mod_ssl','mysql','mlocate','mpg123','mysql-connector-odbc','nc','ncurses-devel','net-tools','newt-devel','ngrep','nmap','ntp','php','php-mbstring','phpmyadmin','php-mysql','php-pear','php-process','php-xml','portaudio','portaudio-devel','sendmail','sendmail-cf','sipp','sox','spandsp','spandsp-devel','sqlite-devel','subversion','telnet','tftp-server','unixODBC','uuid-devel','vim','vsftpd','wget']
class voip-servidor {
  Exec {
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
  }
  if "$selinux" == "true" {
    exec { 'selinux-disable':
      unless  => '/bin/egrep "^SELINUX *= *disabled$" /etc/selinux/config > /dev/null 2>&1',
      command => '/bin/sed -i s/SELINUX=.*/SELINUX=disabled/g /etc/selinux/config;reboot',
    }
  }
  exec { 'RepoNuxInstalar':
    command => '/bin/rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro; /bin/rpm -Uvh http://li.nux.ro/download/nux/dextop/el7/x86_64/nux-dextop-release-0-5.el7.nux.noarch.rpm',
    unless => '/usr/bin/rpm -qa | /usr/bin/egrep -q  nux-dextop-release',
  }
  file { '/etc/sudoers.d/asterisk':
    ensure => directory,
    mode => '0440',
    source  =>  "puppet:///modules/${moduloNome}/etc/sudoers.d/asterisk",
    owner =>  'root',
    group => 'root',
  }
  file { '/etc/localtime':
    ensure => link,
    target  =>  '/usr/share/zoneinfo/America/Sao_Paulo',
  }
}
# == Class: pacotes
class pacotes {
  # resources
  package { $pacotes:
    ensure => installed,
    allow_virtual => true,
  }
}
# == Class: servicos
# Configurar execução dos daemons do serviço
class servicos {
  $servicos = ['httpd','mariadb','ntpd']
  service { $servicos:
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus  => true,
  }
}
# == Class: mariadb
# Configurar banco de dados mariadb
class mariadb {
  # resources
  $configMariaDB = "/root/config-mariadb.conf"
  file { $configMariaDB:
    ensure    => present,
    replace   => true,
    content   => template("${moduloNome}${configMariaDB}.erb"),
    mode      => '0644',
    owner     => 'root',
    group     => 'root',
    notify => Exec['mariadb-config'],
  }
  exec { 'mariadb-config':
    command   => "/usr/bin/mysql_secure_installation < ${configMariaDB}",
    onlyif    =>  '/usr/bin/mysqlshow',
    refreshonly => 'true',
  }
}
class asterisk {
  exec { 'usuario-asterisk':
    command => 'adduser asterisk -m -c "Usuario Asterisk"',
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    unless => 'cat /etc/passwd | egrep "^asterisk\:"'
  }
  file { '/root/instala_asterisk13.sh':
    ensure => file,
    source => "puppet:///modules/${moduloNome}/root/instala_asterisk13.sh",
    mode => '0644',
    require => Exec['usuario-asterisk'],
  }
  exec { 'instalar_asterisk':
    command => 'sh /root/instala_asterisk13.sh; echo 0',
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    unless => 'ls -l /sbin/asterisk',
    require => File['/root/instala_asterisk13.sh'],
    timeout => '0',
    # refreshonly => true,
  }
  exec { 'recarrega-asterisk':
    command => "asterisk -rx 'reload'",
    path        => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    onlyif => 'test -f /var/run/asterisk/asterisk.pid',
    refreshonly => true,
    require     => Exec['instalar_asterisk'],
  }
  file { '/etc/asterisk':
    ensure  => directory,
    recurse => true,
    replace => true,
    owner => 'asterisk',
    group => 'asterisk',
    source  => "puppet:///modules/${moduloNome}/etc/asterisk",
    notify  =>  Exec['recarrega-asterisk'],
  }
  $pastasAsterisk = ['/var/run/asterisk','/var/lib/asterisk','/var/log/asterisk','/var/spool/asterisk','/usr/lib64/asterisk','/var/www/']
  file { $pastasAsterisk:
    ensure => directory,
    owner => 'asterisk',
    group => 'asterisk',
    require     => Exec['instalar_asterisk'],
  }
}
class freePBX {
  # resources
  $freePBXmodulos = 'timeconditions customcontexts endpointman certman manager webrtc iaxsettings phonebook speeddial fax dundicheck certman restapi announcement callforward callwaiting callback donotdisturb findmefollow ivr miscapps miscdests parking queues queueprio ringgroups setcid ttsengines tts hotelwakeup printextensions campon pinsets blacklist backup presencestate paging'
  $scriptDeInstalacaoFreePBX = '/root/instalar_freepbx-13.sh'
  file { $scriptDeInstalacaoFreePBX:
    ensure => file,
    mode => '0755',
    source => "puppet:///modules/${moduloNome}${scriptDeInstalacaoFreePBX}",
    owner => 'root',
    group => 'root',
  }
  exec { $scriptDeInstalacaoFreePBX:
    command => "sh $scriptDeInstalacaoFreePBX",
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    unless => "ls /sbin/fwconsole",
    timeout => '0',
    require => File[$scriptDeInstalacaoFreePBX],
  }
  file { '/etc/systemd/system/freepbx.service':
    ensure => file,
    source => "puppet:///modules/${moduloNome}/etc/systemd/system/freepbx.service",
    mode => '0644',
    owner => 'root',
    group => 'root',
    require => File[$scriptDeInstalacaoFreePBX],
    notify => Exec['FreePBXRepoConfig']
  }
  service { 'freepbx':
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus  => true,
    require => Exec[$scriptDeInstalacaoFreePBX],
  }
  # TODO: INSTALAR MÓDULOS PELO CONSOLE DO FREEPBX
  exec { 'FreePBXRepoConfig' :
    command => "/usr/sbin/fwconsole ma enablerepo standard extended unsupported",
    refreshonly => true,
    timeout => '120',
    notify => Exec['FreePBXModulosInstalar'],
  }
  exec { 'FreePBXModulosInstalar':
    command => "/usr/sbin/fwconsole ma downloadinstall $freePBXmodulos",
    timeout => '240',
    refreshonly => true,
  }
}

# == Class: provisionamento
# Esta classe é responsavel por instalar o agente zabbix
class provisionamento {
  # TODO: IMPEDIR LISTAGEM DA PASTA DE PROVISIONAMENTO
  $ProvisionamentoSenha = '$6$mdcidpn3$wuanTEWzWjBvXxXD4O4V5Z5bwBTka7zcNzhMjHa3rDbSgbmiSVA0LgUR8X3AcYlHlbqiVgCCGF6Z.ZRC.9UDb/'
  $ProvisionamentoUsuario = "autoprovisionamento"
  user { $ProvisionamentoUsuario:
    comment => 'Usuario de autoprovisionamento',
    home => '/tftpboot',
    ensure => present,
    password => "$ProvisionamentoSenha",
  }
  if $usuario_asterisk_existe {
    file { '/tftpboot':
      ensure => directory,
      recurse => 'true',
      mode => '0644',
      owner => "asterisk",
      group => "asterisk",
      source => "puppet:///modules/${moduloNome}/tftpboot",
    }
  }
  service { 'vsftpd':
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus  => true,
    subscribe => File['/etc/vsftpd/vsftpd.conf']
  }
  file { '/etc/vsftpd/vsftpd.conf':
    ensure => file,
    replace => yes,
    mode => '0600',
    owner => 'root',
    group => 'root',
    source => "puppet:///modules/${moduloNome}/etc/vsftpd/vsftpd.conf",
  }
}
class certificadoSSL (
  $certdir          = '/etc/ssl/certs',
  $keydir           = '/etc/ssl/private',
  $wwwroot          = '/var/www/html/',
  $fullyq           = $ipaddress
  ) {
  file { $keydir:
    ensure => directory,
    mode => '0700',
  }
  exec { 'HTTPPastasCriar':
    command => '/bin/mkdir -p /etc/httpd/conf.d',
    unless => '/bin/test -d /etc/httpd/conf.d',
  }
  exec {'criar_self_signed_sslcert':
    command => "openssl req -newkey rsa:2048 -nodes -keyout ${keydir}/${$fullyq}.key  -x509 -days 3600 -out ${certdir}/${$fullyq}.crt -subj '/CN=${$fullyq}'",
    cwd     => $keydir,
    creates => [ "${keydir}/${$fullyq}.key", "${certdir}/${$fullyq}.crt", ],
    path    => ["/usr/bin", "/usr/sbin"],
    require   => File[$keydir],
    notify  => Exec['Diffie-Hellman'],
  }
  exec { 'Diffie-Hellman':
    command   => "openssl dhparam -out ${certdir}/dhparam.pem 2048",
    creates   => "${certdir}/dhparam.pem",
    path      => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    notify    => Exec['append-diffie-hellman'],
    refreshonly => true,
  }
  exec { 'append-diffie-hellman':
    command => "cat ${certdir}/dhparam.pem | sudo tee -a ${certdir}/${$fullyq}.crt",
    path => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
    refreshonly => true,
  }
  file { '/etc/httpd/conf.d/non-ssl.conf':
    ensure => file,
    content   => template("${moduloNome}/etc/httpd/conf.d/non-ssl.conf.erb"),
    mode => '0644',
    require   => [File[$keydir],Exec['HTTPPastasCriar']],
    notify => Service['httpd'],
  }
  file { '/etc/httpd/conf.d/ssl.conf':
    ensure => file,
    content   => template("${moduloNome}/etc/httpd/conf.d/ssl.conf.erb"),
    mode => '0644',
    require   => [File[$keydir],Exec['HTTPPastasCriar']],
    notify => Service['httpd'],
  }
}

class configMariaDBRoot {
  # resources
  if $db_senha_root_setada {
  } else {
    $configMariaDBRoot = "/root/config-rootpw-mariadb.conf"
    file { $configMariaDBRoot:
      ensure    => present,
      replace   => true,
      content   => template("${moduloNome}${configMariaDBRoot}.erb"),
      mode      => '0600',
      owner     => 'root',
      group     => 'root',
    }
    file { '/root/.my.cnf':
      ensure    => present,
      replace   => true,
      content   => template("${moduloNome}/root/.my.cnf.erb"),
      mode      => '0600',
      owner     => 'root',
      group     => 'root',
      notify  => Exec['mariadb-config-rootpw']
    }
    exec { 'mariadb-config-rootpw':
      command   => "/usr/bin/mysql_secure_installation < ${configMariaDBRoot}; /bin/rm -f ${configMariaDBRoot}",
      refreshonly => 'true',
      require => [ File['/root/.my.cnf'], File[$configMariaDBRoot] ]
    }
  }
}
# TODO: Configurar firewall

if "$selinux" == "true" {
  notify{"Desabilite o SELINUX antes de começar a instalação.\n  Desabilite com o comando: \n\n/bin/sed -i s/SELINUX=.*/SELINUX=disabled/g /etc/selinux/config\n":}
} else {
  include voip-servidor
  include pacotes
  include mariadb
  include servicos
  include asterisk
  include freePBX
  include configMariaDBRoot
  include provisionamento
  class {'certificadoSSL':
    certdir          => '/etc/ssl/certs',
    keydir           => '/etc/ssl/private',
    wwwroot          => '/var/www/html/',
    fullyq  => $fullyq,
  }
  Class['voip-servidor'] -> Class['pacotes'] -> Class['provisionamento']-> Class['certificadoSSL'] -> Class['servicos'] ->  Class['mariadb']  -> Class['asterisk'] -> Class['freePBX'] -> Class['configMariaDBRoot']
}
