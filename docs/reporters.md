# Reporters

SparrowCI instances administrators might configure integration of SparrowCI instance with
third party external services by using reporters mechanism.

Reporters are plain SparrowCI pipeline(s) get executed after a _regular_ SparrowCI pipeline has finished.

Reporters provides an effective mechanism of any sort of notification. 

To create reporter just create a SparrowCI pipeline inside `~/.sparrowci/reporters/` directory.

# Examples

## Bugzilla

In this flow SparrowCI notifies Bugzilla service with a build information and optionally closes a related bug:

```bash
mkdir -p ~/.sparrowci/reporters
cat << 'HERE' > ~/.sparrowci/reporters/bugzilla.yaml
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
      %*ENV<SCM_COMMIT_MESSAGE> ~~ /"bug:" \s+ (\D+)/;
      my $bug-id = "$0";
      run_task "comment", %(
        bugid => $bug-id
      );
      if %*ENV<SCM_COMMIT_MESSAGE> ~~ /'close!'/ 
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
```

More detailed explanation:

* Reporter adds a comment with a build http link to the related Bugzilla bug

* If a build has succeeded and a commit message contains `close!` string, the bug is closed

* Bugzilla bug number is set in commit message with `bug: number` pattern

* Access to Bugzilla rest api is set via `BUGZILLA_RESTAPI_KEY` [secret](https://github.com/melezhik/SparrowCI#secrets-management)

Secret should be added to the account of a user who owns pipelines.

# See also

* Variables - [variables.md](variables.md)

* Reporters examples - see [reporters/](https://github.com/melezhik/SparrowCI/tree/main/reporters) directory

