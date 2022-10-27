package-install "libtemplate-perl carton";

my $user = "sph";

systemd-service "sparkyci", %(
  user => $user,
  workdir => "/home/$user/projects/sparrowci_web",
  command => "/usr/bin/bash  --login -c 'cro run 1>>~/.sparkyci/sparkyci.log 2>&1'"
);

bash "systemctl daemon-reload";

# start service

service-restart "sparrowci_web";

service-enable "sparrowci_web";

