unit module SparrowCI::Conf;

use YAMLish;

my %conf;

sub get-sparrowci-conf is export {

  return %conf if %conf;
 
  my $conf-file = %*ENV<HOME> ~ '/sparkyci.yaml';

  %conf = $conf-file.IO ~~ :f ?? load-yaml($conf-file.IO.slurp) !! Hash.new;

  return %conf;

}

sub http-root is export {

  %*ENV<SPARKYCI_HTTP_ROOT> || "";

}

sub sparrowci-root is export {

  "{%*ENV<HOME>}/.sparkyci"
}

sub cache-root is export {

  "{%*ENV<HOME>}/.sparkyci/";

}

sub title is export { 

  "SparrowCI - super fun and flexible CI system with many programming languages support."

}


sub default-theme is export {
  "dark"
}

