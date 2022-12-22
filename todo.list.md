# task names with spaces

If task names have spaces this will lead
to project names with space that in turn lead
to report URL error. For example:

task name - "zef build"

report URL - http://127.0.0.1:4000/report/zef%20build/483 - 404

# use JSON instead of Raku for config files

Using of Raku leads to `Unsupported use of ${})` error
in case of emtpy tasks data

 
