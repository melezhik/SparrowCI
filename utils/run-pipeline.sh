sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--tags scm=https://git.sr.ht/~craftyguy/superd,\
sparrowdo_bootstrap=off,\
tasks_config=$PWD/examples/bash/task.yaml \
--desc "build 123"
