class gitlab::params () {

  $packages = ['make', 'gcc', 'gcc-c++', 'openssl-devel', 'libicu-devel', 'libyaml-devel', 'python-pygments', 'mysql-devel']

  $gem_packages = {
    'charlock_holmes' =>  {
      source => 'http://rubygems.org/downloads/charlock_holmes-0.6.8.gem',
    },
    'bundler'=> {
      source => 'http://rubygems.org/downloads/bundler-1.2.2.gem'
    }
  }

  $gitlab_github_url = "https://github.com/gitlabhq/gitlabhq.git"

  $gitolite_user = 'gitolite'
  $home_gitolite_user = '/var/lib/gitolite/'

  $gitlab_user = 'gitlab'
  $home_gitlab_user = '/home/gitlab'

  $ruby_version_short = '1.9'
  $ruby_version_long = '1.9.30p194'
  $ruby_url = "http://ftp.ruby-lang.org/pub/ruby/${ruby_version_short}/ruby-${ruby_version_long}.tar.gz"


}
