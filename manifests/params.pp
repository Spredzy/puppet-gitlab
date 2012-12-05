class gitlab::params () {

  case $::osfamily {
    'RedHat' : {
      $packages = ['python-pygments', 'mysql-devel', 'redis']
      $redis = 'redis'
    }
    'Debian' : {
      $packages = ['python-pygments', 'libmysqlclient-dev', 'redis-server']
      $redis = 'redis-server'
    }
    default : {
      fail("Unsupported OS : $::osfamily - Get in touch with the Module maintainer to see how we can fix that")
    }
  }

  $gem_packages = {
    'charlock_holmes' =>  {
      ensure => '0.6.8',
    },
    'bundler'=> {
    },
    'unicorn' => {
    }
  }

  $gitlab_github_url = "https://github.com/gitlabhq/gitlabhq.git"

  $gitolite_user = 'gitolite'
  $home_gitolite_user = '/var/lib/gitolite/'

  $gitlab_user = 'gitlab'
  $home_gitlab_user = '/home/gitlab'

  #
  # Ruby Parameters
  #
  $ruby_version_short = '1.9'
  $ruby_version_long = '1.9.3-p194'
  $ruby_url = "http://ftp.ruby-lang.org/pub/ruby/${ruby_version_short}/ruby-${ruby_version_long}.tar.gz"

  #
  # Unicorn Parameters
  #
  $unicorn_work_processes = 4
  $port = '8080'

}
