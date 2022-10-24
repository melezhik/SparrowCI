# SparrowCI Pipelines Development

Run pipelines locally

## On localhost

1. Run pipeline

```bash
sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--tags tasks_config=$PWD/examples/go/make.yaml,\
scm=https://git.sr.ht/~craftyguy/superd \
--desc "build pipeline"
```
