unit module SparkyCI::Security;
use SparkyCI::Conf;
use JSON::Fast;

sub gen-token is export {

  ("a".."z","A".."Z",0..9).flat.roll(8).join

}

sub check-user (Mu $user, Mu $token) is export {

  return False unless $user;

  return False unless $token;

  if "{cache-root()}/users/{$user}/tokens/{$token}".IO ~ :f {
    #say "user $user, token - $token - validation passed";
    return True
  } else {
    say "user $user, token - $token - validation failed";
    return False
  }

}

sub access-token (Mu $user) is export {
  from-json("{cache-root()}/users/{$user}/meta.json".IO.slurp)<access_token>;
}