# SparrowCI Pipelines Development

How to run pipelines locally

## Install

* Install docker

* Install and run Sparky

## Run pipeline

1. Pull docker image

```bash
docker pull melezhik/sparrow:alpine
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
scm=https://git.sr.ht/~craftyguy/superd\,
docker_image=melezhik/sparrow:alpine \ 
--desc "build pipeline"
```
