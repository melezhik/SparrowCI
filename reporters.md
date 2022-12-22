# Reporters

SparrowCI instances administrators might configure SparrowCI instance integration with
third party external services by using reporters mechanism.

# Examples


## Bugzilla

In this flow after _every_ pipeline has been executed, SparrowCI notifies
Bugzilla service with a build information and optionally close a related bug:

```bash
cat << 'HERE' > ~/.sparkyci/reporters/bugzilla.yaml
secrets:
  - BUGZILLA_RESTAPI_KEY
tasks:
  - 
    name: main
    default: true
    language: Raku
    config:
      bugzilla_api: https://bugzilla-dev.allizom.org
    init: |
      config()<tasks><git-commit><state><comment> ~~ /"bug:" \s+ (\D+)/;
      my $bug-id = "$0";
      run_task "comment", %(
        bugid => $bug-id
      );
      if config()<tasks><git-commit><state><comment> ~~ /'close!'/ 
        and %*ENV<BUILD_STATUS> eq "OK" {
        run_task "close", %(
          bugid => $bug-id
        )
      }
    subtasks:
      - 
        name: comment
        language: Bash
        code: |
          set -e
          bugzilla_api=$(config bugzilla_api)
          cat << HERE > data.json
          {
            "comment" : "SparrowCI build finished. URL: $BUILD_URL. STATUS: $BUILD_STATUS",
            "is_private" : false
          }      
          HERE

          curl -fs -H "Content-Type: application/json" -X POST \
          --data @data.json $bugzilla_api/rest/bug/$bugid/comment?api_key=$BUGZILLA_RESTAPI_KEY
      - 
        name: close
        language: Bash
        code: |
          set -e
          bugzilla_api=$(config bugzilla_api)
          cat << HERE > data.json
          {
            "ids" : [$bugid],
            "status" : "RESOLVED",
            "resolution" : "MOVED"
          }          
          HERE

          curl -fs -H "Content-Type: application/json" -X PUT \
          --data @data.json $bugzilla_api/rest/bug/$bugid?api_key=$BUGZILLA_RESTAPI_KEY

    depends:
      -
        name: git-commit
  - name: git-commit
    plugin: git-commit-data
    config:
      dir: source
```

More detailed explanation:

* Reporter adds a comment with a build http link to the related Bugzilla bug

* If a build has succeeded and a commit message contains `close!` string, the bug is closed

* Bugzilla bug number is set in commit message with `bug: number` pattern

* Access to Bugzilla rest api is set via `BUGZILLA_RESTAPI_KEY` [secret](https://github.com/melezhik/SparrowCI#secrets-management)

Secret should be added to the account of a user who owns pipelines.
