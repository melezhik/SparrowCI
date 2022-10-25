# SparrowCI - DSL is dead, long live DSL!

TL;DR - How to write YAML DSL pipelines without frustration.

---

To be honest, I am not in favor of modern DSL based tools.

At least, I am not in favor of them when people try to use those tools for the things they are not *very well designed to* ( which starts to happen pretty quickly ).

Starting from Ansible the course of declarative style DSL languages seems has taken the market, while it does not always mean those tools are easy to use and maintain. 

---

Well, for simple, typical cases ala `make && sudo make install` this approach works really well, while for more complex scenarios where a pipeline logic implies _some data flow and sharing states between steps_ the idea of confining everything into a declarative (none imperative) approach results in ugly and hard to maintain code.

Consider this simple example of GH actions pipeline of setting 2 variables in 2 steps and using them in downstream code:

```yaml
steps:
  - id: task1
    run: echo "::set-output name=test::hello"

  - id: task2
    run: echo "::set-output name=test::world"

  - name: main 
    run: |
      echo "Task1 returns: ${{ steps.task1.outputs.test }}"
      echo "Task2 returns: ${{ steps.task2_outputs.test }}"
```

It’s not only not natural to read (we use none relevant print command to set the output), but also to maintain. 

* One of the question that pops up here, if I use high level general purpose programming language why should I use print commands to declare return output ?
* Another question - how can step return structured, complex object data?

* And the last but not the least how to pass _arbitrary_ configuration as a task input? 

---

This is why ( well partly because of that ) I've created [SparrowCI](https://ci.sparrowhub.io) - super fun and flexible CI system with many programming languages support

---

SparrowCI DSL still allows one to write pipeline code as YAML based steps, however, every step essentially is a function written in a language of choice and thus accepting some input parameters and returning some output values.

That is it.

So we have a good balance of YAML based pipelines for people not willing to go imperative path and do any serious coding and flexibility and freedom to express elementary units of pipeline logic as functions written on regular programming languages:

```yaml
  tasks:
    -
      language: Python
      name: task1
      code: |
        update_state({"test": "hello"})
    -
      name: task2
      language: Python
      depends: 
        - 
          name: task2
      code: |
        update_state({"test": "world"})
    -
      name: main
      language: Python
      default: true
      depends: 
        - 
          name: task1
        - 
          name: task2
      code: |
        print(f”Task1 returns: {config()["tasks"]["task1"]["state"]["test"]}”
        print(f”Task2 returns: {config()["tasks"]["task2"]["state"]["test"]}”

```

---

So, with all being said - DSL(YAML) is dead, long live DSL(YAML)! 


