# Class: gitlab
#
# This class install gitolite and a gitolite-admin account
#
#
define gitlab::instance(
  $version                  = '3.1',
  $user                     = $name,
  $known_hosts_encryption   =  'rsa',
  $base_path                = "/opt/gitlab-${name}") {

  require gitlab

  case $known_hosts_encryptions {
      'dsa' : {
        $ssh_known_hosts_key  = $sshdsakey
        $type_encryption      = 'ssh-dss'
      }
      default : {
        $ssh_known_hosts_key  = $sshrsakey
        $type_encryption      = 'ssh-rsa'
      }
  }

  $gitolite_home          = "/opt/gitolite-${name}"
  $db_name                = "gitlabhq_production_${user}"
  $db_user                = "gitlab_${user}"
  $cnt                    = is_ssh_pub_key_present($base_path)
  $port                   = $gitlab::params::port
  $unicorn_work_processes = $gitlab::params::unicorn_work_processes
  $httpd                  = $gitlab::params::httpd



  #
  # User / Group / Home / Public SSH Key creation
  #
  group {"gitlab_${user}" :
    ensure => present,
  }

  user {"gitlab_${user}" :
    ensure           => present,
    home             => $base_path,
    comment          => "gitlab user gitlab_${user}",
    gid              => "gitlab_${user}",
    shell            => "/bin/sh",
    password_min_age => '0',
    password_max_age => '99999',
    password         => '*',
  }

  $h = get_cwd_hash_path($base_path, $user)
  create_resources('file', $h)

  file {$base_path :
    ensure  => directory,
    owner   => "gitlab_${user}",
    group   => "gitlab_${user}",
    mode    => '0700',
    require => User["gitlab_${user}"],
  }

  exec {"ssh-keygen -N '' -f ${base_path}/.ssh/id_rsa" :
    cwd     =>  $base_path,
    user    =>  "gitlab_${user}",
    path    =>  ['/bin', '/usr/bin'],
    require =>  File[$base_path],
    unless  =>  "ls ${base_path}/.ssh/id_rsa.pub",
  }

  if $cnt == 1 {

  #
  # Instantiation of gitolite instance
  #
  gitolite::instance {"gitolite_${user}" :
    version       => '3.04',
    admin_pub_key =>  file("${base_path}/.ssh/id_rsa.pub"),
    require       =>  Exec["ssh-keygen -N '' -f ${base_path}/.ssh/id_rsa"],
    home          =>  $gitolite_home,
  }

  exec {"usermod -G gitlab_${user} gitolite_${user}":
    cwd     =>  '/',
    user    =>  'root',
    path    =>  '/usr/sbin',
    require =>  Gitolite::Instance["gitolite_${user}"],
  }
  exec {"usermod -G gitolite_${user} gitlab_${user}":
    cwd     =>  '/',
    user    =>  'root',
    path    =>  '/usr/sbin',
    require =>  Gitolite::Instance["gitolite_${user}"],
  }

  #
  # Making gitolite repositories folder readable for gitlab
  #
  file {["${gitolite_home}/repositories", "${gitolite_home}/.gitolite"] :
    ensure  => directory,
    owner   => "gitolite_${user}",
    group   => "gitolite_${user}",
    mode    => '0770',
    recurse => true,
    require => [Exec["usermod -G gitlab_${user} gitolite_${user}"], Exec["usermod -G gitolite_${user} gitlab_${user}"]],
    before  => Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }
  file {"${gitolite_home}/.gitolite/hooks/common/post-receive" :
    ensure => present,
    source => "puppet:///modules/gitlab/post-receive",
    group  => "gitolite_${user}",
    owner  => "gitolite_${user}",
    mode   => '0770',
    require => [Exec["usermod -G gitlab_${user} gitolite_${user}"], Exec["usermod -G gitolite_${user} gitlab_${user}"]],
    before =>  Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }

  sshkey {"gitlab_${user}@${hostname}" :
    ensure => present,
    key    => $ssh_known_hosts_key,
    type   => $type_encryption,
    name   => $ipaddress,
    before => Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }

  #
  # Setting up the database schema
  #
  exec {"mysql -uroot -p'changeit' -e 'CREATE DATABASE IF NOT EXISTS ${db_name} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci'" :
    cwd     => '/',
    user    => 'root',
    path    => '/usr/bin',
  }

  exec {"mysql -uroot -p'changeit' -e 'GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON ${db_name}.* TO ${db_user}@\"${ipaddress}\" identified by \"changeit\"'" :
    cwd     => '/',
    user    => 'root',
    path    => '/usr/bin',
    require =>  Exec["mysql -uroot -p'changeit' -e 'CREATE DATABASE IF NOT EXISTS ${db_name} DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci'"],
    before  =>  Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }

  #
  # Actual gitlab installation and configuration
  #
  exec {"git clone -b stable ${gitlab::params::gitlab_github_url} gitlab" :
    cwd         =>  $base_path,
    environment =>  ["HOME=${base_path}"],
    user        =>  "gitlab_${user}",
    path        =>  ['/bin', '/usr/bin'],
    unless      =>  "ls ${base_path}/gitlab"
  }
  file {"${base_path}/gitlab/config/database.yml" :
    ensure  =>  present,
    content =>  template('gitlab/database.yml.mysql'),
    mode    =>  '0700',
    group   =>  "gitlab_${user}",
    owner   =>  "gitlab_${user}",
    require =>  Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }
  file {"${base_path}/gitlab/config/unicorn.rb" :
    ensure  =>  present,
    content =>  template('gitlab/unicorn.rb'),
    mode    =>  '0700',
    group   =>  "gitlab_${user}",
    owner   =>  "gitlab_${user}",
    require =>  Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }

  #
  # unicorn binary does not create those directories, unicorn_rails does, *but*
  # unicorn seems to load project faster (totally subjective, no research has been made,
  # purely personal feeling), so creating those directory we enable our project 
  #
  file {["${base_path}/gitlab/tmp/pids/", "${base_path}/gitlab/tmp/log", "${base_path}/gitlab/tmp/sockets", "${base_path}/gitlab/tmp/sessions", "${base_path}/gitlab/tmp/cache",] :
    ensure  => directory,
    group   =>  "gitlab_${user}",
    owner   =>  "gitlab_${user}",
    mode    => '0700',
    require =>  Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }
  file {"${base_path}/gitlab/config/gitlab.yml" :
    ensure  => present,
    content => template('gitlab/gitlab.yml'),
    mode    =>  '0700',
    group   =>  "gitlab_${user}",
    owner   =>  "gitlab_${user}",
    require =>  Exec["git clone -b stable ${gitlab::params::gitlab_github_url} gitlab"],
  }

  #
  # Project installation & Deployment
  #
  exec {'bundle install --without development test sqlite postgres  --deployment' :
    user        =>  "gitlab_${user}",
    environment =>  ["HOME=${base_path}"],
    cwd         =>  "${base_path}/gitlab",
    path        =>  ['/usr/local/bin','/bin','/usr/bin','/usr/local/sbin','/usr/sbin','/sbin'],
    require     =>  [File["${base_path}/gitlab/config/gitlab.yml"], File["${base_path}/gitlab/config/database.yml"], File["${base_path}/gitlab/config/unicorn.rb"], File["${base_path}/gitlab/tmp/log"], File["${base_path}/gitlab/tmp/pids/"], File["${base_path}/gitlab/tmp/sockets"],File["${base_path}/gitlab/tmp/sessions"],File["${base_path}/gitlab/tmp/cache"]],
  }
  exec {'bundle exec rake gitlab:app:setup RAILS_ENV=production' :
    user        =>  "gitlab_${user}",
    environment =>  ["HOME=${base_path}"],
    cwd         =>  "${base_path}/gitlab",
    path        =>  ['/usr/local/bin','/bin','/usr/bin','/usr/local/sbin','/usr/sbin','/sbin'],
    require     =>  Exec['bundle install --without development test sqlite postgres  --deployment'],
  }
  exec {'bundle exec rake gitlab:app:status RAILS_ENV=production' :
    user        =>  "gitlab_${user}",
    environment =>  ["HOME=${base_path}"],
    cwd         =>  "${base_path}/gitlab",
    path        =>  ['/usr/local/bin','/bin','/usr/bin','/usr/local/sbin','/usr/sbin','/sbin'],
    require     =>  Exec['bundle exec rake gitlab:app:setup RAILS_ENV=production'],
  }
  exec {'bundle exec unicorn -c config/unicorn.rb -E production -D' :
    user        => "gitlab_${user}",
    environment =>  ["HOME=${base_path}"],
    cwd         =>  "${base_path}/gitlab",
    path        =>  ['/usr/local/bin','/bin','/usr/bin','/usr/local/sbin','/usr/sbin','/sbin'],
    require     => Exec['bundle exec rake gitlab:app:status RAILS_ENV=production'],
  }

  file {"${gitlab::params::vhost_path}/10-gitlab-${user}.conf" :
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("gitlab/vhost-unicorn.conf"),
    require => Exec['bundle exec unicorn -c config/unicorn.rb -E production -D'],
    notify  => Exec["${user} apache reload"],
  }
  exec {"${user} apache reload" :
    user    => 'root',
    cwd     => '/',
    command => "service ${httpd} reload",
    path    =>  ['/usr/local/bin','/bin','/usr/bin','/usr/local/sbin','/usr/sbin','/sbin'],
  }


  /** END **/
  }
}
