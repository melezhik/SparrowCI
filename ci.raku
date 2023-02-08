use Sparky::JobApi;
use HTTP::Tiny;
use YAMLish;
use JSON::Fast;

class Pipeline does Sparky::JobApi::Role {

  has Str $.task = tags()<task> || "";

  has Str $.tasks_config = tags()<tasks_config> || "";

  has Str $.owner = tags()<owner> || "";

  has Str $.image = tags()<image> || "";

  has Str $.project = tags()<project> || tags()<SPARKY_PROJECT> || "";

  has Str $.scm = tags()<scm> || tags()<SCM_URL> || "";

  has Str $.source_dir is default(tags()<source_dir> || "") is rw;

  has Str $.storage_job_id is default(tags()<storage_job_id> || "") is rw;

  has Str $.docker_bootstrap = tags()<docker_bootstrap> || "on";

  has Str $.sparrowdo_bootstrap = tags()<sparrowdo_bootstrap> || "off";

  has Str $.is_reporter = tags()<is_reporter> || "";

  my $notify-job;

  my @jobs;

  method !get-storage-api (:$docker = False) {

    my $sapi;

    say ">>> get-storage-api. docker_mode=$docker";

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
    my $file = self!get-storage-api(:$docker).get-file("sparrow.yaml",:text);
    my $processed-file = $file.subst(/'{{' \s* 'CWD' \s* '}}'/,$.source_dir,:g);
    load-yaml($processed-file);
  }
  
  method !build-report(:$stash) {

    say "build web report ...";

    my %headers = content-type => 'application/json';

    my $j = Sparky::JobApi.new: :mine;

    my $time = now - INIT now;

    $stash<project> = $.project;
    $stash<job-id> = $j.info()<job-id>;
    $stash<with-sparrowci> = True;
    $stash<date> = "{DateTime.now}";
    $stash<worker-status> = "OK";
    $stash<scm> = $.scm;
    $stash<elapsed> = $time.Int;

    my $res;
    my $cnt = 0;
    
    while True {
      my $r = HTTP::Tiny.post: "http://127.0.0.1:2222/build", 
        headers => %headers,
        content => to-json($stash);
        if $r<status> == 200 {
          $res = from-json($r<content>.decode);
          last;
        }
        if $cnt == 3 or $r<status> != 599 {
          die "{$r<status>} : { $r<content> ?? $r<content>.decode !! ''}"
        }
        $cnt++;
        say ">>> (599 recieved) http retry: #0{$cnt}";
        sleep(60);
    }

    say "build web report OK, report_id: {$res}";

    return $res;

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

      my $j = self.new-job: :project<SparrowCIQueue>;

      my $timeout = 1100;

      $j.queue: %(
            description => "{$.scm} queue",
            tags => %(
              stage => "prepare",
              project => $.project,
              scm => $.scm,
              docker_bootstrap => $.docker_bootstrap,
              sparrowdo_bootstrap => $.sparrowdo_bootstrap,
              tasks_config => $.tasks_config,
              image => $.image,
              owner => $.owner,
              scm_branch => tags()<SCM_BRANCH> || 'HEAD',
            ),
      );

      self.wait-job($j,{ timeout => $timeout.Int });

  }

