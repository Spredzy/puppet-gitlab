# Facter: host_dsa_pubkey
#
#   Indicate the dsa public key of the host
#
Facter.add("host_dsa_pubkey") do
  setcode do
    host_dsa_pubkey = File.read('/etc/ssh/ssh_host_dsa_key.pub')
    host_dsa_pubkey
  end
end
