require 'spec_helper'
describe 'appdynamics' do
  context 'with default values for all parameters' do
    it { should compile.with_all_deps }
    it { should contain_class('appdynamics') }

    it do
      should contain_package('libaio').with({
        :ensure => 'installed',
        :before => 'Exec[install_controller]',
      })
    end

    it do
      should contain_package('gcc').with({
        :ensure => 'installed',
        :before => 'Exec[install_controller]',
      })
    end

    limits_entries = {
      'appd_hard_nofile' => 'appd hard nofile 65535',
      'appd_soft_nofile' => 'appd soft nofile 65535',
      'appd_hard_nproc'  => 'appd hard nproc 8192',
      'appd_soft_nproc'  => 'appd soft nproc 8192',
    }

    limits_entries.each do |k, v|
      it do
        should contain_file_line(k).with({
          :path => '/etc/security/limits.conf',
          :line => v,
          :before => 'Exec[install_controller]',
        })
      end
    end

    profile_entries = {
      'appd_ulimit_1' => 'ulimit -n 65535',
      'appd_ulimit_2' => 'ulimit -u 8192',
    }

    profile_entries.each do |k, v|
      it do
        should contain_file_line(k).with({
          :path => '/etc/profile',
          :line => v,
          :before => 'Exec[install_controller]',
        })
      end
    end

    it do
      should contain_file_line('appd_pam_system-auth').with({
        :path   => '/etc/pam.d/system-auth',
        :line   => 'session required pam_limits.so',
        :before => 'Exec[install_controller]',
      })
    end

    response_fixture = File.read(fixtures('response.varfile'))
    it { should contain_file('appdynamics_installer_response').with_content(response_fixture) }

    it do
      should contain_file('appdynamics_installer_response').with({
        :ensure  => 'file',
        :path    => '/tmp/response.varfile',
        :owner   => 'root',
        :group   => 'root',
        :mode    => '0644',
        :before  => 'Exec[install_controller]',
      })
    end

    it do
      should contain_exec('install_controller').with({
        :command   => 'sh /tmp/controller.sh -q -varfile /tmp/response.varfile',
        :creates   => '/home/appduser/AppDynamics/Controller',
        :logoutput => true,
        :timeout   => 900,
        :path      => '/bin:/usr/bin:/sbin:/usr/sbin',
      })
    end

    it do
      should contain_exec('install_appd_license').with({
        :command => 'mv /tmp/license.lic /home/appduser/AppDynamics/Controller/license.lic',
        :creates => '/home/appduser/AppDynamics/Controller/license.lic',
        :path    => '/bin:/usr/bin:/sbin:/usr/sbin',
        :require => 'Exec[install_controller]',
      })
    end

    it do
      should contain_file('appdynamics_license').with({
        :ensure  => 'file',
        :path    => '/home/appduser/AppDynamics/Controller/license.lic',
        :owner   => 'root',
        :group   => 'root',
        :mode    => '0644',
        :require => 'Exec[install_appd_license]',
      })
    end

    it do
      should contain_exec('install_ha_toolkit').with({
        :command => 'tar -xzvf /tmp/HA-toolkit.tar.gz -C /tmp && mv /tmp/HA-toolkit /home/appduser/AppDynamics/Controller/AppDynamicsHA',
        :creates => '/home/appduser/AppDynamics/Controller/AppDynamicsHA',
        :path    => '/bin:/usr/bin:/sbin:/usr/sbin',
        :require => 'Exec[install_controller]',
      })
    end

    it do
      should contain_exec('install_init_script').with({
        :command => 'bash /home/appduser/AppDynamics/Controller/AppDynamicsHA/install-init.sh',
        :creates => '/etc/init.d/appdcontroller',
        :path    => '/bin:/usr/bin:/sbin:/usr/sbin',
        :require => 'Exec[install_ha_toolkit]',
        :notify  => 'Service[appdcontroller]',
      })
    end

    it do
      should contain_service('appdcontroller').with({
        :ensure     => 'running',
        :enable     => true,
        :hasrestart => true,
        :hasstatus  => true,
      })
    end
  end
end