  method stage-prepare {

      say "tags: {tags().perl}";

      directory "source";
      
      git-scm $.scm, %(
        to => "source",
        branch => tags()<scm_branch>,
      );

      task-run "archive source directory", "pack-unpack", %(
        target => "source", 
        file => "source.tar.gz"
      );

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
            state => -2, 
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
              state => -2,
              log => $err-message, 
              git-data => $git-data,
              sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
            );
            self!build-report: :$stash;
            die $err-message;  
          }  
        } 
      }

      unless $tasks-config<tasks>.isa('Array') {
        my $stash = %(
          status => "FAIL", 
          state => -2,
          log => "tasks should be an array", 
          git-data => $git-data,
          sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
        );
        self!build-report: :$stash;
        die "tasks should be an array";
      }

      my $data = $tasks-config<tasks>.grep({.<default>});

      unless $data {
        my $stash = %(
          status => "FAIL", 
          state => -2,
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
          state => -2,
          log => "default task - too many found", 
          git-data => $git-data,
          sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
        );
        self!build-report: :$stash;
        die "default task - too many found";
      }

      my @images = $.image ?? [ $.image ] !!
      ( $tasks-config<image> ?? $tasks-config<image><> !! ['melezhik/sparrow:alpine'] );

      my $jobs-status = "OK";
      my $warn-cnt = 0; # number of warnings found in jobs

      for @images -> $image {

        my $task = $data[0];

        my $project = $task<name>;

        my $j = self.new-job: :$project;

        if $.docker_bootstrap eq "on" {
    
          say ">>> prepare docker container";

          task-run "docker stop", "docker-cli", %(
            action => "stop",
            name => "sparrow-worker"
          );

          my $docker-run-params = %();

          $docker-run-params<action> = "run";
          $docker-run-params<name> = "sparrow-worker";
          $docker-run-params<image> = $image;

          if $.owner && $tasks-config<secrets> {
            $docker-run-params<secrets> = $tasks-config<secrets>.join(" ");
            $docker-run-params<vault_path> = "/kv/sparrow/users/{$.owner}/secrets";
          }
          
          # common pipeline variables:
          my $docker-opts = "-e SCM_URL={$.scm} -e SP6_DUMP_TASK_CODE=1";
          $docker-opts ~= " -e SCM_SHA={$git-data<sha>}";
          my $git-comment = $git-data<comment>.split("\n").first.subst("'","",:g);
          $docker-opts ~= " -e SCM_COMMIT_MESSAGE='{$git-comment}'";

          # following variables are only available for reporter pipelines:
          $docker-opts ~= " -e BUILD_STATUS={tags()<build_status>}" if tags()<build_status>;
          $docker-opts ~= " -e BUILD_URL={tags()<build_url>}" if tags()<build_url>;
          $docker-opts ~= " -e BUILD_WARN_CNT={tags()<warn_cnt>||0}";

          if $.is_reporter {
            $docker-opts ~= " -v {%*ENV<HOME>}/.sparrowci/irc/bot/messages/:/tmp/irc/bot/messages/";
          }

          $docker-run-params<options> = $docker-opts;

          task-run "docker run", "docker-cli", $docker-run-params;

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
            docker => "sparrow-worker",
            no_sudo => True,
            repo => "https://sparrowhub.io/repo", 
            bootstrap => ($.sparrowdo_bootstrap eq "on") ?? True !! False 
          )
        );

        my $st = self.wait-job($j,{ timeout => $timeout.Int });

        say ">>> STOP WAITING ALL JOBS: {$st.perl}";

        $jobs-status = "FAIL" unless $st<OK>;

        # traverse jobs DAG in order
        # and save result in @jobs

        @jobs = [];
  
        self!get-jobs-list($j);

        my $st-to-human = %(
          "-2" => "NA",
          "-1" => "FAILED",
          "0" => "RUNNING",
          "1" => "OK",    
        );

        my @logs;

        for @jobs -> $b {

          my $r = HTTP::Tiny.get: "http://127.0.0.1:4000/report/raw/{$b<project>}/{$b<job-id>}";

          my $log = $r<content> ?? $r<content>.decode !! '';

          $r = HTTP::Tiny.get: $b<status-url>;

          my $status = $r<content> ?? $r<content>.decode !! '-2';

          say "\n[$b<project>] - [{$st-to-human{$status}}]"; 
          say "================================================================";
          for $log.lines.grep({ $_ !~~ /^^ '>>>'/ }) -> $l {
            say $l;
            @logs.push: $l;
            $warn-cnt++ if $l ~~ /":: warn:"/;
          }

        }

        my $stash = %(
          status => ( $st<OK> ?? "OK" !! ( $st<TIMEOUT> ?? "TIMEOUT" !! ($st<FAIL> ?? "FAIL" !! "NA") ) ), 
          state => ( $st<OK> ?? "1" !! ( $st<TIMEOUT> ?? "-1" !! ($st<FAIL> ?? "-2" !! "-10") ) ),
          log => @logs.join("\n"), 
          git-data => $git-data,
          image => $image,
          sparrow-yaml => self!get-storage-api.get-file("sparrow.yaml",:text),
        );  

        task-run "docker stop", "docker-cli", %(
          action => "stop",
          name => "sparrow-worker",
        );

        # we don't create reports for 
        # reporters jobs 
        unless  $.is_reporter {
          my $report = self!build-report: :$stash;
          if "{%*ENV<HOME>}/.sparrowci/reporters/".IO ~~ :d and $.is_reporter ne "yes" {
            # runs reporters jobs
            for dir("{%*ENV<HOME>}/.sparrowci/reporters/", test => /'.yaml'$$/) -> $r {
              my $j = self.new-job: :project<SparrowCIQueue>;
              $j.queue: %(
                description => "{$.scm} queue (reporter - {$r.basename})",
                tags => %(
                  stage => "prepare",
                  is_reporter => "yes",
                  project => $.project,
                  scm => $.scm,
                  docker_bootstrap => $.docker_bootstrap,
                  sparrowdo_bootstrap => $.sparrowdo_bootstrap,
                  tasks_config => $r.path,
                  image => $.image,
                  owner => $.owner,
                  build_status => $jobs-status,  
                  build_url => "{%*ENV<SPARROWCI_HOST> || 'https://ci.sparrowhub.io'}/report/{$report<build-id>}",
                  warn_cnt => $warn-cnt,
                ),
              );
            }
          }
        }
      }

     if $tasks-config<followup_job> && $jobs-status eq "OK" {

        # runs followup jobs

        my $j = self.new-job: :project<SparrowCIQueue>;

        $j.queue: %(
              description => "{$.scm} queue (followup - {$tasks-config<followup_job>})",
              tags => %(
                stage => "prepare",
                project => $.project,
                scm => $.scm,
                docker_bootstrap => $.docker_bootstrap,
                sparrowdo_bootstrap => $.sparrowdo_bootstrap,
                tasks_config => "source/{$tasks-config<followup_job>}",
                image => $.image,
                owner => $.owner
              ),
        );
      } 
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

      unless $.source_dir {
        say "source directory does not yet exist, download source archive from storage";
        my $blob = self!get-storage-api(:docker).get-file("source.tar.gz",:bin);
        "source.tar.gz".IO.spurt($blob,:bin);
        task-run "unpack source archive", "pack-unpack", %(
          action => "unpack",
          # dir => "source", 
          file => "source.tar.gz"
        );
        $.source_dir = "{$*CWD}";
      }  

      # child jobs - holds references to 
      # all depends/followup tasks/jobs
      # and get's linked to the current job

      my %child-jobs = %();

      # accumulated state - represents 
      # all output data, 
      # collected from hub tasks

      my @acc-state = (); # hub tasks accumulated state
      my $i = 0; # hub tasks counter 

      # task out data will hold
      # depends tasks output data

      my $tasks-out-data = %();

      my @tasks; # hub tasks

      # execute depends tasks _before_ 
      # any tasks 

      if $task<depends> {

        say ">>> enter depends block: ", $task<depends>.perl;

        my @jobs = self!run-task-dependency: :tasks($task<depends>);

        say ">>> waiting for dependency tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout.Int });

        for @jobs -> $dj {
            %child-jobs<left>.push: $dj.info;
            my $d = $dj.get-stash();
            if $d<task>:exists {
              $tasks-out-data{$d<task>}<state> = $d<state>;
            }
        }

        # save job data
        $j.put-stash(%( child-jobs => %child-jobs ));

        # handle depends jobs errors
        say ">>> depends jobs status: ", $st.perl;

        unless $st<OK> == @jobs.elems {
          say "some depends jobs failed or timeouted: {$st.perl}";
          exit(1);
        }
      }

      if $task<if> { # compute conditional task
        say ">>> compute conditional task ...";
        my $task-if = $task<if>; $task-if<name> = "{$task<name>}-if";
        my $params = $stash<config> || {};
        $params<tasks> = $tasks-out-data if $tasks-out-data;
        my $state = self!task-run: :task($task-if), :$params;
        if $state<status> and  $state<status> eq "skip" {
          say ">>> conditional task returns SKIP, don't execute main task";
          return;
        }
      }
      
      if $task<hub> {

        say ">>> run hub generator code";
        my $params = $stash<config> || {};
        $params<tasks> = $tasks-out-data if $tasks-out-data;
        my $ht = $task<hub>;
        $ht<name> = "{$task<name>}-hub";
        my $state = self!task-run: :task($ht), :$params;
        @tasks = $state<list> ?? $state<list><> !! [];  
        
      } else {

        # in case there is no hub
        # hub is effectively just one task
        
        push @tasks, $task;
 
      }

      for @tasks -> $t {

        $i++;  

        # if conditional task exists within hub iterator
        # compute conditional task for every task in hub tasks list
        if $t<if> && $task<hub> { 
            say ">>> compute conditional task ...";
            my $task-if = $t<if>; $task-if<name> = "{$task<name>}-hub-if-{$i}";
            my $params = $t<config> || {};
            $params<tasks> = $tasks-out-data if $tasks-out-data;
            my $state = self!task-run: :task($task-if), :$params;
            if $state<status> and  $state<status> eq "skip" {
              say ">>> conditional task returns SKIP, don't execute hub task";
              next;
            }
        }
  
        my $params = $task<hub> ?? ($t<config> || {}) !! ($stash<config> || {});

        # pass depends tasks output data 
        # to parent task as config()<tasks>

        $params<tasks> = $tasks-out-data if $tasks-out-data;

        my $in-artifacts = $task<artifacts><in>;

        my $out-artifacts = $task<artifacts><out>;

        my $state = self!task-run: :$task, :$params, :$in-artifacts, :$out-artifacts;
  
        # link job and task data
        @acc-state.push: $state;

        $j.put-stash(%( 
          state => $task<hub> ?? @acc-state !! $state,
          task => $task<name>, 
          child-jobs => %child-jobs 
        ));

      } # next task in @tasks

      # execute followup tasks
      # _after_ hub tasks are finished

      if $task<followup> { 

        say ">>> enter followup block: ", $task<followup>.perl;

        my $tasks = $task<followup>;

        my $parent-data = $task<hub> ?? @acc-state !! (@acc-state.elems ?? @acc-state[0] !! %());

        my @jobs = self!run-task-dependency: :$tasks, :tasks-data($tasks-out-data), :$parent-data;

        say ">>> waiting for followup tasks have finsihed ...";

        my $st = self.wait-jobs(@jobs,{ timeout => $timeout });

        for @jobs -> $fj {
          %child-jobs<right>.push: $fj.info();
        }

        $j.put-stash(%( 
          state => $task<hub> ?? @acc-state !! (@acc-state.elems ?? @acc-state[0] !! %()),
          task => $task<name>, 
          child-jobs => %child-jobs 
        ));

        say ">>> followup jobs status: ", $st.perl;

        # handle followup jobs errors

        unless $st<OK> == @jobs.elems {
          say "some followup jobs failed or timeouted: {$st.perl}";
          exit(1);
        }
      }  
    }

    method !run-task-dependency (:$tasks,:$tasks-data = {},:$parent-data) {

      my @jobs;

      for $tasks<>.sort({ .<queue> ?? (.<queue>,.<priority>) !! True }).reverse -> $t {
  
        say ">>> run-task-dependency: handle task: {$t.perl}";

        my $project = $t<queue> || $t<name>;

        my $job = self.new-job: :$project;

        my $data = self!tasks-config(:docker<True>)<tasks>.grep({.<name> eq $t<name>});
        
        die "task {$t<name>} is not found" unless $data;

        my $stash-data = %(
          say ">>> set default depend/followup task/plugin parameters ...";
          config => $data[0]<config> || {},
        );

        if $t<config> {
          say ">>> override default depend/followup task/plugin parameters ...";
          $stash-data<config> =  $t<config>   
        }

        $stash-data<config><parent><state> = $parent-data if $parent-data;

        $stash-data<config><tasks> = $tasks-data if $tasks-data;

        $job.put-stash: $stash-data;

        my $description = "run [d] [{$t<name>}]";

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

        sleep(3);

        @jobs.push: $job;

      }

      return @jobs;

    }

    method !task-run (:$task, :$params = {},:$in-artifacts = [],:$out-artifacts = []) {

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
          go => "go"
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
