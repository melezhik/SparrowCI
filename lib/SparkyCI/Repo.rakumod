unit module SparkyCI::Repo;
use YAMLish;

sub get-repo (Mu $user,$repo-id,$type) is export {
    return unless "{%*ENV<HOME>}/.sparky/projects/{$type}-{$user}-{$repo-id}/sparky.yaml".IO ~~ :f;    
    load-yaml("{%*ENV<HOME>}/.sparky/projects/{$type}-{$user}-{$repo-id}/sparky.yaml".IO.slurp)
}
