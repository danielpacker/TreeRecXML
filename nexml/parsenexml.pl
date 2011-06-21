use Bio::TreeIO;
use strict;
use warnings; 

my $fn = $ARGV[0] || './examples/trees.xml';

print "Opening '$fn'\n";
die "'$fn' not found!" if (! -e $fn);

my $in = Bio::TreeIO->new(-file => $fn, -format => 'Nexml');

use Data::Dumper;

while( my $tree = $in->next_tree ) {
    print "read a tree...\n";
    my @taxa = $tree->get_leaf_nodes;
    print Dumper \@taxa;
    print "taxa: @taxa\n";
    my $root = $tree->get_root_node;
    print "root: $root\n";
    my $total_length = $tree->total_branch_length;
    print "total length: $total_length\n";
}
