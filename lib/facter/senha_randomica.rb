Facter.add("senha_randomica") do
  setcode do
    Facter::Util::Resolution.exec("/bin/openssl rand -base64 32|sed \"s/[^a-zA-Z0-9]//g\"")
  end
end
