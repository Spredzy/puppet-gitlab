class gitlab::params () {

  $packages = ['python-pygments', 'mysql-devel', 'redis']

  $gem_packages = {
    'charlock_holmes' =>  {
      ensure => '0.6.8',
    },
    'bundler'=> {
    }
  }

  $gitlab_github_url = "https://github.com/gitlabhq/gitlabhq.git"

  $gitolite_user = 'gitolite'
  $home_gitolite_user = '/var/lib/gitolite/'

  $gitlab_user = 'gitlab'
  $home_gitlab_user = '/home/gitlab'

  $ruby_version_short = '1.9'
  $ruby_version_long = '1.9.3-p194'
  $ruby_url = "http://ftp.ruby-lang.org/pub/ruby/${ruby_version_short}/ruby-${ruby_version_long}.tar.gz"


}
