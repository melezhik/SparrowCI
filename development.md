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
## On docker

1. Run docker

```bash
docker run -rm --name alpine \
--add-host=host.docker.internal:host-gateway \
--env STORAGE_API=host.docker.internal:host-gateway:4000 \
--env NOTIFY_API=host.docker.internal:host-gateway:4000  \
-itd alpine
```

2. Runs pipeline

```bash
sparrowdo --bootstrap  \
--color \
--docker alpine \
--no_sudo --with_sparky \
--sparrowfile ci.raku \
--tags tasks_config=$PWD/examples/go/make.yaml,\
scm=https://git.sr.ht/~craftyguy/superd \
--desc "build pipeline"
```
