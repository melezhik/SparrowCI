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
        say "sp_man --base /path/to/basedir worker conf";
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
  if "{%*ENV<HOME>}/.sp_man/conf.raku".IO ~~ :e {
    EVALFILE "{%*ENV<HOME>}/.sp_man/conf.raku"
  } else {
    return {}
  }
}

sub _update_conf (%c) {
  mkdir "{%*ENV<HOME>}/.sp_man/";
  say "update {%*ENV<HOME>}/.sp_man/conf.raku ...";
  "{%*ENV<HOME>}/.sp_man/conf.raku".IO.spurt(%c.perl)
}
