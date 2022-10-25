# SparrowCI Pipelines Development

How to run pipelines locally

## Install

Install and run Sparky

## Run pipeline

1. Start docker container

```bash
docker run \
--rm --name alpine \
--add-host=host.docker.internal:host-gateway \
-itd alpine
```

2. Run pipeline

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
