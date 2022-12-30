# Development

How to run SparrowCI pipelines locally. Useful for SparrowCI developers.

1. First install SparrowCI as a self-hosted service, please see [selfhosted.md](docs/selfhosted.md)

2. Now you can run pipeline locally from the machine where SparrowCI is hosted

Pull _some_ docker image:

```bash
docker pull melezhik:alpine
```

Now run the pipeline:

```bash
sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--tags tasks_config=$PWD/examples/go/make.yaml,\
scm=https://git.sr.ht/~craftyguy/superd\,
image=melezhik/sparrow:alpine \ 
--desc "build pipeline"
```

If you an image where Sparrow agent is not installed use `sparrowdo_bootstrap` tag:

```
--tags=sparrowdo_bootstrap=on
```

3. Watch reports

*  For Sparky workers reports, visit Sparky web UI - http://127.0.0.1:4000

* For SparrowCI reports ( for low level troubleshooting ), visit SparrowCI web UI - http://127.0.0.1:2222
