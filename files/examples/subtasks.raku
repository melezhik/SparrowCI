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
