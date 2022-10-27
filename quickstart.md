# Quick Start

SparrowCI quick start

## Create pipeline 

Just create a file `sparrow.yaml` in your repository root folder:

```yaml
tasks:
    name: unit_tests
    language: Bash
    default: true
    code: |
      set -e
      cd source/
      sudo pip3 install -r requirements.txt
      pytest
```

This simple code snippet represents a minimalist CICD for python 
project.

Commit `sparrow.yaml` and push changes to Git:

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

# Examples

See more examples at [SparrowCI examples](https://github.com/melezhik/SparrowCI/tree/main/examples)

or read documentation to get in depth understanding of SparrowCI pipelines.


# Documentation

Follow [https://github.com/melezhik/SparrowCI](https://github.com/melezhik/SparrowCI)

# Author

Alexey Melezhik

