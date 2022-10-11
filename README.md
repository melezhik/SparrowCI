# SparrowCI

SparrowCI - superfun and flexible CI system with
many programming languages support.

# Howto

Install SparrowCI

```
apk add sparrowci
```

Create build scenario:

```yaml
  tasks:
    -
      name: make_task
      language: bash
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
      language: raku
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
        say "hello from Raku"
        update_state %( message => "OK" )
    -
      name: python_task
      language: python
      config:
        foo: bar # default value
      code: |
        from sparrow6lib import *
        state = config()['state']['raku']
        print("hello from Python")
        print(f"I can read output data from other tasks: {state['message']}")
        print(f"named parameter: {config()['foo']}")
```

This example scenario would execute Bash task and Python task and then 
execute Raku task. Task dependencies are just DAG and ensured by `before`
sections.

