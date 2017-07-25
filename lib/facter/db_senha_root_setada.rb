Facter.add("db_senha_root_setada") do
  setcode do
    Facter::Util::Resolution.exec("test -f /root/.my.cnf && echo true")
  end
end
