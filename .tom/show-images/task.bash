docker images --format table \
melezhik/sparrow:*20*|\
raku -e '
 my $i;
 for lines() -> $l {
   $i++ or next;
   my @f = $l.split(/\s+/);
   say "@f[0]:@f[1]"
}' | sort -r
