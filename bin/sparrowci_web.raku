use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cro::WebApp::Template;
use SparrowCI::DB;
use SparrowCI::User;
use SparrowCI::News;
use SparrowCI::HTML;
use SparrowCI::Conf;
use SparrowCI::Security;
use SparrowCI::Repo;
use Text::Markdown;
use JSON::Fast;
use Cro::HTTP::Client;
use File::Directory::Tree;
use Digest::SHA1::Native;

my $application = route {

  my %conf = get-sparrowci-conf();

  get -> :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    my @results = get-builds();
    #die @results.perl;
    template 'templates/main.crotmp', %(
      page-title => "SparrowCI - super fun and flexible CI system with many programming languages support",
      message => $message,
      title => title(),   
      results => @results,
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> 'all', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    my @results = get-builds(1000);
    #die @results.perl;
    template 'templates/main.crotmp', %( 
      page-title => "All Reports",
      title => title(),   
      results => @results,
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> Str $user-id, 'builds', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    my @results = get-builds(100,$user-id);
    #die @results.perl;
    template 'templates/main.crotmp', %( 
      page-title => "{$user-id}'s Reports",
      title => title(),   
      results => @results,
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> 'report', Int $id, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {

    my %report = get-report($id);

    my $path =  %report<with-sparrowci>:exists ?? 'templates/report2.crotmp' !! 'templates/report.crotmp';
    my $title = %report<with-sparrowci>:exists ?? "SparrowCI Report - {%report<project>} | [image: {%report<image> || 'NA'}]" !! "SparrowCI Report - {%report<project>}";

    if %report<project> ~~ /"gh-" (\S+?) "-" (\S+)/ {
        %report<runner> = "$0";
        %report<repo> = "$1"; 
        %report<repo-type> = "gh";
    } elsif %report<project> ~~ /"git-" (\S+?) "-" (\S+)/ {
        %report<runner> = "$0";
        %report<repo> = "$1"; 
        %report<repo-type> = "git";
    }

    %report<user> = $user || "";

    template $path, %( 
      page-title => $title,
      title => title(),   
      %report,
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> 'quickstart', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    template 'templates/quickstart.crotmp', %(
      page-title => "Quick Start", 
      title => title(),   
      data => parse-markdown("docs/quickstart.md".IO.slurp).to_html,
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> 'donations', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    template 'templates/donations.crotmp', %(
      page-title => "Support SparrowCI", 
      title => title(),   
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> 'news', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    my @results = get-news();
    #die @results.perl;
    template 'templates/news.crotmp', %( 
      page-title => "News",
      title => title(),   
      results => @results,
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> 'repos', :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my $data = conf-login-type() eq "GH" ?? gh-repos($user) !! [];
      my @projects = projects($user);
      my $repos =  $data<>.map({ ("\"{$_<name>||''}\"") }).join(",");
      template 'templates/repos.crotmp', %(
        page-title => "Repositories", 
        title => title(),
        projects => @projects, 
        gh-repos-js => $repos,
        login-type => conf-login-type(),
        css => css($theme),
        theme => $theme,
        repos-sync-date => repos-sync-date($user),
        navbar => navbar($user, $token, $theme),
        message => $message,
      )
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage repositories";
    }  
  }

  post -> 'repo', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
 
    if check-user($user, $token) == True {
      my $repo;
      request-body -> (:$repos) {
        $repo = $repos.subst(/\s+/,"",:g);
        say "add repo. user: $user, repo: $repo";
      }

      my $url;
      my $type;

      if $repo ~~ /^^ ( 'https://githbub.com' || 'git@github.com' ) / {
        $url = $repo; 
        $type = "gh"; 
      } elsif $repo ~~ /^^ ( 'https://' || 'git@' ) /  {
        $url = $repo;
        $type = "git";
      } elsif $repo ~~ /<-[ @ \\ \/ : ]>/ and conf-login-type() eq "GH" {  
        $url = "https://github.com/{$user}/{$repo}.git";
        $type = "gh";
      } else {
        $type = "unknown"
      }

      say "effective url: $url, type: $type";

      if $type eq "unknown" {
        redirect :see-other, "{http-root()}/repos?message=bad repository: {$repo}"; 
      } else {
          my $yaml = qq:to/YAML/;
            sparrowdo:
              no_sudo: true
              no_index_update: false
              bootstrap: false
              format: default
              repo: https://sparrowhub.io/repo
              tags: SCM_URL=$url,owner=$user
            disabled: false
            keep_builds: 100
            allow_manual_run: true
            scm:
              url: $url
              branch: HEAD
          YAML
          say "yaml: $yaml";

          my $repo-dir = "{%*ENV<HOME>}/.sparky/projects/{$type}-{$user}-{$repo.split('/').tail}";

          say "create repo dir: $repo-dir";

          mkdir $repo-dir;

          "{$repo-dir}/sparky.yaml".IO.spurt($yaml);

          if "{$repo-dir}/sparrowfile".IO ~~ :e {
            say "{$repo-dir}/sparrowfile symlink exists"; 
            redirect :see-other, "{http-root()}/repos?message=repo {$repo} updated";
          } else {
            say "create {$repo-dir}/sparrowfile symlink"; 
            symlink("ci.raku","{$repo-dir}/sparrowfile");
            redirect :see-other, "{http-root()}/repos?message=repo {$repo} added";
          }
        } 
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage repositories"; 
    }
  }

  post -> 'repos-sync', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my $repo;
      say "sync repos information from GH account for user: $user";
      sync-repos($user);  
      redirect :see-other, "{http-root()}/repos?message=repositories synced from GH account";
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage repositories";
    }  
  }

  post -> 'repo-build', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my $repo-id; my $repo-type;
      request-body -> (:$repo,:$type) {
        $repo-id = $repo;
        $repo-type = $type;
        say "build repo: $repo type: $type";
      }
      
      my $repo-dir = "{%*ENV<HOME>}/.sparky/projects/{$repo-type}-{$user}-{$repo-id}";

      my $id = "{('a' .. 'z').pick(20).join('')}.{$*PID}";

      my %trigger = %(
        description =>  "triggered by SparrowCI user",
      );

      mkdir "{$repo-dir}/.triggers";

      "{$repo-dir}/.triggers/$id".IO.spurt(%trigger.perl);

      say "queue repo: {$repo-id} type: {$repo-type} to build: {$repo-dir}/.triggers/$id";

      redirect :see-other, "{http-root()}/repos?message=repo {$repo-id} queued to build";

    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage repositories";
    }  
  }

  post -> 'build' {

    my $bid;

    request-body  -> %json {

      my $build = %json;

      my $project = %json<project>;
      my $desc = %json<desc>;
      my $state = %json<state>;
      my $job-id = %json<job-id>;
      my $image = %json<image>;

      say "generate SparrowCI build ...";

      $bid = insert-build :$state, :$image, :$project, :$desc, :$job-id;

      say "bid: $bid";

      mkdir "{sparrowci-root()}/data/{$bid}";

      $build<id> = $bid;

      "{sparrowci-root()}/data/{$bid}/data.json".IO.spurt(to-json($build));

    }

    content 'application/json', %( build-id => $bid );

  } 

  post -> 'repo-rm', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my $repo-id; my $repo-type;
      request-body -> (:$repo,:$type) {
        $repo-id = $repo;
        $repo-type = $type;
        say "remove repo: $repo type: $type";
      }
      
      my $repo-dir = "{%*ENV<HOME>}/.sparky/projects/{$repo-type}-{$user}-{$repo-id}";

      if "{$repo-dir}".IO ~~ :d {
          say "remove {$repo-dir}";
        rmtree $repo-dir;
      } else {
          say "{$repo-dir} does not exist"; 
      }
      redirect :see-other, "{http-root()}/repos?message=repo {$repo-id} removed";
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage repositories";
    }  
  }

  get -> 'repo', 'manage', 'branches', :$type, :$repo, :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my @projects = projects($user);
      template 'templates/repo-branches.crotmp', %(
        page-title => "Manage repository branches", 
        title => title(),
        css => css($theme),
        theme => $theme,
        repo => $repo,
        type => $type,
        navbar => navbar($user, $token, $theme),
        projects => @projects,
        message => $message,
      )
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage branches";
    }  
  }

  post -> 'repo', 'branch', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {

    if check-user($user, $token) == True {
      my $branch-param; 
      my $branch-memo-param;  
      my $type-param;
      my $repo-param;
      my $process = True;

      request-body -> (:$branch, :$branch_memo, :$repo, :$type) {
        $branch-param = $branch.subst(/\s+/,"",:g);
        $branch-memo-param = $branch_memo;
        $repo-param = $repo;
        $type-param = $type;
        say "add branch to repo. user: $user, repo: $repo, type: $type, branch: $branch, memo: $branch_memo";
      }
      if $branch-param !~~ /\S+/ {
        redirect :see-other, "{http-root()}/repo/manage/branches?repo={$repo-param}&type={$type-param}&message=bad branch";
      } elsif $branch-memo-param ~~ /^^ <[ a .. z A .. Z 0 .. 9 _ ]>+ $$/ {
        my $repo-dir = "{%*ENV<HOME>}/.sparky/projects/branch-{$user}-{$repo-param}-{$branch-memo-param}";
        say "create repo dir: $repo-dir";
        mkdir $repo-dir;
        my $t =  "{%*ENV<HOME>}/.sparky/projects/{$type-param}-{$user}-{$repo-param}/sparky.yaml".IO.slurp(); 
        $t.=subst(/'branch:' \s+ HEAD/,"branch: $branch-param");
        "{%*ENV<HOME>}/.sparky/projects/branch-{$user}-{$repo-param}-{$branch-memo-param}/sparky.yaml".IO.spurt($t);
        if "{$repo-dir}/sparrowfile".IO ~~ :e {
          say "{$repo-dir}/sparrowfile symlink exists"; 
        } else {
          say "create {$repo-dir}/sparrowfile symlink"; 
          symlink("ci.raku","{$repo-dir}/sparrowfile");
        }
        redirect :see-other, "{http-root()}/repo/manage/branches?repo={$repo-param}&type={$type-param}&message=branch {$branch-param} added";
      }  else {
        redirect :see-other, "{http-root()}/repo/manage/branches?repo={$repo-param}&type={$type-param}&message=bad memo name";
        $process = False;
      }
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage branches";
    }  
  }

  get -> 'repo', 'edit', Str $type, Str $repo-id, :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my %repo = get-repo($user, $repo-id, $type);
      template 'templates/repos-edit.crotmp', %(
        page-title => "Edit Repo - {$repo-id}", 
        title => title(),
        %repo, 
        css => css($theme),
        theme => $theme,
        navbar => navbar($user, $token, $theme),
        message => $message,
      )
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage repositories";
    }  
  }

  get -> 'repo', Str $repo-id, 'link', :$type, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    my $repo = get-repo($user,$repo-id,$type);
    if $repo && $repo<scm> && $repo<scm><url> {
      redirect :see-other, $repo<scm><url>;
    } else {
      redirect :see-other, "{http-root()}/repos?message=http link not found";
    }  
  }

  get -> 'tc', Int $id, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    my %report = get-report($id);
    template 'templates/tc.crotmp', %( 
      title => title(),   
      %report,
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )
  }

  get -> 'project', Str $project, 'badge', 'markdown', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {

    template 'templates/badge.crotmp', %( 
      page-title => "{$project} badge",  
      title => title(),   
      badge => "[![SparrowCI](https://ci.sparrowhub.io/project/{$project}/badge)](https://ci.sparrowhub.io)",
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    )

  }

  get -> 'project', Str $project, 'badge', {
    my $b = get-last-build($project);
    cache-control :no-store, :no-cache;
    if $b<state> eq "OK" {
      redirect :see-other, 'https://img.shields.io/static/v1?label=SparrowCI&message=Build+|+OK&color=green'
    } elsif $b<state> eq "FAIL" {
      redirect :see-other, 'https://img.shields.io/static/v1?label=SparrowCI&message=Build+|+FAIL&color=red'
    } elsif $b<state> eq "TIMEOUT" {
      redirect :see-other, 'https://img.shields.io/static/v1?label=SparrowCI&message=Build+|+TIMEOUT&color=yellow'
    } else {
      redirect :see-other, 'https://img.shields.io/static/v1?label=SparrowCI&message=Build+|+UNKOWN&color=gray'
    }
  }

  get -> 'secrets', :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      if conf-use-secrets() {
        my @secrets = secrets($user);
        template 'templates/secrets.crotmp', %(
          page-title => "Secrets", 
          title => title(),
          secrets => @secrets, 
          css => css($theme),
          theme => $theme,
          navbar => navbar($user, $token, $theme),
          message => $message,
        )
      } else {
        redirect :see-other, "{http-root()}/?message=secrets are not enabled on this instance";         
      }
    } else {
      redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage secrets";
    }  
  }

  post -> 'secret', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my $secret_param; my $secret_value_param;
      request-body -> (:$secret,:$secret_value) {
        $secret_param = $secret;
        $secret_value_param = $secret_value;
        say "add secret: $secret";
      }
    $secret_param.=subst(/\s/,"",:g);  
    if $secret_param ~~ /^^ <[ a .. z A .. Z 0 .. 9 \- _ ]>+ $$/ {
      secret-add($user,$secret_param,$secret_value_param);
      redirect :see-other, "{http-root()}/secrets?message=secret {$secret_param} added";
    }  else {
      redirect :see-other, "{http-root()}/secrets?message=bad secret name";
    }
    } else {
        redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage secrets"; 
    }
  }

  post -> 'rm-secret', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my $secret_param;
      request-body -> (:$secret) {
        $secret_param = $secret;
        say "delete secret: $secret";
      }
      secret-delete($user,$secret_param);
      redirect :see-other, "{http-root()}/secrets?message=secret {$secret_param} deleted";
    } else {
        redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage secrets"; 
    }
  }

  get -> 'account', :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      template 'templates/account.crotmp', %(
        page-title => "Account Manager", 
        title => title(),
        login => $user, 
        login-type => conf-login-type(),
        css => css($theme),
        theme => $theme,
        navbar => navbar($user, $token, $theme),
        message => $message,
      )
    } else {
      if conf-login-type() eq "GH" {
        redirect :see-other, "{http-root()}/login-page?message=you need to sign in to manage account";
      } else {
        redirect :see-other, "{http-root()}/login-page2?message=you need to sign in to manage account";
      }
    }  
  }

  get -> 'js', *@path {
      cache-control :public, :max-age(300);
      static 'js', @path;
  }

  get -> 'css', *@path {
      cache-control :public, :max-age(300);
      static 'css', @path;
  }

  get -> 'icons', *@path {

    cache-control :public, :max-age(3000);

    static 'icons', @path;

  }

  get -> 'set-theme', :$message, :$theme, :$user is cookie, :$token is cookie {

    my $date = DateTime.now.later(years => 100);

    set-cookie 'theme', $theme, http-only => True, expires => $date;

    redirect :see-other, "{http-root()}/?message=theme set to {$theme}";

  }

  #
  # Authentication methods
  #
  
  get -> 'login' {
    redirect :see-other,
      "https://github.com/login/oauth/authorize?client_id={%*ENV<OAUTH_CLIENT_ID>}&state={%*ENV<OAUTH_STATE>}"
  }

  post -> 'logout', :$user is cookie, :$token is cookie {

    set-cookie 'user', Nil;
    set-cookie 'token', Nil;

    if ( $user && $token && "{cache-root()}/users/{$user}/tokens/{$token}".IO ~~ :e ) {

      unlink "{cache-root()}/users/{$user}/tokens/{$token}";
      say "unlink user token - {cache-root()}/users/{$user}/tokens/{$token}";

      if ( $user && $token && "{cache-root()}/users/{$user}/meta.json".IO ~~ :e ) {

        unlink "{cache-root()}/users/{$user}/meta.json";
        say "unlink user meta - {cache-root()}/users/{$user}/meta.json";

      }

    }
    redirect :see-other, "{http-root()}/?message=user logged out";
  } 

  post -> 'chgpass', :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {
    if check-user($user, $token) == True {
      my $password_param;
      request-body -> (:$password) {
        $password_param = $password;
        say "change password user: $user";
      }
      if get-user($user) {
        update-user(:login($user), :password($password_param));
      } else {
        insert-user(:login($user), :password($password_param),:description<user>)
      }
      redirect :see-other, "{http-root()}/account?message=password changed";
    } else {
        redirect :see-other, "{http-root()}/login-page?message=you need to sign in to change password"; 
    }
  }

  get -> 'oauth2', :$state, :$code {

      say "request token from https://github.com/login/oauth/access_token";

      my $resp = await Cro::HTTP::Client.get: 'https://github.com/login/oauth/access_token',
        headers => [
          "Accept" => "application/json"
        ],
        query => { 
          redirect_uri => "https://ci.sparrowhub.io/oauth2",
          client_id => %*ENV<OAUTH_CLIENT_ID>,
          client_secret => %*ENV<OAUTH_CLIENT_SECRET>,
          code => $code,
          state => $state,    
        };


      my $data = await $resp.body-text();

      my %data = from-json($data);

      say "response recieved - {%data.perl} ... ";

      if %data<access_token>:exists {

        say "token recieved - {%data<access_token>} ... ";

        my $resp = await Cro::HTTP::Client.get: 'https://api.github.com/user',
          headers => [
            "Accept" => "application/vnd.github.v3+json",
            "Authorization" => "token {%data<access_token>}"
          ];

        my $data2 = await $resp.body-text();
  
        my %data2 = from-json($data2);

        %data2<access_token> = %data<access_token>;

        say "set user login to {%data2<login>}";

        my $date = DateTime.now.later(years => 100);

        set-cookie 'user', %data2<login>, http-only => True, expires => $date;

        set-cookie 'token', user-create-account(%data2<login>,%data2), http-only => True, expires => $date;

        redirect :see-other, "{http-root()}/?message=user logged in";

      } else {

        redirect :see-other, "{http-root()}/?message=issues with login";

      }
      
  }

  get -> 'login-page', :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {

    template 'templates/login-page.crotmp', {
      page-title => "Login page",
      title => title(),
      http-root => http-root(),
      message => $message || "sign in using your github account",
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    }
  }

  get -> 'login-page2', :$message, :$user is cookie, :$token is cookie, :$theme is cookie = default-theme() {

    template 'templates/login-page2.crotmp', {
      page-title => "Login page",
      title => title(),
      http-root => http-root(),
      message => $message || "sign in using your credentials",
      css => css($theme),
      theme => $theme,
      navbar => navbar($user, $token, $theme),
    }
  }

  post -> 'login' {
    my $user; my $password_param; my $create_param;
    request-body -> (:$login,:$password,:$create) {
      $user = $login;
      $password_param = $password;
      $create_param = $create;
      my $masked_password = $password ?? "*" x $password.chars !! "";
      say "login user: $user, create: {$create || 'off'}, password: {$masked_password}";
    }

    my $user-acc = get-user($user);
    my $password_param_enc;
    if $user-acc {
      say "account exists";
      $password_param_enc = sha1-hex("{$user-acc<salt>}{$password_param}")
    } else {
      say "account does not exist"
    }

    if !$user-acc and is-admin-login($user) and $password_param eq conf-admin-password()  {

      say "(1) login user: $user - OK";

      say "set user login to {$user}";

      set-cookie 'user', $user;

      set-cookie 'token', user-create-account($user);

      redirect :see-other, "{http-root()}/?message=user successfully logged in";

    } elsif $user-acc and $user-acc<password> eq $password_param_enc {

      say "(2) login user: $user - OK";

      say "set user login to {$user}";

      set-cookie 'user', $user;

      set-cookie 'token', user-create-account($user);

      redirect :see-other, "{http-root()}/?message=user successfully logged in";

    } elsif $user-acc and $user-acc<password> ne $password_param {

        say "(3) login user: $user - FAIL";
        redirect :see-other, "{http-root()}/login-page2?message=bad credentials"; 

    } elsif !$user-acc and $create_param and $password_param {

      say "create user: $user ...";

      if $user ~~ /^^ <[ a .. z A .. Z 0 .. 9 _ ]>+ $$/ {

        insert-user(:login($user), :password($password_param),:description<user>);

        say "(4) login user: $user - OK";

        say "set user login to {$user}";

        set-cookie 'user', $user;

        set-cookie 'token', user-create-account($user);

        redirect :see-other, "{http-root()}/?message=user successfully created and logged in";

      } else {
        redirect :see-other, "{http-root()}/login-page2?message=bad login";
      }  

    }  else {

        say "(5) login user: $user - FAIL";

        redirect :see-other, "{http-root()}/login-page2?message=bad credentials"; 
    }
  }

}

(.out-buffer = False for $*OUT, $*ERR);

my Cro::Service $service = Cro::HTTP::Server.new:
    :host<127.0.0.1>, :port<2222>, :$application;

$service.start;

react whenever signal(SIGINT) {
    $service.stop;
    exit;
}

