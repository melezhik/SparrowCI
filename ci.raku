use Sparky::JobApi;
use HTTP::Tiny;
use YAMLish;

class Pipeline does Sparky::JobApi::Role {

  has Str $.task = tags()<task> || "";

  has Str $.tasks_config = tags()<tasks_config> || "";

  has Str $.project = %*ENV<PROJECT> || "SparrowCI";

  has Str $.scm = tags()<scm> || %*ENV<SCM> || 'git@github.com:melezhik/rakudist-teddy-bear.git';

  has Str $.source_dir is default(tags()<source_dir> || "") is rw;

  has Str $.storage_job_id is default(tags()<storage_job_id> || "") is rw;

  has Str $.docker_bootstrap = tags()<docker_bootstrap> || "off";

  has Str $.sparrowdo_bootstrap = tags()<sparrowdo_bootstrap> || "off";

  my $notify-job;

  my @jobs;

  my $time;

  method !get-storage-api (:$docker = False) {

    my $sapi;

    say "get-storage-api. docker_mode=$docker";

    if $.storage_job_id {
      # return existing storage api job  
      $sapi = self.new-job: 
        job-id => $.storage_job_id, 
        project => <SparrowCIStorage>, 
        api => ($docker ?? 'http://host.docker.internal:host-gateway:4000' !! 'http://127.0.0.1:4000');
    } else {
      $sapi = self.new-job: 
        project => <SparrowCIStorage>, 
        api => ($docker ?? 'http://host.docker.internal:host-gateway:4000' !! 'http://127.0.0.1:4000');
      # allocate new storage api job
      $.storage_job_id = $sapi.info()<job-id>;
    } 

    return $sapi; 

  }

  method !tasks-config (:$docker = False) {
    say ">>> load sparrow.yaml from storage, docker_mode=$docker";
    load-yaml(self!get-storage-api(:$docker).get-file("sparrow.yaml",:text));
  }
  
  method !build-report(:$stash) {

    say "build web report ...";

    my %headers = content-type => 'application/json';

    my $j = Sparky::JobApi.new: :mine;

    $stash<project> = $.project;
    $stash<job-id> = $j.info()<job-id>;
    $stash<with-sparrowci> = True;
    $stash<date> = "{DateTime.now}";
    $stash<worker-status> = "OK";
    $stash<scm> = $.scm;
    $stash<elapsed> => $time.Int;

    my $r = HTTP::Tiny.post: "http://127.0.0.1:2222/build", 
      headers => %headers,
      content => to-json($stash);

    $r<status> == 200 or die "{$r<status>} : { $r<content> ?? $r<content>.decode !! ''}";

    my $res = $r<content>.decode;

    say "build web report OK, report_id: {$res}";

  }

  method !get-jobs-list ($j){
    # traverse jobs DAG
    # in order: left -> parent -> right
    if $j.get-stash()<child-jobs><left> {
        for $j.get-stash()<child-jobs><left><> -> $c {
          my $job-id = $c<job-id>;
          my $project = $c<project>;
          my $cj = self.new-job: :$job-id, :$project;
          self!get-jobs-list($cj)
        }
    } 
    say ">>> get-jobs-list: push job={$j.info().perl}";

    @jobs.push: $j.info();
    if $j.get-stash()<child-jobs><right> {
        for $j.get-stash()<child-jobs><right><> -> $c {
          my $job-id = $c<job-id>;
          my $project = $c<project>;
          my $cj = self.new-job: :$job-id, :$project;
          self!get-jobs-list($cj)
        }
    } 

  }

