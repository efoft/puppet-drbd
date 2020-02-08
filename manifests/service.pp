#
class drbd::service inherits drbd {

  if $service_ensure == 'unmanaged' {
    $_ensure = undef
  } else {
    $_ensure = $service_ensure
  }

  # random number of seconds to wait after DRBD service started and before proceeding with drbdadm primary commands
  # to avoid race condition between the nodes
  $seconds = seeded_rand(30, $::fqdn)

  @service { 'drbd':
    ensure  => $_ensure,
    enable  => $service_enable,
    require => Package[$package_name],
    restart => 'systemctl reload drbd',
  }

  # sleep random number of seconds
  if $service_ensure == 'running' {
    exec { "sleep ${seconds} seconds before trying to become primary":
      command     => "sleep ${seconds}",
      refreshonly => true,
      path        => ['/usr/bin','/bin'],
      subscribe   => Service['drbd'],
    }
  }
}
