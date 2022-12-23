sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--tags scm=https://github.com/melezhik/sparrowci-sandbox.git,\
sparrowdo_bootstrap=off,\
tasks_config=$PWD/examples/bash/task.yaml \
--desc "sparrowci test"
