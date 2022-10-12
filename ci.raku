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

      if $task<depends> {

        say ">>> enter depends block: ", $task<depends>.perl;

        my @jobs = self!run-task-dependency($task<depends>);

        say "waiting for dependency tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout.Int });

        die $st.perl unless $st<OK> == @jobs.elems;

        say $st.perl;

      }

      self!task-run: :$task;
 
      if $task<cleanup> {

        say ">>> enter cleanup block: ", $task<cleanup>.perl;

        my @jobs = self!run-task-dependency($task<cleanup>);

        say "waiting for cleanup tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout });

        die $st.perl unless $st<OK> == @jobs.elems;

        say $st.perl;
      }

    }

    method !run-task-dependency ($tasks) {

      my @jobs;

      for $tasks<> -> $t {
  
        my $project = $t<name>;

        my $job = self.new-job: :$project;

        say "trigger task [$project] | {$t.perl}";

        if $t<config> {
          say "save job vars ...";    
          $job.put-stash({ config => $t<config> });
        }

        my $description = "run [d] [{$t<name>}]";;

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

    method !task-run (:$task) {

        say "run task - to be implemented";

    }

  }


Pipeline.new.run;


