module Puppet::Parser::Functions
  newfunction(:get_ssh_known_hosts_key, :type => :rvalue) do |args|

    info = args[0].split(' ')
    pubkey = {
      "type" =>  info[0],
      "key"  =>  info[1],
      "host" =>  info[2]
    }
    pubkey
  end
end
