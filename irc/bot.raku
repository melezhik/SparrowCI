use IRC::Client;

my $channel = '#raku-sparrow';

class SparrowCIBot does IRC::Client::Plugin {
    method irc-connected ($) {
        react {
          whenever self!messages<> -> $m {
            say "handle message for bot: {$m.perl}";
            my $text = "hello from sparrowbot";
            say "send message to irc channel: <{$channel}> ...";
            $.irc.send: :where($channel) :text($text);
            say "unlink {$m<file>.path} ...";
            unlink $m<file>;
          }
        }
    }

    method !messages {
        supply {
            loop {
                for dir("/tmp/foo2/") -> $m {
                  my %meta = %( text => "test bot", file => $m );
                  emit %meta;
                }
                #exit(0);
            }
        }
    }
}

say %*ENV<LIBERA_SASL_PASSWORD>;
say "=====";

.run with IRC::Client.new:
    #:userhost<mybf.io>
    :port(6697)
    :ssl(True)
    #:ca-file("./libera.pem")
    :nick<sparrowbot>
    :username<sparrowbot>
    :password(%*ENV<sparrowbot_password>)
    :host<irc.libera.chat>
    :channels($channel)
    :debug
    :plugins(SparrowCIBot.new)
