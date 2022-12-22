# Reporters

SparrowCI instances administrators might configure integration with
third party external systems via reporters mechanism.

In this example after _every_ pipeline execution, SparrowCI notifies
Bugzilla service with a build information and optionally close related bug:


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

Reporter will add a comment containing a pipeline build link to related Bugzilla bug. 

Optionally if a build has succeeded and a commit message contains `close!` string,
reporter closes the bug. 

Bugzilla bug number is set in commit message with "bug: number" pattern. 

Access to Bugzilla rest api is set via `BUGZILLA_RESTAPI_KEY` Sparrow [secret](https://github.com/melezhik/SparrowCI#secrets-management).

Secret should be added to a user account that owns pipelines.
