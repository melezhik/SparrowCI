# SparrowCI

SparrowCI - super fun and flexible CI system with many programming languages support.

# Quick Start

## Install SparrowCI

```bash
# choose any convenient package manager: 
sudo apk add sparrowci
sudo apt-get install sparrowci
sudo yum install sparrowci
```

## Create Sparrow pipeline 

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
      followup:
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
        state = config()['tasks']['raku_task']['state']
        print("Hello from Python")
        
        print(f"I can read output data from other tasks: {state['message']}")
        print(f"named parameter: {config()['foo']}")
```

This example scenario would execute Bash task as a _dependency_ for Raku task, the Raku task and then 
execute _followup_ Python task.

Task that is marked as `default: true` is entry point for scenario,
where flows starts.

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

(TBD)

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

Every task is executed in separated environment and does not see other tasks.

Artifacts and tasks output data is mechanism how tasks communicate with each other.

## Workers

Workers execute tasks.

SparrowCI workers are ephemeral docker alpine instances, that are created
for every build and then destroyed. If you need more OS support please
let me know.

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

# Handling tasks statuses

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

Read more about `ignore_error()` function on https://github.com/melezhik/Sparrow6/blob/master/documentation/development.md#ignore-task-failures

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

(TBD)

Build triggering happens automatically upon any changes in a source code.

The source code is checked out into `./source` local folder.

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
    name: install_python
    # install Python dependencies
    plugin: sparkyci-package-python
  - 
    name: unit tests
    language: Bash
    default: true
    depends:
      -
        name: install_python
    code: |
      set -e
      cd source/
      sudo pip3 install -r requirements.txt
      pytest
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

TBD

## Another examples

Other examples could be found at [files/examples](files/examples) folder

# Development

1. Install Sparky

2. Setup config.pl6 

Edit config.pl6 file changing `$example-path` variables:

```raku
my $example-path = "files/examples/raku/zef.yaml";
```

3. Run

Then run from command line:

```bash
sparrowdo \
--color \
--localhost \
--no_sudo \
--with_sparky \
--sparrowfile ci.raku \
--desc "sparrowci zef build"
```

# Thanks to

God and Jesus Christ who inspires me
