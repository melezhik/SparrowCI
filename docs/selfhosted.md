# SparrowCI Pipelines Development

How to run pipelines locally

## Install

* Install docker

You need to install docker on the same machine where Sparky and SparrowCI are installed.

* Install and run Sparky

You need to install Sparky on the same machine where SparrowCI is installed.

Sparky API should be accessible on http://127.0.0.1:4000

See [https://github.com/melezhik/sparky#installation](https://github.com/melezhik/sparky#installation)

* Install SparrowCI web app

```bash
zef install . --/test
```

* Initialize SparrowCI DB

```bash
raku db-init.raku
```

* Setup SparrowCI configuration 

```bash
cat << 'HERE' > ~/.sparkyci.yaml
login_type: DB
HERE
```

* Run SparrowCI web app

```bash
cro run
```

SparrowCI API will be accessible on http://127.0.0.1:2222 , use `admin` as a login
and `passW0rd` as a password. 

Please change the password after the first successful login.

## Run pipeline

1. Pull docker image

This could be any of [Sparrow supported Linux distro](https://github.com/melezhik/sparrowdo/blob/master/resources/bootstrap.sh) docker images.

For example One can choose alpine linux docker image with bootstrapped Sparrow:

```bash
docker pull melezhik/sparrow:alpine
```


