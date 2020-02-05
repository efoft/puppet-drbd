#
# @summary                   Used to created a resource that replicates data between 2 hosts for HA.
#
# @param disk                Name of disk to be replicated. Assumes that the name of the disk will be the same on both hosts.
# @param host1               Name of first host. Required unless $cluster is set.
# @param host2               Name of second host. Required unless $cluster is set.
# @param ip1                 Ipaddress of first host. Required unless $cluster or $res1/$res2 is set.
# @param ip2                 Ipaddress of second host. Required unless $cluster or $res1/$res2 is set.
# @param res1                First stacked resource name.
# @param res2                Second stacked resource name.
# @param cluster_name        Arbitary work used as tag for exported resources.
# @param secret              The shared secret used in peer authentication. No auth required if undef.
# @param myip                To override fact in case of multihomed hosts.
# @param port                Port which drbd will use for replication on both hosts.
# @param device              The path of the drbd device to be used.
# @param protocol            Protocol to use for drbd. See http://www.drbd.org/users-guide/s-replication-protocols.html
# @param verify_alg          Algorithm used for block validation on peers.
# @param disk_parameters     Parameters for disk{} section.
# @param handlers_parameters Parameters for handlers{} section.
# @param startup_parameters  Parameters for startup{} section.
# @param manage              If the actual drbd resource should be managed.
# @param metadisk            Must be the same on both hosts. Ignored if flexible_metadisk is defined.
# @param flexible_metadisk   Name of the flexible_metadisk. If defined, the metadisk parameter is superseeded.
#
define drbd::resource (
  Stdlib::Unixpath                      $disk,
  Optional[Stdlib::Host]                $host1                = undef,
  Optional[Stdlib::Host]                $host2                = undef,
  Optional[Stdlib::Ip::Address]         $ip1                  = undef,
  Optional[Stdlib::Ip::Address]         $ip2                  = undef,
  Optional[String]                      $res1                 = undef,
  Optional[String]                      $res2                 = undef,
  Optional[String]                      $cluster_name         = undef,
  Optional[String]                      $secret               = undef,
  Stdlib::Ip::Address                   $myip                 = $::ipaddress,
  Integer                               $port                 = 7789,
  Stdlib::Unixpath                      $device               = '/dev/drbd0',
  Enum['A','B','C']                     $protocol             = 'C',
  Enum['crc32c','sha1','md5']           $verify_alg           = 'crc32c',
  Optional[String]                      $rate                 = undef,
  Hash                                  $disk_parameters      = {},
  Hash                                  $net_parameters       = {},
  Hash[String, Variant[Integer,String]] $handlers_parameters  = {},
  Hash[String, Variant[Integer,String]] $startup_parameters   = {},
  Boolean                               $manage               = true,
  String[1]                             $metadisk             = 'internal',
  Optional[String[1]]                   $flexible_metadisk    = undef,
) {

  include drbd

  Exec {
    path      => ['/bin', '/sbin', '/usr/bin'],
    logoutput => 'on_failure',
  }

  concat { "/etc/drbd.d/${name}.res":
    owner  => 'root',
    group  => 'root',
    mode   => '0600',
    notify => Class['drbd::service'],
  }

  concat::fragment { "${name} drbd header":
    target  => "/etc/drbd.d/${name}.res",
    content => template('drbd/header.res.erb'),
    order   => '01',
  }

  if $cluster_name {
    # Export our fragment for the clustered node
    @@drbd::resource::peer { "${name} resource of ${::fqdn}":
      disk     => $disk,
      peer     => $::fqdn,
      resource => $name,
      ip       => $myip,
      port     => $port,
      manage   => $manage,
      tag      => $cluster_name,
    }
  } elsif $host1 and $ip1 and $host2 and $ip2 {
    concat::fragment { "${name} static primary resource":
      target  => "/etc/drbd.d/${name}.res",
      content => template('drbd/primary-resource.res.erb'),
      order   => '10',
    }
    concat::fragment { "${name} static secondary resource":
      target  => "/etc/drbd.d/${name}.res",
      content => template('drbd/secondary-resource.res.erb'),
      order   => '20',
    }
  } elsif $res1 and $ip1 and $res2 and $ip2 {
    concat::fragment { "${name} static stacked primary resource":
      target  => "/etc/drbd.d/${name}.res",
      content => template('drbd/primary-stacked-resource.res.erb'),
      order   => '10',
    }
    concat::fragment { "${name} static stacked secondary resource":
      target  => "/etc/drbd.d/${name}.res",
      content => template('drbd/secondary-stacked-resource.res.erb'),
      order   => '20',
    }
  } else {
    fail('Must provide either cluster, host1/host2/ip1/ip2 or res1/res2/ip1/ip2 parameters')
  }

  concat::fragment { "${name} drbd footer":
    target  => "/etc/drbd.d/${name}.res",
    content => "}\n",
    order   => '99',
  }

  if $cluster_name {
    # Import cluster nodes and realize DRBD service
    Drbd::Resource::Peer <<| tag == $cluster_name |>>
  }
  else {
    if $manage {
      drbd::resource::up { $name:
        disk => $disk,
      }
    }
    realize(Service['drbd'])
  }
}
