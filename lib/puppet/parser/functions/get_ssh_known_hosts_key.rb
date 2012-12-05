module Puppet::Parser::Functions
  newfunction(:get_ssh_known_hosts_key, :type => :rvalue) do |args|

    pubkey = args[0].split(' ')[1]
    pubkey
  end
end
