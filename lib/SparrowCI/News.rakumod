unit module SparrowCI::News;
  
use SparrowCI::DB;

sub get-news ($limit=10) is export {

    my $dbh = get-dbh();

    my $sth = $dbh.prepare(q:to/STATEMENT/);
        SELECT 
          url,
          title, 
          dt as date
        FROM 
          news
        ORDER BY
          id desc
        LIMIT ?
    STATEMENT

    $sth.execute($limit);

    my @rows = $sth.allrows(:array-of-hash);

    $sth.finish;

    $dbh.dispose;

    return @rows;
}
