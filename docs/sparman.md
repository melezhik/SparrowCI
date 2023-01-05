# Sparman

Spartman is a cli to ease SparrowCI management

# API

## Sparky Worker

Sparky worker is a background process performing all SparrowCI tasks execution

```bash
sparman.raku worker start
sparman.raku worker stop
sparman.raku worker status
```

## Sparky Worker UI

Sparky worker UI allows to read worker reports and manage worker jobs. This
is intended for SparrowCI operations people

```bash
sparman.raku worker_ui start
sparman.raku worker_ui stop
sparman.raku worker_ui status
```

## SparrowCI UI

SparrowCI UI is a end-user SparrowCI interface

```bash
sparman.raku ui start
sparman.raku ui stop
sparman.raku ui status
```
## Pass environment variables

To pass environmental variables to services, use `--env var=val,var2=val ...` notation.

For example, to set worker polling timeout to 10 seconds and set SPARROWCI_HOST:

```bash
sparman.raku --env SPARKY_TIMEOUT=10,SPARRWOCI_HOST=http://127.0.0.1:2222 worker start
```

## Logs

Logs are available at the following locations:

SparrowCI UI - `~/.sparrowci/sparrowci_web.log`

Sparky Woker UI - `~/.sparky/sparky-web.log`

Sparky Woker - `~/.sparky/sparkyd.log `

# See also

* Self-hosted deployment - [selfhosted.md](selfhosted.md)
