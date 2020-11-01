#
class drbd::service inherits drbd {

  if $service_ensure == 'unmanaged' {
    $_ensure = undef
  } else {
    $_ensure = $service_ensure
  }

  @service { 'drbd':
    ensure  => $_ensure,
    enable  => $service_enable,
    require => Package[$package_name],
    restart => 'systemctl reload drbd',
  }
}
