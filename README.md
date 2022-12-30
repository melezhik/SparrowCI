# SparrowCI

SparrowCI - super fun and flexible CI system with many programming languages support.

# Why yet another pipeline DSL?

Read [why?](docs/why.md) manifest

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

## Deep dive

See [dsl.md](dsl.md) document for full SparrowCI DSL tutorial.

# Other topics

## Environment variables

See [variables.md](docs/variables.md) document.

## Self-hosted deployment

See [selfhosted.md](docs/selfhosted.md) document.

## Development

See [development.md](docs/development.md) document.

## External systems integration

See [reporters.md](docs/reporters.md) document.

# Thanks to

God and Jesus Christ who inspires me
