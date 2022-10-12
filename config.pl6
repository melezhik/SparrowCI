use YAMLish;

say "load config from files/example.raku ...";

my $conf = load-yaml("files/example.raku".IO.slurp());

say $conf.perl;

$conf;

