# Sparman

Spartman is a cli to easy SparrowCI management

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

To pass environmental variables to services, use `--env var=val --env var2=val ...` notation.

For example, to set worker polling timeout to 10 seconds:

```bash
sparman.raku --env SPARKY_TIMEOUT=10 worker start
```
