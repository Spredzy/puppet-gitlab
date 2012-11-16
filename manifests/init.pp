# Class: gitlab
#
# This class install gitolite and a gitolite-admin account
#
#
class gitlab (
  $gitlab_user = $gitlab::params::gitlab_user,
  $home_gitlab_user = $gitlab::params::home_gitlab_user) inherits gitlab::params {

  Class['gitolite'] -> Class['mysql::server'] -> Class['gitlab']

  $gitolite_user = $git::params::gitolite_user
  $home_gitolite_user = $git::params::home_gitolite_user

  class {'gitolite' :
    $gitolite_admin_user      => $gitlab_user,
    $home_gitolite_admin_user => $home_gitlab_user,
  }

  class {'mysql::server' :
    config_hash => {'root_password' => 'changeit' }
  }

  mysql::db {'gitlabhq_production' :
    ensure   => present,
    user     => 'gitlab',
    password => 'changeit',
    host     => 'localhost',
    grant    => ['all'],
    require  => Class['mysql::server'],
  }

  package {[$gitlab::params::packages] :
    ensure => latest,
  }

  exec {"curl -L ${gitlab::params::ruby_url} | tar -xzvf - && cd ruby-${gitlab::params::ruby_version_long} && ./configure && make && make install" :
    cwd    => '/tmp',
    path   => ['/usr/bin', '/usr/local/bin'],
    unless =>  'ruby -v',
  }

  create_resources('package', $gitlab::params::gem_packages, {ensure =>  installed, provider => gem,})

  #
  # Making gitolite repositories folder readable for gitlab
  #
  file {'/var/lib/gitolite/repositories' :
    ensure => directory,
    owner  => 'gitolite',
    group  => 'gitolite',
    mode   => '0770',
  }
  file {'/var/lib/gitolite/.gitolite.rc' :
    ensure => present,
    owner  => 'gitolite',
    group  => 'gitolite',
    mode   => '0770',
  }
  file {'/var/lib/gitolite/hooks/common/post-receive' :
    ensure => present,
    source => "pupet:///modules/gitlab/post-receive",
    group  => 'gitolite',
    owner  => 'gitolite',
    mode   => '0770',
  }

  exec {"git clone -b stable ${gitlab_github_url} gitlab" :
    cwd         => $home_gitlab_user,
    environment =>  ["HOME=${home_gitlab_user}"],
    user        =>  $gitlab_user,
    path        =>  ['/bin', '/usr/bin'],
    unless     =>  "ls ${home_gitlab_user}/gitlab"
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
    cwd  => $home_gitlab_user,
    path => '/usr/local/bin/',
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

























