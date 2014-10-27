# == Class: redis::install
#
# Installs redis from source (http://redis.googlecode.com).
# Has to be includes before the redis::server functions are called.
#
# === Parameters
#
# [*redis_version*]
#   The redis version to be installed. By default, the latest stable build will be installed.
#
# [*redis_build_dir*]
#   The dir to store redis source code.
#
# [*redis_install_dir*]
#   The dir to which the newly built redis binaries are copied. Default value is '/usr/bin'.
#
class redis::install (
  $redis_version         = $::redis::params::redis_version,
  $redis_build_dir       = $::redis::params::redis_build_dir,
  $redis_install_dir     = $::redis::params::redis_install_dir,
  $redis_from_repository = $::redis::params::redis_from_repository
) inherits redis {

  if $redis_from_repository {
    case $::operatingsystem {
      'Debian', 'Ubuntu': {
        package { 'redis-server':
          ensure => $redis_version,
        }

        file { "/etc/init.d/redis-server":
          ensure  => absent,
          require => Package['redis-server']
        }
      }
      default: {
        fail('The module does not support this OS.')
      }
    }
  } else {
    # install necessary packages for build.
    case $::operatingsystem {
      'Debian', 'Ubuntu': {
        if (! defined(Package['build-essential'])) {
          package { 'build-essential':
            ensure => installed,
            before => Anchor['redis::prepare_build']
          }
        }
      }

      'Fedora', 'RedHat', 'CentOS', 'OEL', 'OracleLinux', 'Amazon': {
        package { 'make':
          ensure => installed,
          before => Anchor['redis::prepare_build']
        }

        package { 'gcc':
          ensure => installed,
          before => Anchor['redis::prepare_build']
        }

        package { 'glibc-devel':
          ensure => installed,
          before => Anchor['redis::prepare_build']
        }
      }
      default: {
        fail('The module does not support this OS.')
      }
    }

    exec { "Make dir ${redis_build_dir}":
      command => "mkdir -p ${redis_build_dir}",
      creates => $redis_build_dir,
      path    => $::path,
      cwd     => '/',
      user    => 'root',
      group   => 'root',
      before  => File[$redis_build_dir]
    }

    file { $redis_build_dir:
      ensure => directory,
    }

    if $redis_version == $::redis::params::redis_version {
        $redis_download_url = 'http://download.redis.io/redis-stable.tar.gz'
    } else {
        $redis_download_url = "http://download.redis.io/releases/redis-${redis_version}.tar.gz"
    }

    exec { "Download and untar redis ${redis_version}":
      require => File[$redis_build_dir],
      before  => Anchor['redis::prepare_build'],

      command => "wget -O - ${redis_download_url} | tar xz",
      creates => "${redis_build_dir}/redis-${::redis::install::redis_version}",
      path    => $::path,
      cwd     => $redis_build_dir,
      user    => 'root',
      group   => 'root',
    }

    anchor { 'redis::prepare_build':
      before => Exec['redis::compile'],
    }

    # if this fails, then a 'make distclean' can help
    exec { 'redis::compile':
      command => 'make',
      creates => "${redis_build_dir}/redis-${redis_version}/src/redis-server",
      cwd     => "${redis_build_dir}/redis-${::redis::install::redis_version}/",
      path    => $::path,
      user    => 'root',
      group   => 'root',
    }

    file { "${redis_build_dir}/redis":
      ensure  => link,
      target  => "${redis_build_dir}/redis-${::redis::install::redis_version}/src/",
      require => Exec['redis::compile']
    }

    anchor { 'redis::install':
      require => File["${redis_build_dir}/redis"],
    }

    $redis_binaries = [
      'redis-benchmark',
      'redis-check-aof',
      'redis-check-dump',
      'redis-cli',
      'redis-sentinel',
      'redis-server'
    ]

    redis::installbinary { $redis_binaries:
      require           => Anchor['redis::install'],
      redis_build_dir   => $redis_build_dir,
      redis_install_dir => $redis_install_dir,
    }
  }
}
