# SparrowCI

SparrowCI - superfun and flexible CI system with
many programming languages support.

# Quick Start

Install SparrowCI

```
apk add sparrowci
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
        echo "hello from Bash"
    -
      name: raku_task
      language: Raku
      main: true # start scenario with that task
      before: 
        - 
          name: make_task
          config:
            with_test: true
        - 
            name: python_task
            config:
              foo: baz
      code: |
        say "hello from Raku";
        update_state %( message => "OK" )
    -
      name: python_task
      language: Python
      config:
        foo: bar # default value
      code: |
        from sparrow6lib import *
        state = config()['tasks']['raku_task']
        print("hello from Python")
        print(f"I can read output data from other tasks: {state['message']}")
        print(f"named parameter: {config()['foo']}")
```

This example scenario would execute Bash task and Python task and then 
execute Raku task. Task dependencies are just DAG and ensured by `before`
sections. Task is marked as `default: true` is executed by default when
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
            name: foo.txt
            path: foo/bar/file.txt
    - name: parser
      language: ruby
      main: true
      before:
      -
        name: make_file
      code:
        File.readlines('.artifacts/foo.txt').each do |line|
          puts(line)
        end
      artifacts:
        in:
          - file.txt 
```

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

In this example plugin "k8s-deployment-check" to check k8s deployment resource.

Available plugins are listed on SparrowHub repository - https://sparrowhub.io


## Artifacts

Tasks might produce artifacts that become visible within other tasks:


## Workers

SparrowCI workers are ephemeral docker alpine instances, that are created
for every build and then destroyed. If you need more OS support please
let me know.

## Parallel tasks execution

Tasks could be executed on parallel workers simultaneously for efficiency.

Documentation - TDB
 

## Languages

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
  language: powershell
  code: |
    Write-Host "Hello from Powershell"
```

## Tasks parameters and configuration

Every task might have some default configuration:

```yaml
  name: bash_task
  language: powershell
  config:
    message: hello
  code: |
    echo "you've said:" $(config hello)
```

Default configuration parameters could be overridden by tasks parameters:

```yaml
  tasks:
    -
      name: main_task
      language: Bash
      main: true
      before: 
        - 
          name: bash_task
          config:
            message: "how are you?"
```

## Task output data

Task might have output data that is later becomes available
within other tasks:

```yaml
  tasks:
    -
      name: parser
      language: ruby
      main: true
      name: ruby_task
      code: |
        update_state(Hash["message", "I love Ruby"])

```

`update_state()` function accepts HashMap as parameter and available for all programming languages, excepts Bash.


Other tasks would use `config()` function to access tasks output data:


```yaml
  tasks:
    -
      name: raku_task
      language: Raku
      main: true # start scenario with that task
      before: 
        - 
          name: ruby_task
      code: |
        say "hello from Raku";
        my $ruby_task_message = config()<tasks><ruby_task><message>;
```


