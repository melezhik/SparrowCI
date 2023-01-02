sub MAIN(
  Str $comp,
  Str $action,
  Str :$base?,
  Bool :$verbose = False,
) {

    say "Execute $action on $comp ...";

    my $c = _get_conf();

    if $comp eq "worker_ui" {
      if ! $c<worker><base> and $action ne "conf" {
        say "worker ui base dir not found, tell me where to look it up:";
        say "sparman --base /path/to/basedir worker conf";
        exit(1)
      }
      if $action eq "start" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparky-web.raku|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then ] ~
            qq[cd {$c<worker><base>} ] ~
            q[mkdir -p ~/.sparky
            nohup cro run 1>~/.sparky/sparky-web.log 2>&1 & < /dev/null;
            echo "run [OK]"
          else
            echo "already running pid=$pid ..."
          fi
        ];          
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "stop" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparky-web.raku|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "already stopped"
          else
            echo "kill $pid ..."
            kill $pid
            echo "stop [OK]"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "conf" {
        if $base {
          $c<worker><base> = $base;
          _update_conf($c);
        }
      } elsif $action eq "status" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparky-web.raku|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "stop [OK]"
          else
            echo "run [OK]"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      }
    } 
    if $comp eq "worker" {
      if $action eq "start" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparkyd|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            mkdir -p ~/.sparky/
            nohup sparkyd 1>~/.sparky/sparkyd.log 2>&1 & < /dev/null;
            echo "run [OK]"
          else
            echo "already running pid=$pid ..."
          fi
        ];          
        say $cmd if $verbose;
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
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "status" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep bin/sparkyd|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "stop [OK]"
          else
            echo "run [OK]"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      }
    }

    if $comp eq "ui" {
      if ! $c<sparrowci><base> and $action ne "conf" {
        say "sparrowci ui base dir not found, tell me where to look it up:";
        say "sparman --base /path/to/basedir ui conf";
        exit(1)
      }
      if $action eq "start" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep sparrowci_web.raku|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then ] ~
            qq[cd {$c<sparrowci><base>} ] ~
            q[mkdir -p ~/.sparrowci/
            nohup cro run 1>~/.sparrowci/sparrowci_web.log 2>&1 & < /dev/null;
            echo "run [OK]"
          else
            echo "already running pid=$pid ..."
          fi
        ];          
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "stop" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep sparrowci_web.raku|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "already stopped"
          else
            echo "kill $pid ..."
            kill $pid
            echo "stop [OK]"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
      } elsif $action eq "conf" {
        if $base {
          $c<sparrowci><base> = $base;
          _update_conf($c);
        }
      } elsif $action eq "status" {
        my $cmd = q[
          set -e
          pid=$(ps uax|grep sparrowci_web.raku|grep rakudo|grep -v grep | awk '{ print $2 }')
          if test -z $pid; then
            echo "stop [OK]"
          else
            echo "run [OK]"
          fi
        ];
        say $cmd if $verbose;
        shell $cmd;
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
