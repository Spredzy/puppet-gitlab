# Class: gitlab
#
# This class install gitolite and a gitolite-admin account
#
#
class gitlab (
  $gitlab_user = $gitlab::params::gitlab_user,
  $home_gitlab_user = $gitlab::params::home_gitlab_user) inherits gitlab::params {

  Class['ruby'] -> Class['gitolite'] -> Class['mysql::server'] -> Class['gitlab']

  $gitolite_user = $gitlab::params::gitolite_user
  $home_gitolite_user = $gitlab::params::home_gitolite_user

  class {'ruby' :
    provider => 'source',
    version  => '1.9.3-p194',
  }

  class {'gitolite' :
    gitolite_admin_user      => $gitlab_user,
    home_gitolite_admin_user => $home_gitlab_user,
  }

  class {'mysql::server' :
    config_hash           => {
      'root_password'     => 'changeit',
      'bind_address'      => false,
    }
  }

  exec {"mysql -uroot -e 'CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci'" :
    cwd     => '/',
    path    => '/usr/bin',
    require =>  Class['mysql::server'],
  }

  exec {"mysql -uroot -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON gitlabhq_production.* TO gitlab@\"${ipaddress}\" identified by \"changeit\"'" :
    cwd     => '/',
    path    => '/usr/bin',
    require =>  Exec["mysql -uroot -e 'CREATE DATABASE IF NOT EXISTS gitlabhq_production DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci'"],
    before  =>  Exec["git clone -b stable ${gitlab_github_url} gitlab"],
  }

  package {[$gitlab::params::packages] :
    ensure => latest,
    before =>  Exec["git clone -b stable ${gitlab_github_url} gitlab"],
    notify => Service['redis'],
  }

  service {'redis' :
    ensure     => running,
    hasrestart => true,
    hasstatus  => true,
    enable     => true,
  }

  create_resources('package', $gitlab::params::gem_packages, {provider =>   gem, source => 'http://rubygems.org/', before => Exec["git clone -b stable ${gitlab_github_url} gitlab"],})

  #
  # Making gitolite repositories folder readable for gitlab
  #
  file {['/var/lib/gitolite/repositories', '/var/lib/gitolite/.gitolite'] :
    ensure  => directory,
    owner   => 'gitolite',
    group   => 'gitolite',
    mode    => '0770',
    recurse => true,
    before  => Exec["git clone -b stable ${gitlab_github_url} gitlab"],
  }
  file {'/var/lib/gitolite/.gitolite/hooks/common/post-receive' :
    ensure => present,
    source => "puppet:///modules/gitlab/post-receive",
    group  => 'gitolite',
    owner  => 'gitolite',
    mode   => '0770',
    before =>  Exec["git clone -b stable ${gitlab_github_url} gitlab"],
  }
  file {"${home_gitlab_user}/.ssh/known_hosts" :
    ensure  => present,
    owner   => $gitlab_user,
    group   => $gitlab_user,
    mode    => '0600',
    content => "${ipaddress} ssh-rsa /* INSERT HERE THE CONTENT OF /etc/ssh/ssh_known_hosts*/",
    before =>  Exec["git clone -b stable ${gitlab_github_url} gitlab"],
  }

  exec {"git clone -b stable ${gitlab_github_url} gitlab" :
    cwd         => $home_gitlab_user,
    environment =>  ["HOME=${home_gitlab_user}"],
    user        =>  $gitlab_user,
    path        =>  ['/bin', '/usr/bin'],
    unless      =>  "ls ${home_gitlab_user}/gitlab"
  }

  file {"${home_gitlab_user}/gitlab/config/gitlab.yml" :
    ensure  => present,
    content => template('gitlab/gitlab.yml'),
    mode    =>  '0700',
    group   =>  $gitlab_user,
    owner   =>  $gitlab_user,
    require =>  Exec["git clone -b stable ${gitlab_github_url} gitlab"],
  }

  file {"${home_gitlab_user}/gitlab/config/database.yml" :
    ensure  => present,
    content => template('gitlab/database.yml.mysql'),
    mode    =>  '0700',
    group   =>  $gitlab_user,
    owner   =>  $gitlab_user,
    require =>  Exec["git clone -b stable ${gitlab_github_url} gitlab"],
  }

  Exec {
    user => $gitlab_user,
    environment  => ["HOME=${home_gitlab_user}"],
    cwd  => "${home_gitlab_user}/gitlab",
    path => ['/usr/local/bin','/bin','/usr/bin','/usr/local/sbin','/usr/sbin','/sbin'],
  }
  exec {'bundle install --without development test sqlite postgres  --deployment' :
    require =>  [File["${home_gitlab_user}/gitlab/config/gitlab.yml"], File["${home_gitlab_user}/gitlab/config/database.yml"]]
  }
  exec {'bundle exec rake gitlab:app:setup RAILS_ENV=production' :
    require =>  Exec['bundle install --without development test sqlite postgres  --deployment'],
  }
  exec {'bundle exec rake gitlab:app:status RAILS_ENV=production' :
    require =>  Exec['bundle exec rake gitlab:app:setup RAILS_ENV=production'],
  }
}
