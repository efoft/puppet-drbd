#
define drbd::resource::up (
  $disk,
) {

  include ::drbd

  # create metadata on device, except if resource seems already initalized
  exec { "resource ${name}: initialize metadata":
    command => "yes yes | drbdadm create-md ${name}",
    onlyif  => [
      "test -b ${disk}",
      "drbdadm dump-md ${name} 2>&1 | grep 'No valid meta data found'",
    ],
    unless  => "drbdadm cstate ${name} | egrep -q '^(Sync|Connected|WFConnection|StandAlone|Verify)'",
    before  => Service['drbd'],
  }

  # normally resources are enabled by DRBD service but in cluster it's disabled
  # so we enable the resource manually
  -> exec { "resource ${name}: enable":
    command => "drbdadm up ${name} && sleep 5", # let the connection to establish before next commands
    onlyif  => "drbdadm dstate ${name} | egrep -q '^(Diskless|Unconfigured|Inconsistent)'",
    unless  => "drbdadm cstate ${name}",
    require => Class['drbd::service'],
  }

  # establish initial replication (peer connected, no primary, dstate inconsistent)
  -> exec { "resource ${name}: force primary":
    command => "drbdadm -- --overwrite-data-of-peer primary ${name}",
    unless  => "drbdadm role ${name} | grep 'Primary'",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^Inconsistent'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
  }

  # re-establish replication (peers connected, no primary)
  -> exec { "resource ${name}: make primary":
    command => "drbdadm primary ${name}",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^UpToDate'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
    unless  => [
      "drbdadm status ${name} | grep 'role:Primary'",
    ]
  }

  # try to reattach disk (peers connected, me is diskless) after io failures and following detach
  -> exec { "resource ${name}: attach":
    command => "drbdadm attach ${name}",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^Diskless'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
  }

}
