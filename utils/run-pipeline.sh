sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--tags scm=https://git.sr.ht/~craftyguy/superd,\
tasks_config=$PWD/examples/bash/nested-deps.yaml,\
docker_bootstrap=off,\
sparrowdo_bootstrap=off \
--desc "build 123"
