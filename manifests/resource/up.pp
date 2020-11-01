#
define drbd::resource::up (
  $disk,
) {

  include ::drbd

  $force_primary_cmd = $::drbd_kernel_version_code ?
  {
    /^0x08/ => "drbdadm -- --overwrite-data-of-peer primary ${name}", # drbd 8.x
    /^0x09/ => "drbdadm --force primary ${name}"                      # drbd 9.x
  } 

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

  # enable the resource
  -> exec { "resource ${name}: enable":
    command => "drbdadm up ${name} && sleep 5", # let the connection to establish before next commands
    onlyif  => "drbdadm dstate ${name} | egrep -q '^(Diskless|Unconfigured|Inconsistent|Consistent)'",
    unless  => [
      "drbdadm cstate ${name}",
    ],
    before  => Service['drbd'],
  }

  # establish initial replication (peer connected, no primary, dstate inconsistent)
  -> exec { "resource ${name}: force primary":
    command => $force_primary_cmd,
    unless  => "drbdadm role ${name} | grep 'Primary'",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^Inconsistent'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
  }

  # demote to secondary again if auto-promote is yes
  -> exec { "resource ${name}: make secondary":
    command => "drbdadm secondary ${name}",
    onlyif  => [
      "drbdadm role ${name} | grep 'Primary'",
      'egrep "auto-promote\s+yes" /etc/drbd.d/global_common.conf',
    ],
    refreshonly => true,
  }

  # re-establish replication (peers connected, no primary) only if not auto-promote
  -> exec { "resource ${name}: make primary":
    command => "drbdadm primary ${name}",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^UpToDate'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
    unless  => [
      "drbdadm status ${name} | grep 'role:Primary'",
      'egrep "auto-promote\s+yes" /etc/drbd.d/global_common.conf',
    ]
  }

  # try to reattach disk (peers connected, me is diskless) after io failures and followed detach
  -> exec { "resource ${name}: attach":
    command => "drbdadm attach ${name}",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^Diskless'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
  }

}
