# Go support

SparrowCI allows to write tasks on Go. The API
is similar to all other languages, but because of
Go specific (naming of public functions, etc)
has some nuances.

Here is some example:


```yaml
tasks:
  - 
    name: main
    default: true
    language: Go
    code: |
      package main

      import (
        "fmt"
        "github.com/melezhik/sparrowgo"
      )

      func main() {

        // sparrowgo.DebugOn()

        type State struct { Message string }

        var state State

        sparrowgo.GetState(&state)

        fmt.Printf("task state: %s\n",state.Message)

      }
    init: |    
      package main

      import (
        "github.com/melezhik/sparrowgo"
      )

      func main() {

        type Params struct {
          Message string
        }

        sparrowgo.RunTask("foo",Params{Message: "Hello from main"})

      }
    subtasks:
      -
        name: foo
        language: Go
        code: |
          package main

          import (
            "fmt"
            "github.com/melezhik/sparrowgo"
          )

          func main() {

            // sparrowgo.DebugOn()

            type Vars struct {
              Message string
            }

            type Message struct {
              Message string
            }

            var task_vars Vars

            sparrowgo.TaskVars(&task_vars)

            fmt.Printf("foo subtask get this: %s\n",task_vars.Message)

            sparrowgo.UpdateState(Message{Message: "Hello from subtask"})
          }              
```

For more information visit [sparrowgo](https://github.com/melezhik/sparrowgo) project documentation page.
 
