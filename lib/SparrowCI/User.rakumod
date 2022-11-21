unit module SparrowCI::User;
use SparrowCI::Conf;
use SparrowCI::Security;
use Cro::HTTP::Client;
use JSON::Fast;

sub gh-repos (Mu $user) is export {

    unless "{cache-root()}/users/{$user}/repos.js".IO ~~ :e {
        sync-repos($user)
    }

    my @list = from-json("{cache-root()}/users/{$user}/repos.js".IO.slurp);

    #die @list.List.flat.perl;

    return @list.List.flat;

}

sub repos-sync-date (Mu $user) is export {
    "{cache-root()}/users/{$user}/repos.js".IO.modified.DateTime.truncated-to('minute');
}

sub sync-repos (Mu $user) is export {

    say "fetch user repos: https://api.github.com/users/$user/repos";

    my %q = %( per_page => 100, sort => "updated" );

    #say %q.perl;

    my $resp = await Cro::HTTP::Client.get: "https://api.github.com/users/$user/repos",
        query => %q,
        headers => [
            Authorization => "token {access-token($user)}"
        ];

    my $data = await $resp.body-text();

    my @list = from-json($data);

    "{cache-root()}/users/{$user}/repos.js".IO.spurt(to-json(@list));

    return @list;

}

sub projects (Mu $user) is export {
    my @list;
    for dir "{%*ENV<HOME>}/.sparky/projects/" -> $i {
        if $i.IO ~~ :d and $i ~~ /"gh-" $user "-" (\S+)/ {
            push @list, { repo => "{$0}", type => 'gh', type-human => "github", project => $i.IO.basename } 
        } elsif $i.IO ~~ :d  and $i ~~ /"git-" $user "-" (\S+)/ {
            push @list, {  repo => "{$0}" , type => 'git', type-human => "git", project => $i.IO.basename  }
        }
    }
    return @list.sort({ .<repo> || .<type> });
}

sub secrets (Mu $user) is export {
    my @list;
    if "{cache-root()}/users/{$user}/secrets/".IO ~~ :d {
        for dir "{cache-root()}/users/{$user}/secrets/" -> $s {
            if $s.IO ~~ :f {
                @list.push: %(
                    name => $s.IO.basename,
                    date => $s.IO.modified.Date,
                    date_hr => DateTime.new(
                        $s.IO.modified, 
                        formatter => sub ($self) { 
                            sprintf "%02d-%02d-%04d %02d:%02d", 
                            .month, .day, .year, .hour, .minute  
                            given $self; 
                        }
                    ),
                    datetime => $s.IO.modified.DateTime    
                )
            }    
        }
    }
    @list.sort({$^a<datetime> cmp $^b<datetime> });
}

sub secret-add (Mu $user,$secret,$secret_value) is export {
    mkdir "{cache-root()}/users/{$user}/secrets/";
    "{cache-root()}/users/{$user}/secrets/{$secret}".IO.spurt("");
    my $cmd = "vault write /kv/sparrow/users/{$user}/secrets {$secret}={$secret_value}";
    shell("if vault -version; then {$cmd}; else echo 'vault is not installed, nothing to do'; fi");
}

sub secret-delete (Mu $user,$secret) is export {
    if "{cache-root()}/users/{$user}/secrets/{$secret}".IO ~~ :e {
        unlink("{cache-root()}/users/{$user}/secrets/{$secret}");
    }
    my $cmd = "vault delete /kv/sparrow/users/{$user}/secrets/{$secret}";
    shell("if vault -version; then {$cmd}; else echo 'vault is not installed, nothing to do'; fi");
}
