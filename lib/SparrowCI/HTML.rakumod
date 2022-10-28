unit module SparrowCI::HTML;

use SparrowCI::Conf;
use SparrowCI::Security;

sub css (Mu $theme) is export {

  my %conf = get-sparrowci-conf();

  my $bulma-theme ;

  if $theme eq "dark" {

    if %conf<ui> && %conf<ui><theme><dark> {
      $bulma-theme = %conf<ui><theme><dark>
    } else {
      $bulma-theme = "nuclear";
    }

  } elsif $theme eq "light" {

    if %conf<ui> && %conf<ui><theme><light> {
      $bulma-theme = %conf<ui><theme><light>
    } else {
      $bulma-theme = "materia";
    }

  } else {

    $bulma-theme = "materia";

  }

  qq:to /HERE/
  <meta charset="utf-8">
  <link rel="stylesheet" href="https://unpkg.com/bulmaswatch/$bulma-theme/bulmaswatch.min.css">
  <script defer src="https://use.fontawesome.com/releases/v5.14.0/js/all.js"></script>
  <script src="{http-root()}/js/misc.js"></script>
  <link href="{http-root()}/css/prism-{$theme}.css" rel="stylesheet" />
  <script src="{http-root()}/js/prism-{$theme}.js"></script>
  HERE

}

sub login-logout (Mu $user, Mu $token) {

  if check-user($user,$token) == True {

    "<a class=\"navbar-item\" href=\"{http-root()}/logout?q=123\">
      Log out
    </a>"

  } else {

    "<a class=\"navbar-item\" href=\"{http-root()}/login-page?q=123\">
      Log In
    </a>"
  }

}

sub theme-link (Mu $theme) {

  if $theme eq "light" {

    "<a class=\"navbar-item\" href=\"{http-root()}/set-theme?theme=dark\">
      Dark Theme
    </a>"

  } else {

    "<a class=\"navbar-item\" href=\"{http-root()}/set-theme?theme=light\">
      Light Theme
    </a>"

  }

}

sub mybuilds (Mu $user, Mu $token) {

  if check-user($user,$token) == True {
    "<a class=\"navbar-item\" href=\"{http-root()}/$user/builds\">My builds</a>"
  } else {
    ""
  }
}

sub navbar (Mu $user, Mu $token, Mu $theme) is export {
  qq:to /HERE/
      <nav class="navbar" role="navigation" aria-label="main navigation">
        <div class="navbar-brand">
          <a role="button" class="navbar-burger" aria-label="menu" aria-expanded="false" data-target="navbarBasicExample">
            <span aria-hidden="true"></span>
            <span aria-hidden="true"></span>
            <span aria-hidden="true"></span>
          </a>
          <div id="navbarBasicExample" class="navbar-menu"> 
            <div class="navbar-start">
              <a class="navbar-item" href="{http-root()}/">Home</a>
              <a class="navbar-item"href="{http-root()}/quickstart">Quick start</a>
              <a class="navbar-item" href="{http-root()}/all">All builds</a>
              {mybuilds($user,$token)}
              <a class="navbar-item" href="{http-root()}/repos">My repos</a>
              <a class="navbar-item"href="{http-root()}/donations">Donations</a>
              <div class="navbar-item has-dropdown is-hoverable">
                <a class="navbar-link">
                  More
                </a>
                <div class="navbar-dropdown">
                  {login-logout($user, $token)}
                  {theme-link($theme)}
                  <a class="navbar-item" href="https://github.com/melezhik/SparrowCI" target="_blank">Github</a>
                  <hr class="navbar-divider">
                  <a class="navbar-item" href="https://sparky.sparrowhub.io">Workers</a>
                </div>
              </div>      
            </div>  
          </div>
        </div>
      </nav>
  HERE

}

