unit module SparrowCI::DB;
use YAMLish;
use DBIish;
use JSON::Fast;
use SparrowCI::Conf;

sub get-dbh {

  my $dbh;

  my %conf = get-sparrowci-conf();

  if %conf<database> && %conf<database><engine> && %conf<database><engine> !~~ / :i sqlite / {

    $dbh  = DBIish.connect(
        %conf<database><engine>,
        host      => %conf<database><host>,
        port      => %conf<database><port>,
        database  => %conf<database><name>,
        user      => %conf<database><user>,
        password  => %conf<database><pass>,
    );

  } else {

    my $db-name = "{sparrowci-root}/db.sqlite3";

    $dbh  = DBIish.connect("SQLite", database => $db-name );

  }

  return $dbh;

}


sub insert-build (:$state, :$project, :$image, :$desc, :$job-id ) is export {

    my $dbh = get-dbh();

    my $sth = $dbh.prepare(q:to/STATEMENT/);
      INSERT INTO builds (project, state, image, description, job_id)
      VALUES ( ?,?,?,? )
    STATEMENT

    $sth.execute($project, $state, $image, $desc, $job-id);

    $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT max(ID) AS build_id
        FROM builds where job_id = ? 
        STATEMENT

    $sth.execute($job-id);

    my @rows = $sth.allrows();

    my $build_id = @rows[0][0];

    $sth.finish;

    $dbh.dispose;

    return $build_id;

}

sub get-builds ($limit=10, $user?) is export {

    my $dbh = get-dbh();

    my $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT 
          project, 
          CASE
            WHEN state = 1 THEN "OK"
            WHEN state = -1 THEN "TIMEOUT"
            WHEN state = -2 THEN "FAIL"
            ELSE "UNKNOWN"
          END AS state,
          dt as date, id
        FROM 
          builds
        ORDER BY
          id desc
        LIMIT ?
    STATEMENT

    $sth.execute($limit);

    my @rows = $sth.allrows(:array-of-hash);

    $sth.finish;

    $dbh.dispose;

    if $user {
     return @rows.grep({.<project> ~~  / ( git || gh ) '-'  $user '-' / });
    } else {
     return @rows;
    }
 
}

sub get-last-build ($project) is export {

    my $dbh = get-dbh();

    my $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT 
          project, 
          CASE
            WHEN state = 1 THEN "OK"
            WHEN state = -1 THEN "TIMEOUT"
            WHEN state = -2 THEN "FAIL"
            ELSE "UNKNOWN"
          END AS state,
          dt as date, id
        FROM 
          builds
        WHERE
          project = ?
        ORDER BY
          id desc
        LIMIT 1  
    STATEMENT

    $sth.execute($project);

    my @rows = $sth.allrows(:array-of-hash);

    $sth.finish;

    $dbh.dispose;

    return @rows[0];
 
}

sub get-report ($id) is export {

  if "{sparrowci-root()}/data/{$id}/data.json".IO ~~ :e {
    my $r = from-json("{sparrowci-root()}/data/{$id}/data.json".IO.slurp);
    if $r<state> == 1 {
      $r<state> = "OK"
    } elsif $r<state> == -1 {
      $r<state> = "TIMEOUT"
    } elsif $r<state> == -2  {
      $r<state> = "FAIL"
    }
    $r<date> = DateTime.new(
      $r<date>,
      formatter => {
          sprintf '%02d.%02d.%04d @ %02d:%02d', 
          .day, .month, .year, .hour, .minute
      }
    ).Str;
    return $r;
  } else {
    return {}
  }
}
