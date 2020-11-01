#
# This class can be used to configure the drbd service.
#
# It has been first forked from https://github.com/voxpupuli/puppet-drbd/
# then almost completely rewritten and refactored.
#
class drbd (
  Enum['8.4','9.0']                       $version        = '9.0',
  Optional[Variant[String,Array[String]]] $package_name   = undef,
  Boolean                                 $service_enable = true,
  Enum['running', 'stopped', 'unmanaged'] $service_ensure = running,
  Hash                                    $global_options = {},
  Hash                                    $common_options = {},
) {

  include drbd::service

  ## Packages names have no dot
  $version_internal  = regsubst($version, '\.', '')

  ## If no specific packages are given then use version to form their names
  $package_name_real = $package_name ?
  {
    undef   => ["drbd${version_internal}-utils","kmod-drbd${version_internal}"],
    default => $package_name
  }

  package { $package_name_real:
    ensure => present,
  }
  -> exec { 'modprobe drbd':
    path   => ['/bin/', '/sbin/'],
    unless => 'grep -qe \'^drbd \' /proc/modules',
  }

  File {
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    require => Package[$package_name_real],
    notify  => Class['drbd::service'],
  }

  file { '/drbd':
    ensure => directory,
  }

  # this file just includes other files
  file { '/etc/drbd.conf':
    source  => 'puppet:///modules/drbd/drbd.conf',
  }

  file { '/etc/drbd.d/global_common.conf':
    content => template('drbd/global_common.conf.erb'),
  }

  # only allow files managed by puppet in this directory.
  file { '/etc/drbd.d':
    ensure  => directory,
    purge   => true,
    recurse => true,
    force   => true,
  }
}
