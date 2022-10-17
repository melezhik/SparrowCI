use Sparky::JobApi;

class Pipeline does Sparky::JobApi::Role {

  has Str $.task = tags()<task> || "";

  has Str $.storage_project = tags()<storage_project> || "";

  has Str $.storage_job_id = tags()<storage_job_id> || "";

  has Str $.storage_api = config()<storage> || "http://127.0.0.1:4000";
  
  method stage-main {

      #say "config: {config().perl}";

      my $data = config()<tasks>.grep({.<default>});

      die "default task is not found" unless $data;

      die "default task - too many found" if $data.elems > 1;

      my $task = $data[0];

      my $project = $task<name>;

      my $j = self.new-job: :$project;

      say "trigger task: {$task.perl}";

      my $storage = self.new-job: api => $.storage_api;  

      my %storage = $storage.info();

      my $description = "run [{$task<name>}]";

      my $timeout = 600;

      $j.queue: %(
        description => $description,
        tags => %(
          stage => "run",
          task => $task<name>,
          storage_project => %storage<project>,
          storage_job_id => %storage<job-id>,
        ),
      );

      my $st = self.wait-job($j,{ timeout => $timeout.Int });

      die $st.perl unless $st<OK> == 1;

      say $st.perl;

    }

    method stage-run {

      my $j = Sparky::JobApi.new: :mine;

      my $stash = $j.get-stash();

      my $data = config()<tasks>.grep({.<name> eq $.task});

      die "task {$.task} is not found" unless $data;

      die "task {$.task} - too many found" if $data.elems > 1;

      my $task = $data[0];

      my $timeout = 600;

      say ">>> handle task: ", $task.perl;

      my $tasks-data = %();

      if $task<depends> {

        say ">>> enter depends block: ", $task<depends>.perl;

        my $tasks = $task<depends>;

        my @jobs = self!run-task-dependency: :$tasks;

        say "waiting for dependency tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout.Int });

        die $st.perl unless $st<OK> == @jobs.elems;

        say $st.perl;

        for @jobs -> $dj {

            my $d = $dj.get-stash();

            if $d<task>:exists {
              $tasks-data{$d<task>}<state> = $d<state>;
            }
        }
      }

      my $params = $stash<config> || $task<config> || {};

      $params<tasks> = $tasks-data if $tasks-data;

      my $in-artifacts = $task<artifacts><in>;

      my $out-artifacts = $task<artifacts><out>;

      my $state = self!task-run: :$task, :$params, :$in-artifacts, :$out-artifacts;
 
      # save task state to job's stash

      $j.put-stash(%( state => $state, task => $task<name> ));

      my $parent-data = $state;

      if $task<followup> {

        say ">>> enter followup block: ", $task<followup>.perl;

        my $tasks = $task<followup>;

        my @jobs = self!run-task-dependency: :$tasks, :$tasks-data, :$parent-data;

        say "waiting for followup tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout });

        die $st.perl unless $st<OK> == @jobs.elems;

        say $st.perl;
      }

    }

    method !run-task-dependency (:$tasks,:$tasks-data = {},:$parent-data = {}) {

      my @jobs;

      for $tasks<> -> $t {
  
        my $project = $t<name>;

        my $job = self.new-job: :$project;

        my $stash-data = %(
          config => { }
        );

        if $t<config> {
          say "save job vars ...";
          $stash-data<config> =  $t<config>   
        }

        $stash-data<config><parent><state> = $parent-data if $parent-data;

        $stash-data<config><tasks> = $tasks-data if $tasks-data;

        $job.put-stash: $stash-data;

        my $description = "run [d] [{$t<name>}]";;

        say "trigger task [$project] | {$t.perl} | stash: {$stash-data.perl}";

        $job.queue: %(
          description => $description,
          tags => %(
            stage => "run",
            task => $t<name>,
            storage_project => $.storage_project,
            storage_job_id => $.storage_job_id,
          ),
        );

        @jobs.push: $job;

      }

      return @jobs;

    }

    method !task-run (:$task,:$params = {},:$in-artifacts = [],:$out-artifacts = []) {
        my $state;

        if $in-artifacts {
          my $job = self.new-job: 
            job-id => $.storage_job_id, 
            project => $.storage_project, 
            api => $.storage_api;
            
          mkdir ".artifacts";

          for $in-artifacts<> -> $f {
            say "copy artifact [$f] from storage to .artifacts/";
            ".artifacts/{$f}".IO.spurt($job.get-file($f),:bin);
          } 
        }

        if $task<plugin> {
          say "run task [{$task<name>}] | plugin: {$task<plugin>} | params: {$params.perl}";
          $state = task-run $task<name>, $task<plugin>, $params; 
        } else {
          my $task-dir = self!build-task: :$task;
          say "run task [{$task<name>}] | params: {$params.perl} | dir: {$*CWD}/{$task-dir}";
          $state = task-run $task-dir, $params; 
        }
        if $out-artifacts {
          my $job = self.new-job: 
            job-id => $.storage_job_id, 
            project => $.storage_project, 
            api => $.storage_api;
          for $out-artifacts<> -> $f {
            say "copy artifact [{$f<name>}] to storage";
            $job.put-file("{$f<path>}",$f<name>);
          }            
        }
        return $state;
    }

    method !build-task (:$task,:$base-dir?) {

        say "build task [{$task<name>}]";

        my $lang = $task<language> || die "task language is not set";

        my $task-dir = $base-dir || "tasks/{{$task<name>}}";

        directory $task-dir;

        # build subtasks recursively
        if $task<subtasks> {
          for $task<subtasks><> -> $st {
            self!build-task: task => $st, base-dir => "$task-dir/tasks/{$st<name>}";
          }
        }

        my %lang-to-ext = %(
          raku => "raku",
          bash => "bash",
          perl => "pl",
          powershell => "ps1",
          python => "py",
          ruby => "rb",
        );

        die "unkonwn language $lang" unless %lang-to-ext{lc($lang)}:exists;

        my $ext = %lang-to-ext{lc($lang)};

        "{$task-dir}/task.{$ext}".IO.spurt(
          ($ext eq "py") ?? "from sparrow6lib import *\n\n{$task<code>}" !! $task<code>
        ) if $task<code>;

        "{$task-dir}/task.check".IO.spurt($task<check>) if $task<check>;

        "{$task-dir}/config.raku".IO.spurt($task<config>.perl) if $task<config>;

        if $task<init> {
            "{$task-dir}/hook.{$ext}".IO.spurt(
              ($ext eq "py") ?? "from sparrow6lib import *\n\n{$task<init>}" !! $task<init>
            );
        }

        return $task-dir;

    }

  }


Pipeline.new.run;
