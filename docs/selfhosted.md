# Self-hosted

SparrowCI self-hosted installation

## Install

* Install docker

You need to install docker on the same machine where Sparky and SparrowCI are installed.

* Install Sparky and initialize Sparky database

Follow [sparky#installation](https://github.com/melezhik/sparky#installation) document. 
Please don't run sparkyd and sparky-web services,
as they will be run later, see `Run SparrowCI stack`.

* Install SparrowCI web app

```bash
git clone https://github.com/melezhik/SparrowCI.git
cd SparrowCI
zef install . --/test
```

* Initialize SparrowCI DB

```bash
raku db-init.raku
```

* Setup SparrowCI configuration 

One has to choose _database_ login type.

```bash
cat << 'HERE' > ~/sparkyci.yaml
login_type: DB
HERE
```

# Run SparrowCI stack

Use spaman - cli application that comes with SparrowCI to run underlying SparrowCI components:

Run `sparkyd` - Sparrow jobs worker 

```bash
sparman.raku --env SPARROWCI_HOST=http://127.0.0.1:2222 worker start
```

Run `sparky-web` - worker UI (aka Sparky Web UI)

Sparky UI will be accessible on http://127.0.0.1:4000 , use `user` as a login and `password` as a password.

```bash
sparman.raku worker_ui start
```

Run SparrowCI UI

```bash
sparman.raku ui start
```

SparrowCI UI will be accessible on http://127.0.0.1:2222 , use `admin` as a login and `passW0rd` as a password.

Please, change the admin user password after the first successful login.

# See also

[sparman](sparman.md) - SparrowCI management tool
