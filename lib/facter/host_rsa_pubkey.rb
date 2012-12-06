# Facter: host_rsa_pubkey
#
#   Indicate the RSA public key of the host
#
Facter.add("host_rsa_pubkey") do
  setcode do
    host_rsa_pubkey = File.read('/etc/ssh/ssh_host_rsa_key.pub')
    host_rsa_pubkey
  end
end
