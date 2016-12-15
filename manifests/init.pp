# == Class: appdynamics
#
class appdynamics (
  $controller_install_path      = '/tmp/controller.sh',
  $ha_toolkit_path              = '/tmp/HA-toolkit.tar.gz',
  $controller_config            = 'demo',
  $iio_port                     = '3700',
  $server_port                  = '8090',
  $server_hostname              = $::fqdn,
  $ha_controller_type           = 'notapplicable',
  $controller_tenancy_mode      = 'single',
  $admin_port                   = '4848',
  $language                     = 'en',
  $jms_port                     = '7676',
  $install_dir                  = '/home/appduser/AppDynamics/Controller',
  $mysql_root_password          = 'DRvYYv9eq6',
  $database_port                = '3388',
  $username                     = 'admin',
  $password                     = 'pa55word',
  $ssl_port                     = '8181',
  $real_datadir                 = '/home/appduser/AppDynamics/Controller/db/data',
  $elasticsearch_datadir        = '/home/appduser/AppDynamics/Controller/events_service/analytics-processor',
  $root_user_password           = 'pa55word2',
  $reporting_service_http_port  = '8020',
  $reporting_service_https_port = '8021',
  $elasticsearch_port           = '9200',
  $manage_libaio                = true,
  $manage_gcc                   = true,
  $manage_unzip                 = true,
  $install_timeout              = 900,
  $exec_path                    = '/bin:/usr/bin:/sbin:/usr/sbin',
) {

  validate_absolute_path($controller_install_path)
  validate_absolute_path($ha_toolkit_path)
  validate_re($controller_config, '^demo$|^small$|^medium$|^large$|^extra-large$', 'The controller config must be set to demo, small, medium, large, or extra-large')
  validate_string($iio_port)
  validate_string($server_port)
  validate_string($server_hostname)
  validate_re($ha_controller_type, '^notapplicable$|^primary$|^secondary$', 'The HA Controller type must be "notapplicable", "primary", or "secondary"')
  validate_re($controller_tenancy_mode, '^single$|^multi$', 'The controller tenancy mode must be set to single or multi')
  validate_string($admin_port)
  validate_string($language)
  validate_string($jms_port)
  validate_string($install_dir)
  validate_string($mysql_root_password)
  validate_string($database_port)
  validate_string($username)
  validate_string($password)
  validate_string($ssl_port)
  validate_string($real_datadir)
  validate_string($elasticsearch_datadir)
  validate_string($root_user_password)
  validate_string($reporting_service_http_port)
  validate_string($reporting_service_https_port)
  validate_string($elasticsearch_port)
  validate_bool($manage_libaio)
  validate_bool($manage_gcc)
  validate_bool($manage_unzip)
  validate_integer($install_timeout)
  validate_string($exec_path)

  if $manage_libaio == true {
    package { 'libaio':
      ensure => installed,
      before => Exec['install_controller'],
    }
  }

  if $manage_gcc == true {
    package { 'gcc':
      ensure => installed,
      before => Exec['install_controller'],
    }
  }

  if $manage_unzip == true {
    package { 'unzip':
      ensure => installed,
      before => Exec['install_ha_toolkit'],
    }
  }

  File_line {
    before => Exec['install_controller'],
  }

  file_line { 'appd hard nofile':
    path => '/etc/security/limits.conf',
    line => 'appd hard nofile 65535',
  }

  file_line { 'appd soft nofile':
    path => '/etc/security/limits.conf',
    line => 'appd soft nofile 65535',
  }

  file_line { 'appd hard nproc':
    path => '/etc/security/limits.conf',
    line => 'appd hard nproc 8192',
  }

  file_line { 'appd soft nproc':
    path => '/etc/security/limits.conf',
    line => 'appd soft nproc 8192',
  }

  file_line { 'ulimit config 1':
    path => '/etc/profile',
    line => 'ulimit -n 65535',
  }

  file_line { 'ulimit config 2':
    path => '/etc/profile',
    line => 'ulimit -u 8192',
  }

  file_line { 'pam configuration':
    path => '/etc/pam.d/system-auth',
    line => 'session required pam_limits.so',
  }

  file { 'appdynamics_response':
    ensure  => 'file',
    path    => '/opt/response.varfile',
    content => template('appdynamics/response.varfile.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    before  => Exec['install_controller'],
  }

  exec { 'install_controller':
    command   => "sh ${controller_install_path} -q -varfile /opt/response.varfile",
    creates   => '/home/appduser/AppDynamics/Controller',
    logoutput => true,
    timeout   => $install_timeout,
    path      => $exec_path,
  }

  file { 'appdynamics_license':
    ensure  => 'file',
    path    => "${install_dir}/license.lic",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    #source  => 'puppet:///modules/appdynamics/license.lic',
    require => Exec['install_controller'],
  }

  exec { 'install_ha_toolkit':
    command => "tar -xzvf ${ha_toolkit_path} -C /tmp && mv /tmp/HA-toolkit ${install_dir}/AppDynamicsHA",
    creates => "${install_dir}/AppDynamicsHA",
    path    => $exec_path,
    require => Exec['install_controller'],
  }

  exec { 'install_init_script':
    command => "bash ${install_dir}/AppDynamicsHA/install-init.sh",
    creates => '/etc/init.d/appdcontroller',
    path    => $exec_path,
    require => Exec['install_ha_toolkit'],
    notify  => Service['appdcontroller'],
  }

  service { 'appdcontroller':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
  }
}