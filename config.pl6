use YAMLish;

my $example-path = "files/examples/ruby/artifacts.yaml";

say "load config from $example-path ...";

my $conf = load-yaml($example-path.IO.slurp());

say $conf.perl;

$conf;

