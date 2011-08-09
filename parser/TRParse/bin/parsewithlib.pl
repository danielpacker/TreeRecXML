use warnings;
use strict;

use lib '../lib';

use Bio::TRParse;

my $TRobject = Bio::TRParse->new();

my $filename = $ARGV[0] or die "usage: program filename.xml";

die "$filename does not exist" unless (-e $filename);

$TRobject->load(
     'source' => $filename,
     'format' => 'nexml'
);

print $TRobject->dump();

print "done";

exit;