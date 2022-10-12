# SparrowCI

SparrowCI - super fun and flexible CI system with many programming languages support.

# Quick Start

Install SparrowCI

```bash
# choose any convenient package manager: 
sudo apk add sparrowci
sudo apt-get install sparrowci
sudo yum install sparrowci
```

Create build scenario `sparrow.yaml`:

```yaml
  tasks:
    -
      name: make_task
      language: Bash
      config:
        prefix: ~/
        with_test: false
      code: |
        prefix=$(config prefix)
        make
        if test $(config with_test) = "true"; then
          make test
        fi
        sudo make install --prefix=$prefix
        echo "Hello from Bash"
    -
      name: raku_task
      language: Raku
      default: true # start scenario with that task
      depends: 
        - 
          name: make_task
          config:
            with_test: true
      cleanup:
        - 
            name: python_task
            config:
              foo: baz
      code: |
        say "Hello from Raku";
        update_state %( message => "OK" );
    -
      name: python_task
      language: Python
      config:
        foo: bar # default value
      code: |
        from sparrow6lib import *
        state = config()['tasks']['raku_task']
        print("Hello from Python")
        print(f"I can read output data from other tasks: {state['message']}")
        print(f"named parameter: {config()['foo']}")
```

This example scenario would execute Bash task and Python task and then 
execute Raku task. Task dependencies are just DAG and ensured by `depends`/`cleanup`
sections. Task is marked as `default: true` is executed by first when a 
scenario gets triggered.

To execute scenario add it to your git repo and assign tasks to SparrowCI service:


```bash
git add sparrow.yaml
git commit -a -m "my sparrowci scenario"
git push

sparrow_ci login # login into SparrowCI account 
sparrow_ci register # register your git project, this will trigger a new build soon

```

# Advanced topics

Consider more sophisticated example:

```yaml
  tasks:
    -
      name: make_file
      language: Bash
      code: |
        mkdir -p foo/bar
        touch foo/bar/file.txt
      artifacts:
        out:
          -
            name: file.txt
            path: foo/bar/file.txt
    - name: parser
      language: Ruby
      default: true
      depends:
      -
        name: make_file
      code:
        File.readlines('.artifacts/file.txt').each do |line|
          puts(line)
        end
      artifacts:
        in:
          - file.txt 
```

## Artifacts

In this example, `parser` task would wait till `make_file` is executed and produce artifact
for file located at `foo/bar/file.txt`, the artifact will be registered and copied into 
the central SparrowCI system with  unique name `file.txt`.

The artifact then  will be ready to be consumed for other tasks. The local file
representing consumed artifact will be located at `.artifacts` folder.

## Sparrow Plugins

Sparrow plugins are reusable tasks one can run from within their scenarios:

```yaml
  tasks:
    -
      name: dpl_check
      plugin: k8s-deployment-check
        config:
          name: animals
          namespace:  pets
          image:  blackcat:1.0.0
          command: /usr/bin/cat
          args:
            - eat
            - milk
            - fish
          env:
            - ENABLE_LOGGING
          volume-mounts:
            foo-bar: /opt/foo/bar

```

In this example plugin "k8s-deployment-check" checks k8s deployment resource.

Available plugins are listed on SparrowHub repository - https://sparrowhub.io

## Artifacts

Tasks might produce artifacts that become visible within other tasks:

## Workers

SparrowCI workers are ephemeral docker alpine instances, that are created
for every build and then destroyed. If you need more OS support please
let me know.

Every task is executed in separated environments and does not see other tasks.

Artifacts and tasks output data is mechanism how tasks communicate with each other.

## Parallel tasks execution

Tasks could be executed on parallel workers simultaneously for efficiency.

Documentation - TDB

## Dependencies

Tasks dependencies are implemented via `depends`/`cleanup` tasks lists.

`depends`/`cleanup` sections allows to execute tasks before/after a given one.

`cleanup` tasks executed unconditional on main tasks status (success/failure).

if any of  `depends` tasks fail the main, dependent task is not executed and the whole
scenario terminated.

`depends`/`cleanup` tasks are executed in no particular order and 
_potentially_ on separated hosts.


## Subtasks

Subtasks allows to split a big task on small pieces (sub tasks) and
call them as functions:

```yaml
- tasks:
  -
    name: app_test
    language: Raku
    main: |
      for ('http://raku.org', 'https://raku.org') -> $url {
        run_task http_check, %(
          url => $url
        )
      }
    subtasks:
      -
        name http_check
        language: Bash
        code: |
          curl -f $url
    code: |
      say "finshed"
```

## Using Programming Languages 

Currently SparrowCI supports following list of programming languages:

- Raku
- Bash
- Python
- Perl
- Ruby
- Powershell

To chose a language for underling task just use `language: $language` statement:

```yaml
  name: powershell_task
  language: Powershell
  code: |
    Write-Host "Hello from Powershell"
```

## Tasks parameters and configuration

Every task might have some default configuration:

```yaml
  name: pwsh_task
  language: Powershell
  config:
    message: Hello
  code: |
    echo "you've said:" $(config message)
```

Default configuration parameters could be overridden by tasks parameters:

```yaml
  tasks:
    -
      name: main_task
      language: Bash
      default: true
      depends: 
        - 
          name: pwsh_task
          config:
            message: "How are you?"
```

## Task output data

Task might have output data that is later becomes available
within other tasks:

```yaml
  tasks:
    -
      name: parser
      language: Ruby
      default: true
      name: ruby_task
      code: |
        update_state(Hash["message", "I code in Ruby"])

```

`update_state()` function accepts HashMap as parameter and available for all programming languages, excepts Bash.

Other tasks would use `config()` function to access tasks output data:


```yaml
  tasks:
    -
      name: raku_task
      language: Raku
      default: true # start scenario with that task
      depends: 
        - 
          name: ruby_task
      code: |
        say "Hello from Raku";
        my $ruby_task_message = config()<tasks><ruby_task><message>;
```

## Plugins parameters and output data

Plugins have default and input parameters, as well as states (output data).

# Examples

Here is just short list of some possible scenarios.

## Make build

```yaml
  tasks:
    -
      name: checkout
      language: Bash
    -  
      name: build
      language: Bash
      default: true
      config:
        url: https://github.com/rakudo/rakudo.git
      code: |
        set -e
        git clone $(config url) scm
        cd scm
        perl Configure.pl --gen-moar --gen-nqp --backends=moar
        make
        make install
```

## Python build

TDB

## Raku build

TBD

## Golang build

TBD


