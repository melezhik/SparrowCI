sub MAIN(
  Str $comp,
  Str $action,
  Str :$base?,
) {

    say "Execute $action on $comp ...";

    my $c = _get_conf();

    if $comp eq "worker" and $action ne "conf" {
      unless $c<worker><base> {
        say "worker base dir not found, tell me where to look it up:";
        say "sparman --base /path/to/basedir worker conf";
        exit(1)
      }
      if $action eq "start" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparkyd|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then ] ~
            qq[cd {$c<worker><base>} ] ~
            q[mkdir -p ~/.sparkyd
            nohup sparkyd 1>~/.sparky/sparkyd.log 2>&1 & < /dev/null;
            echo "run [OK]"
          else
            echo "already running pid=$pid ..."
          fi
        ];          
        say $cmd;
        shell $cmd;
      } elsif $action eq "stop" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparkyd|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "already stopped"
          else
            echo "kill $pid ..."
            kill $pid
            echo "stop [OK]"
          fi
        ];
        say $cmd;
        shell $cmd;
      }
    } elsif $action eq "conf" {
      if $base {
        $c<worker><base> = $base;
        _update_conf($c);
      }
    }
}


sub _get_conf {
  if "{%*ENV<HOME>}/.sparman/conf.raku".IO ~~ :e {
    EVALFILE "{%*ENV<HOME>}/.sparman/conf.raku"
  } else {
    return {}
  }
}

sub _update_conf (%c) {
  mkdir "{%*ENV<HOME>}/.sparman/";
  say "update {%*ENV<HOME>}/.sparman/conf.raku ...";
  "{%*ENV<HOME>}/.sparman/conf.raku".IO.spurt(%c.perl)
}
