#
# @summary  Used to export and collect the peers info via PuppetDB
#
define drbd::resource::peer (
  String  $peer,
  String  $resource,
  String  $ip,
  Numeric $port,
  Boolean $manage,
) {

  concat::fragment { "${resource} resource of ${peer}":
    target  => "/etc/drbd.d/${resource}.res",
    content => template('drbd/resource.res.erb'),
    order   => '10',
  }

  # if this collected resource is really from peer we can activate drbd service and the resource
  if $peer != $::fqdn {
    if $manage {
      drbd::resource::up { $resource:
        disk => $disk,
      }
    }
    realize(Service['drbd'])
  }
}
