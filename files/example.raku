tasks:
  -
    name: example_task
    language: Bash
    default: true
    config:
      foo: bar
    code: |
      prefix=$(config prefix)
      echo "Hello from Bash"
      echo "foo:" $(config foo)
