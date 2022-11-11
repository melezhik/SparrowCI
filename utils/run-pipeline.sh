sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--tags scm=https://github.com/tbrowder/CSV-AutoClass.git,\
sparrowdo_bootstrap=off,\
tasks_config=$PWD/examples/go/task.yaml \
--desc "sparrowci test"
