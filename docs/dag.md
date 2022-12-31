# DAG

Directed acycling graph of tasks explanation

## Create SparrowCI pipeline 

Consider this build scenario `sparrow.yaml`:

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

In this example task "main_task" executes some Python code. 

To make it sure we have a Python in runtime,  dependency task "install-python" is executed. 

This example illustrates the core idea behind SparrowCI pipeline - to have a **collection of dependent tasks** (DAG) that executed in **particular order**.