  method stage-main {

      say "tags: {tags().perl}";

      $time = now - INIT now;

      directory "source";
      
      git-scm $.scm, %(
        to => "source",
        branch => "HEAD",
      );

      bash("tar -czvf source.tar.gz source/",%( description => "archive source directory"));

      self!get-storage-api().put-file("source.tar.gz","source.tar.gz");

      my $git-data = task-run "git data", "git-commit-data", %(
        dir => "{$*CWD}/source",
      );

      if $.tasks_config {
        say ">>> copy {$.tasks_config} to remote storage";
        die "{$.tasks_config} file not found" unless $.tasks_config.IO ~~ :e;
        self!get-storage-api().put-file($.tasks_config,"sparrow.yaml");
      } else {
        say ">>> copy source/sparrow.yaml to remote storage";
        unless "source/sparrow.yaml".IO ~~ :e {
          my $stash = %(
            status => "FAIL", 
            log => "sparrow.yaml not found", 
            git-data => $git-data,
          );
          self!build-report: :$stash;
          die "sparrow.yaml file not found"; 
        }
        self!get-storage-api().put-file("source/sparrow.yaml","sparrow.yaml");
      }

      my $tasks-config;

      try {
        # check is tasks-confg is a valid YAML

        $tasks-config = self!tasks-config;

        CATCH { 
          when X::AdHoc {
            my $err-message = .message;  
            my $stash = %(
              status => "FAIL", 
              log => $err-message, 
              git-data => $git-data,
              sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
            );
            self!build-report: :$stash;
            die $err-message;  
          }  
        } 
      }

      my $data = $tasks-config<tasks>.grep({.<default>});
      unless $data {
        my $stash = %(
          status => "FAIL", 
          log => "default task is not found", 
          git-data => $git-data,
          sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
        );
        self!build-report: :$stash;
        die "default task is not found";
      }

      if $data.elems > 1 {
        my $stash = %(
          status => "FAIL", 
          log => "default task - too many found", 
          git-data => $git-data,
          sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
        );
        self!build-report: :$stash;
        die "default task - too many found";
      }

      my $task = $data[0];

      my $project = $task<name>;

      my $j = self.new-job: :$project;

      if $.docker_bootstrap eq "on" {
  
        say ">>> prepare docker container";

        bash(q:to /HERE/, %(description => "docker run") );
          docker run \
          --rm --name alpine \
          --add-host=host.docker.internal:host-gateway \
          -itd alpine
        HERE

      }

      say ">>> trigger task: {$task.perl}";

      my $description = "run [{$task<name>}]";

      my $timeout = 1100;

      $j.queue: %(
        description => $description,
        tags => %(
          stage => "run",
          task => $task<name>,
          storage_job_id => $.storage_job_id,
        ),
        sparrowdo => %(
          docker => "alpine",
          no_sudo => True, 
          bootstrap => ($.sparrowdo_bootstrap eq "on") ?? True !! False 
        )
      );

      my $st = self.wait-job($j,{ timeout => $timeout.Int });
      
      # traverse jobs DAG in order
      # and save result in @jobs

      self!get-jobs-list($j);

      my $st-to-human = %(
        "-2" => "NA",
        "-1" => "FAILED",
        "0" => "RUNNING",
        "1" => "OK",    
      );

      my @logs;

      for @jobs.reverse() -> $b {

        my $r = HTTP::Tiny.get: "http://127.0.0.1:4000/report/raw/{$b<project>}/{$b<job-id>}";

        my $log = $r<content> ?? $r<content>.decode !! '';

        $r = HTTP::Tiny.get: $b<status-url>;

        my $status = $r<content> ?? $r<content>.decode !! '-2';

        say "\n[$b<project>] - [{$st-to-human{$status}}]"; 
        say "================================================================";
        for $log.lines.grep({ $_ !~~ /^^ '>>>'/ }) -> $l {
          say $l;
          @logs.push: $l;
        }

      }

      my $stash = %(
        status => ( $st<OK> ?? "OK" !! ( $st<TIMEOUT> ?? "TIMEOUT" !! ($st<FAIL> ?? "FAIL" !! "NA") ) ), 
        log => @logs.join("\n"), 
        git-data => $git-data,
        sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
      );  

      self!build-report: :$stash;

    }

