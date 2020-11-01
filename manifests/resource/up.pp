#
define drbd::resource::up (
  $disk,
) {

  include ::drbd

  # random number of seconds to wait after DRBD service started and before proceeding with drbdadm force primary 
  # to avoid race condition between the nodes
  $seconds = seeded_rand(30, $::fqdn)

  $force_primary_cmd = $drbd::version ?
  {
    '8.4' => "sleep ${seconds} && drbdadm -- --overwrite-data-of-peer primary ${name} && sleep 5",
    '9.0' => "sleep ${seconds} && drbdadm --force primary ${name} && sleep 5"
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
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^Inconsistent'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
    unless  => [
      "drbdadm role ${name} | grep 'Primary'",
      "drbdadm status ${name} | grep 'peer-disk:UpToDate'",
    ],
    require => Service['drbd'],
  }

  # make the resource secondary again after initial sync unless two primaries are allowed
  # we make it secondary because usually drbd role is managed by external means like cluster
  ~> exec { "resource ${name}: make secondary after initial sync":
    command => "drbdadm secondary ${name}",
    onlyif  => "drbdadm role ${name} | grep 'Primary'",
    unless  => "drbdadm dump ${name} | egrep 'allow-two-primaries\s+yes'",
    refreshonly => true,
  }

  # establish replication if two primaries are allowed (incompatible with cluster managed drbd ?)
  -> exec { "resource ${name}: make primary":
    command => "drbdadm primary ${name}",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^UpToDate'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
      "drbdadm dump ${name} | egrep 'allow-two-primaries\s+yes'",
    ],
    unless  => [
      "drbdadm role ${name} | grep 'Primary'",
    ]
  }

  # try to reattach disk (peers connected, me is diskless) after i/o failures and followed detach
  -> exec { "resource ${name}: attach":
    command => "drbdadm attach ${name}",
    onlyif  => [
      "drbdadm dstate ${name} | egrep -q '^Diskless'",
      "drbdadm cstate ${name} | grep -q 'Connected'",
    ],
  }
}
