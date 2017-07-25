Facter.add("usuario_asterisk_existe") do
  setcode do
    Facter::Util::Resolution.exec("egrep  '^asterisk:' /etc/passwd  > /dev/null 2>&1 && echo true")
  end
end
