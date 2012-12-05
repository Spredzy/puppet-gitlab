module Puppet::Parser::Functions
  newfunction(:is_ssh_pub_key_present, :type => :rvalue) do |args|

    pubkey = args[0] + "/.ssh/id_rsa.pub"
    doesExist = File.exists?(pubkey) ? 1 : 0
    doesExist
  end
end
