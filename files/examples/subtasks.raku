tasks:
  -
    name: main
    language: Bash
    default: true
    init: |
      task_run "task1"
    subtasks:
      -
        name: task1
        language: Bash
        init: |
          task_run "task2"
        code: |
          echo "task1"
      -
        name: task2
        language: Bash
        code: |
          echo "task2"
    code: |
      echo "finshed"
