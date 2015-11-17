$packages = [
  'build-essential',
  'git',
  'zlibc',
  'zlib1g-dev',
  'ruby',
  'ruby-dev',
  'openssl',
  'libxslt1-dev',
  'libxml2-dev',
  'libssl-dev',
  'libreadline6',
  'libreadline6-dev',
  'libyaml-dev',
  'libsqlite3-dev',
  'sqlite3',
  'dstat',
  'unzip',
  'bundler',
  'jq',
]
package { $packages:
  ensure => 'installed',
}
exec { 'bundle install':
  logoutput => true,
  cwd       => '/home/ubuntu/scripts',
  path      => '/bin:/usr/bin:/usr/local/bin',
  unless    => 'bundle check',
}
notify {'i am running':}
