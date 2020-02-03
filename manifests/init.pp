#
# This class can be used to configure the drbd service.
#
# It has been first forked from https://github.com/voxpupuli/puppet-drbd/
# then almost completely rewritten and refactored.
#
class drbd (
  Boolean                                 $service_enable = true,
  Enum['running', 'stopped', 'unmanaged'] $service_ensure = running,
  Variant[String,Array[String]]           $package_name   = ['drbd84-utils','kmod-drbd84'],
) {

  include drbd::service

  package { $package_name:
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
    require => Package[$package_name],
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
