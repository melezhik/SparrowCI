unit module SparkyCI::User;
use SparkyCI::Conf;
use SparkyCI::Security;
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

