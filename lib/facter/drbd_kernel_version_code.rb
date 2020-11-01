# drbd_kernel_version_code.rb

Facter.add(:drbd_kernel_version_code) do
  confine :kernel => 'Linux'
  setcode do
    original_path = ENV['PATH']
    path = ENV.fetch('PATH') { '/bin:/usr/bin:/usr/local/bin' }
    ENV['PATH'] = path + ':/usr/local/bin'
    begin
      Facter::Util::Resolution.exec('drbdadm --version 2> /dev/null | grep DRBD_KERNEL_VERSION_CODE').lines.first.split('=')[1]
    rescue
      nil
    ensure
      ENV['PATH'] = original_path
    end
  end
end