    method stage-run {

      my $j = Sparky::JobApi.new: :mine;

      my $stash = $j.get-stash();

      my $data = self!tasks-config(:docker<True>)<tasks>.grep({.<name> eq $.task});

      die "task {$.task} is not found" unless $data;

      die "task {$.task} - too many found" if $data.elems > 1;

      my $task = $data[0];

      my $timeout = 600;

      say ">>> handle task: ", $task.perl;

      my $tasks-data = %();

      my %child-jobs = %();

      unless $.source_dir {
        say "source directory does not yet exist, download source archive from storage";
        my $blob = self!get-storage-api(:docker).get-file("source.tar.gz",:bin);
        "source.tar.gz".IO.spurt($blob,:bin);
        bash "tar -xzf source.tar.gz && ls -l source/", %( 
          description => "unpack source archive", 
          cwd => "{$*CWD}" 
        );
        $.source_dir = "{$*CWD}";
      }  
      if $task<depends> {

        say ">>> enter depends block: ", $task<depends>.perl;

        my $tasks = $task<depends>;

        my @jobs = self!run-task-dependency: :$tasks;

        say ">>> waiting for dependency tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout.Int });

        for @jobs -> $dj {
            %child-jobs<left>.push: $dj.info;
            my $d = $dj.get-stash();
            if $d<task>:exists {
              $tasks-data{$d<task>}<state> = $d<state>;
            }
        }

        # save job data
        $j.put-stash(%( child-jobs => %child-jobs ));

        # handle depends jobs errors
        say ">>> depends jobs status: ", $st.perl;

        unless $st<OK> == @jobs.elems {
          say "some depends jobs failed or timeouted: {$st.perl}";
          exit(1)
        }

      }

      my $params = $stash<config> || $task<config> || {};

      $params<tasks> = $tasks-data if $tasks-data;

      my $in-artifacts = $task<artifacts><in>;

      my $out-artifacts = $task<artifacts><out>;

      my $state = self!task-run: :$task, :$params, :$in-artifacts, :$out-artifacts;
 
      my $parent-data = $state;

      if $task<followup> {

        say ">>> enter followup block: ", $task<followup>.perl;

        my $tasks = $task<followup>;

        my @jobs = self!run-task-dependency: :$tasks, :$tasks-data, :$parent-data;

        say ">>> waiting for followup tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout });


        for @jobs -> $fj {
          %child-jobs<right>.push: $fj.info();
        }

        # save job data
        $j.put-stash(%( state => $state, task => $task<name>, child-jobs => %child-jobs ));

        say ">>> followup jobs status: ", $st.perl;

        # handle followup jobs errors

        unless $st<OK> == @jobs.elems {
          say "some followup jobs failed or timeouted: {$st.perl}";
          exit(1);
        }

      } else {
        # save job data
        $j.put-stash(%( state => $state, task => $task<name>, child-jobs => %child-jobs ));       
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
          say ">>> save job vars ...";
          $stash-data<config> =  $t<config>   
        }

        $stash-data<config><parent><state> = $parent-data if $parent-data;

        $stash-data<config><tasks> = $tasks-data if $tasks-data;

        $job.put-stash: $stash-data;

        my $description = "run [d] [{$t<name>}]";;

        say ">>> trigger task [$project] | {$t.perl} | stash: {$stash-data.perl}";

        $job.queue: %(
          description => $description,
          tags => %(
            stage => "run",
            task => $t<name>,
            source_dir => $.source_dir,
            storage_job_id => $.storage_job_id,
          ),
        );

        @jobs.push: $job;

      }

      return @jobs;

    }

    method !task-run (:$task,:$params = {},:$in-artifacts = [],:$out-artifacts = []) {

        my $state;

        say ">>> chdir to source_dir: {$.source_dir}";

        my $cur-dir = $*CWD;

        chdir $.source_dir;

        if $in-artifacts {

          my $job = self!get-storage-api: :docker;

          mkdir ".artifacts";

          for $in-artifacts<> -> $f {
            say ">>> copy artifact [$f] from storage to .artifacts/";
            ".artifacts/{$f}".IO.spurt($job.get-file($f),:bin);
          } 
        }

        if $task<plugin> {
          say ">>> run task [{$task<name>}] | plugin: {$task<plugin>} | params: {$params.perl}";
          $state = task-run $task<name>, $task<plugin>, $params; 
        } else {
          my $task-dir = self!build-task: :$task;
          say ">>> run task [{$task<name>}] | params: {$params.perl} | dir: {$*CWD}/{$task-dir}";
          $state = task-run $task-dir, $params; 
        }
        if $out-artifacts {
          my $job = self!get-storage-api: :docker;
          for $out-artifacts<> -> $f {
            say ">>> copy artifact [{$f<name>}] to storage";
            $job.put-file("{$f<path>}",$f<name>);
          }            
        }
        # restore context
        chdir $cur-dir;

        return $state;
    }

    method !build-task (:$task,:$base-dir?) {

        say ">>> build task [{$task<name>}]";

        my $lang = $task<language> || die "task language is not set";

        my $task-dir = $base-dir || "tasks/{{$task<name>}}";

        mkdir $task-dir;

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
