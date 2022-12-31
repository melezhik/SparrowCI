use IRC::Client;

my $channel = '#raku-sparrow';

class SparrowCIBot does IRC::Client::Plugin {
    method irc-connected ($) {
        react {
          whenever self!messages<> -> $m {
            say "handle message for bot: {$m.perl}";
            say "send message to irc channel: <{$channel}> ...";
            $.irc.send: :where($channel) :text($m<text>);
            say "unlink {$m<file>.path} ...";
            unlink $m<file>;
          }
        }
    }

    method !messages {
        supply {
            loop {
                for dir("{%*ENV<HOME>}/.sparrowci/irc/bot/messages/") -> $m {
                  my $msg = $m.IO.slurp;
                  if $msg {
                    my %meta = %( text => $msg, file => $m );
                    emit %meta;
                  }
                }
                exit(0);
            }
        }
    }
}

say %*ENV<LIBERA_SASL_PASSWORD>;

say "=====";

.run with IRC::Client.new:
    :port(5555)
    :ssl(True)
    :ca-file("/home/sph/.znc/znc.pem")
    :nick<sparrowbot>
    :username('admin/libera')
    :password(%*ENV<sparrowbot_password>)
    :host<127.0.0.1>
    :channels($channel)
    :debug
    :plugins(SparrowCIBot.new)
