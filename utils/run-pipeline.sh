sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--tags scm=https://github.com/melezhik/Sparrow6.git,\
sparrowdo_bootstrap=off,\
tasks_config=$PWD/examples/raku/sparrow.yaml \
--desc "build 123"
