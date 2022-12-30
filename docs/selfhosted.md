# Self-hosted

SparrowCI self-hosted installation

## Install

* Install docker

You need to install docker on the same machine where Sparky and SparrowCI are installed.

* Install and run Sparky

You need to install Sparky on the same machine where SparrowCI is installed.

Sparky API must listen to http://127.0.0.1:4000 address

Follow [https://github.com/melezhik/sparky#installation](https://github.com/melezhik/sparky#installation)
for installation details.

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

* Run SparrowCI web app

```bash
cro run
```

SparrowCI API will be accessible on http://127.0.0.1:2222 , use `admin` as a login
and `passW0rd` as a password. 

Please change the password after the first successful login.
