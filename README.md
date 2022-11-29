# SparrowCI

SparrowCI - super fun and flexible CI system with many programming languages support.

# Why yet another pipeline DSL?

Read [why?](why.md) manifest

# Quick Start

## Create SparrowCI pipeline 

Create a build scenario `sparrow.yaml`:

```yaml
- 
  tasks:
    -
      name: main_task
      language: Python
      default: true
      code: |
        print("hello from Python")
      depends:
        - 
          name: install-python
    -
      name: install-python
      language: Bash
      code: |
       sudo apk apk add --no-cache python3 py3-pip    
```

In this simple example task "main_task" executes some Python code. To make it sure we have a Python in runtime, 
dependency task "install-python" is executed. 

That's simple!

This example illustrates the core idea behind SparrowCI pipeline - to have a **collection of dependent tasks** (DAG) that executed in **particular order**.

To automatically trigger builds add pipeline source to a git repo:

```bash
git add sparrow.yaml
git commit -a -m "SparrowCI pipeline"
git push
```

## Add git repository to SparrowCI

* Go to [https://ci.sparrowhub.io](https://ci.sparrowhub.io), sign in using your GitHub credentials

* Go to "My Repos" page and add a repository to your repository list

## Trigger a build

That is it. A build will be triggered soon!

# Advanced topics

Consider more sophisticated example:

```yaml
tasks:
  -
    name: make_file
    language: Bash
    code: |
      set -x
      mkdir -p foo/bar
      echo "we have" > foo/bar/file.txt
      echo "some data here" >> foo/bar/file.txt
    artifacts:
      out:
        -
          name: file.txt
          path: foo/bar/file.txt
  - 
    name: parser
    language: Ruby
    default: true
    depends:
      -
        name: make_file
    code: |
      File.readlines('.artifacts/file.txt').each do |line|
        puts(line)
      end
    artifacts:
      in:
        - file.txt 
```

## Default task

SparrowCI pipeline should have one task, marked as default ( `default: true` flag ), scenario starts execution from the default task.

## Artifacts

Tasks might produce artifacts that become visible within other tasks.

In this example, `parser` task would wait till `make_file` is executed and produce artifact
for file located at `foo/bar/file.txt`, the artifact will be registered and copied into 
the central SparrowCI system with  unique name `file.txt`.

The artifact then will be ready to be consumed for other tasks. The local file
representing consumed artifact will be located at `.artifacts` folder.

## Sparrow plugins

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

## Tasks

Tasks are elementary build units. They could be written on various languages
or executed as external Sparrow plugins.

Every task is executed in a separated environment and does not see other tasks.

Artifacts and tasks output data is mechanism how tasks communicate with each other.

## Workers

Workers execute tasks.

SparrowCI workers are ephemeral docker instances, that are created
for every build and then destroyed

## Docker images

By default pipeline runs on Alpine docker image. 

One can choose different Linux distributions.

For example, Debian:

```yaml
image:
  - melezhik/sparrow:debian
```

Use following table to find proper docker image

| OS          | Image                        |
| ------------| ---------------------------- |
| Alpine      | melezhik/sparrow:alpine      |
| Debian      | melezhik/sparrow:debian      |
| Ubuntu      | melezhik/sparrow:ubuntu      |
| Arch Linux  | melezhik/sparrow:archlinux   |

To run on many images:

```yaml
image:
  - melezhik/sparrow:alpine
  - melezhik/sparrow:debian
  - melezhik/sparrow:archlinux
```

More Linux distributions will be supported in a future.

To handle different OS within Pipeline use `$os` variable:

```yaml
name: install-python
language: Bash
code: |
  if test $os = "alpine"; then
    sudo apk add py3-pip
  elif test $os = "debian"; then
    sudo apt-get install -y python3-pip
  fi
```

In all none Bash languages use `os()` function:

```yaml
name: install-deps
default: True
language: Python
code: |
  if os() == "alpine":
    print("Hello Alpine")
```

See also - https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md#recognizable-os-list

## Parallel tasks execution

(TBD)

Tasks could be executed on parallel workers simultaneously for efficiency.

## Dependencies

Tasks dependencies are implemented via `depends`/`followup` tasks lists.

`depends`/`followup` sections allows to execute tasks before/after a main task.

`depends`/`followup` tasks are executed in no particular order and _potentially_ on separated hosts.

Here are some examples:

```yaml
tasks:
  -
    language: Ruby
    name: ruby_task
    code: |
      update_state(Hash["message", "I code in Ruby"])
  -
    name: raku_task
    language: Raku
    default: true
    depends: 
      - 
        name: ruby_task
    code: |
      say "ruby_task says: {config()<tasks><ruby_task><state><message>}"
    check: |
      ruby_task says: I code in Ruby
```

Dependencies could be nested, when a dependency has other dependency, so on:

```yaml
tasks:
  -
    name: task_0
    language: Bash
    code: |
      echo "task 0" 
  -
    name: task_A
    language: Bash
    code: |
      echo "task A" 
    depends:
    -
      name: task_0
  -
    name: task_B
    language: Bash
    default: true
    code: |
      echo "task B"
    depends:
    -
      name: task_A
```

## Handling tasks statuses

If any task fail the entire scenario will terminate at that point.

It's possible to handle task statuses using `ignore_error()` function and task
output data:

```yaml
tasks:
  -
    name: main_task
    default: true
    language: Raku
    init: |
      ignore_error()
    code: |
      die "I don't feel well";
      update_state %( status => "OK" )
    followup:
      -
        name: error_handler
  -
    name: error_handler
    language: Python
    code: |
      if 'status' not in config()['parent'] or config()['parent']['status'] != "OK":
        print("handling main task errors ...")
    
```

## Subtasks

Subtasks allows to split a big task on small pieces (sub tasks) and
call them as functions:

```yaml
tasks:
  -
    name: app_test
    language: Raku
    default: true
    config:
      sites:
        - http://raku.org
        - https://raku.org
        - https://sparrowhub.io
    init: |
      for config()<sites><> -> $url {
        run_task "http_check", %(
          url => $url
        )
      }
    subtasks:
      -
        name: http_check
        language: Bash
        code: |
          echo "check site:" $url
          curl -fs $url | head
    code: |
      say "finshed"
```

The same example could be implemented by Python as well:

```yaml
tasks:
  -
    name: app_test
    language: Python
    default: true
    config:
      sites:
        - https://www.python.org
        - https://python-poetry.org
        - https://pypi.org/project/pip/
    init: |
      for url in config()['sites']:
        run_task(
          "http_check",
          { "url": url }
        )
    subtasks:
      -
        name: http_check
        language: Bash
        code: |
          echo "check site:" $url
          curl -fs $url -D - -o /dev/null | head
    code: |
      print("finshed")
```

To access sub tasks parameters in none Bash languages use `task_var()` function:

```yaml
tasks:
  -
    name: task_main
    language: Python
    default: true
    init: |
      run_task("subtask_1",{ "param": "OK" } )
    subtasks:
      -
        name: subtask_1
        language: Python
        code: |
          print(f"param passed: {task_var('param')}")

```

Subtasks could be nested, when one subtask calls another substask, etc. :

```yaml
tasks:
  -
    name: main
    language: Bash
    default: true
    init: |
      run_task "task1"
    subtasks:
      -
        name: task1
        language: Bash
        init: |
          run_task "task2"
        code: |
          echo "task1"
      -
        name: task2
        language: Bash
        code: |
          echo "task2"
    code: |
      echo "finshed"
```

In this example task "main" would call task "task1" first which in turn call task "task2", and 
resulted output would be:

```
task2
task1
finished
```

Read more about tasks at https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md#subtasks

## Init blocks

Init blocks allow to write some task initialization code that will be executed
before main task code (defined at `code` section).

The main purpose of init blocks is to run subtasks, however any code could be used within init block:

```yaml
tasks:
  -
    name: main
    language: Python
    default: true
    init: |
      print("some initialization code")
    code: |
      print("main code")
```
Special functions - `set_stdout` and `ignore_error` could be used within init blocks to alter
a task logic:

```yaml
tasks:
  -
    name: main
    language: Python
    default: true
    init: |
      ignore_error()
    code: |
      raise RuntimeError('something goes wrong') 
```

`ignore_error()` function will ignore task failure and execution flow will continue

Read more about `ignore_error()` function at https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md#ignore-task-failures

```yaml
tasks:
  -
    name: main
    language: Python
    default: true
    init: |
      set_stdout("hello from init")
    code: |
      print("hello from main code")
```

`set_stdout()` function will send some output to task STDOUT so it'll become visible together
with main code output, the example above would give this result:

```
hello from init
hello from output
```

Read more about `set_stdout` function on https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md#set-hook-output

## Using Programming Languages 

Currently SparrowCI supports following list of programming languages:

- Raku
- Go (*)
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

(*) golang support is not yet fully implemented, for details visit this [page](go_support.md).

## Tasks parameters and configuration

Every task might have some default configuration:

```yaml
  name: bash_task
  language: Bash
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
          name: bash_task
          config:
            message: "How are you?"
```

This example will produce:

```
you've said: How are you?
```

## Tasks output data

Dependency task might produce output data that is available within _dependent_ tasks:

```yaml
  tasks:
    -
      language: Ruby
      name: ruby_task
      code: |
        update_state(Hash["message", "I code in Ruby"])
    -
      name: raku_task
      language: Raku
      default: true
      depends: 
        - 
          name: ruby_task
      code: |
        say "Hello from Raku";
        my $ruby_task_message = config()<tasks><ruby_task><state><message>;
```

Use `update_state()` function to register task output data.

The function accepts HashMap as a parameter and available for all programming languages, excepts Bash.

Use `config()` function to access dependency task data from dependent task.

If the same dependency task is executed more than once, use local name parameter
to distinguish output data from different runs:

```yaml
  tasks:
    -
      name: parser
      language: Ruby
      default: true
      name: ruby_task
      code: |
        rand_string = (0...8).map { (65 + rand(26)).chr }.join
        update_state(Hash["random_message", rand_string])
    -
      name: raku_task
      language: Python
      default: true
      depends: 
        - 
          name: python_task
          localname: ruby_task1
        - 
          name: ruby_task
          localname: ruby_task2
      code: |
        print("Hello from Python")
        ruby_task1_message = config()['tasks']['state']['ruby_task1']['random_message'];
        ruby_task2_message = config()['tasks']['state']['ruby_task2']['random_message'];
```

Output data works the same way for `followup` tasks, to access _parent_ task data
from followup task use `parent` (instead of `tasks`) key:

```yaml
tasks:
  -
    name: task_main
    default: true
    language: Perl
    code: |
      update_state({ message => "hello from Perl"})
    followup:
    -
      name: followup_task
  -
    name: followup_task
    language: Python
    code: |
      print(f"task_main says: {config()['parent']['state']['message']}")
    check: |
      task_main says: hello from Perl
```

## Plugins parameters and output data

Plugins have default and input parameters, as well as states (output data).

## Tasks checks

Task checks allow to create rules to verify scripts output, it useful when creating
Bash scripts in quick and dirty way, where there is no convenient way to validate scripts logic:

```yaml
tasks:
  -
    name: create-database
    language: Bash
    code: |
      mysql -c "create database foo" -h 127.0.0.1 2>&1
    check: |
      regexp: database .* exists | created   
```

Check rules are based on Raku regular expression, follow this link - https://github.com/melezhik/Sparrow6/blob/master/documentation/taskchecks.md
to know more.

Here is another example with Python, which
checks that strings ("hello from Python" and "you passed foo: bar")
follow each other.

```yaml
tasks:
  -
    name: example_task
    language: Python
    default: true
    config:
      foo: bar
    code: |
      print("Hello from Python")
      print(f"you passed foo: {config()['foo']}")
    check: |
      being:
        Hello from Python
        you passed foo: bar
      end:
```

## Source code and triggering

Build triggering happens automatically upon any changes in a source code.

The source code is checked out into `./source` local folder.

Here is an example of building Raku project from the source:

```yaml
tasks:
  -
    name: zef-build
    language: Bash
    default: true
    code: |
      set -e
      cd source/
      zef install --deps-only --/test .
      zef test .
```

## Secrets management

WARNING! This feature is still being tested, although security is address 
seriously (*) in SparrowCI service,  don't use SparrowCI secrets to store your credit card
information and other valuable data. You've been warned )))

To use secrets n SparrowCI pipeline:

1. Create secret using secret manager in https://ci.sparrowhub.io 

2. Reference secrets by names in a pipeline:

```yaml
secrets:
  - MY_SECRET
```

(*) Secrets are encrypted at rest and kept in secure backend storage. 
Secrets are never exposed in the internet and only available for
internal docker containers when you reference them in pipeline.
This is users responsibility not to dump secrets in pipeline reports.

3. Use secrets as environment variables withing pipeline tasks:

```yaml
name: dump
language: Bash
code: |
  echo "Now I am telling you ${MY_SECRET} ..."
```

## Followup jobs

Sometimes one needs to run some followup jobs _after_ main jobs defined at `sparrow.yaml`
are _successfully_ finished.

To do so create another SparrowCI pipeline located at `.sparrow/folloup.yaml` path:

```yaml
image:
  - melezhik/sparrow:debian

tasks:
  -
    language: Bash
    name: main
    default: true
    code: |
      echo hello from followup job
```

Typical use case for followup jobs when once has a "basic" CI test defined at `sparrow.yaml`
root file and they want to publish a package after such a test succeeds. So they place
publishing logic into a followup job pipeline `.sparrow/followup.yaml`.

# Examples

Here is just short list of some possible scenarios.

## Make build

```yaml
  tasks:
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

```yaml
tasks:
  -
   name: install-python
   plugin: sparkyci-package-python
  -
   name: install-deps
   language: Bash
   code: |
      set -e
      cd source
      pip install -e .[develop]
   depends:
    -
      name: install-python
  - 
   name: unit-tests
   default: true
   language: Bash
   code: |
      set -e
      cd source
      pytest
   depends:
    -
      name: install-deps
```

## Raku build

```yaml
tasks:
  -
    name: zef-build
    language: Bash
    default: true
    code: |
      set -e
      rm -rf source/
      git clone $(config url) source
      cd source/
      zef install --deps-only --/test .
      zef test .
    config:
      url: https://github.com/lizmat/App-Rak.git
```

## Golang build

```yaml
tasks:
 - 
  name: unit_test
  language: Bash
  code: |
    set -e
    go version
    cd source 
    make test COVERAGE_DIR=/tmp/coverage
  default: true
  depends:
    -
      name: install-go
 -
    name: install-go
    language: Bash
    code: sudo apk add go
```

## Ruby build

```yaml
tasks:
  -
    name: rake_task
    language: Bash
    default: true
    code: |
      set -e
      cd source
      bundle install
      bundle exec rake
    default: true
    depends:
      - 
        name: install-ruby
  -
    name: install-ruby
    language: Bash
    code: |
      sudo apk add ruby-dev ruby-bundler ruby-rake zlib
```

## Another examples

Other examples could be found at [examples](examples) folder

# Development

See [development.md](development.md) document.

# Thanks to

God and Jesus Christ who inspires me
