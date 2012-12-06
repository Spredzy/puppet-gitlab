# Class: gitlab
#
# This class install gitolite and a gitolite-admin account
#
#
class gitlab () {

  Class['ruby'] -> Class['gitolite'] -> Class['mysql::server'] -> Class['gitlab']

  include gitlab::params, gitolite,  apache, apache::mod::proxy

  class {'ruby' :
    provider => 'source',
    version  => '1.9.3-p194',
  }

  class {'mysql::server' :
    config_hash           => {
      'root_password'     => 'changeit',
      'bind_address'      => false,
    }
  }

  if $::osfamily == 'Debian' {
    exec {'a2enmod proxy_balancer proxy_http rewrite && service apache2 restart' :
      user    => 'root',
      cwd     => '/etc/apache2/mods-available/',
      path    =>  ['/usr/local/bin','/bin','/usr/bin','/usr/local/sbin','/usr/sbin','/sbin'],
      require => Class['apache::mod::proxy']
    }
  }

  package {[$gitlab::params::packages] :
    ensure => latest,
    notify => Service[$gitlab::params::redis],
  }

  service {$gitlab::params::redis :
    ensure     => running,
    hasrestart => true,
    hasstatus  => true,
    enable     => true,
  }

  file {'/etc/ssh/ssh_known_hosts' :
    ensure => present,
    group   => 'root',
    owner  => 'root',
    mode   => '0644',
  }

  create_resources('package', $gitlab::params::gem_packages, {provider => gem, source => 'http://rubygems.org/',})
}
