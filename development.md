# SparrowCI Pipelines Development

How to run pipelines locally

## Install

* Install docker

* Install and run Sparky

## Run pipeline

1. Pull docker image

This could be any of [Sparrow supported Linux distro](https://github.com/melezhik/sparrowdo/blob/master/resources/bootstrap.sh) docker images.

For example One can choose alpine linux docker image with bootstrapped Sparrow:

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

If an image does not have a Sparrow installed, one can
bootstrap it during pipeline execution by using `sparrowdo_bootstrap` tag:

```
--tags=sparrowdo_bootstrap=on
```

