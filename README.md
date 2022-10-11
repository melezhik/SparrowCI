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
  app:
    -
      name: make
      language: bash
      config:
        prefix: ~/
      code: |
        prefix=$(config prefix)
        make
        make test
        sudo make install --prefix=$prefix
        echo "hello from Bash"
    -
      name: raku
      language: raku
      before: 
        - 
          name: make
      code: |
        say "hello from Raku"
        update_state %( status => "OK" )
    -
      name: python
      language: python
      config:
        foo: bar
      before: 
        - 
          name: raku
      code: |
        from sparrow6lib import *
        state = config()['state']['raku']
        print("hello from Python")
        print(f"named parameter: {config()['foo']}")
```

This example scenario would execute Bash task, then Raku task
and then finally Python task. Task dependencies are ensured by `before`
section.

