use strict;
use warnings;

use Bio::Phylo;
use Bio::NexmlIO;

my $fn = $ARGV[0] || './examples/trees.xml';
print "Opening '$fn'\n";
die "'$fn' not found!" if (! -e $fn);

my $in_nexml = Bio::NexmlIO->new(-file => $fn, -format => 'Nexml');

#Read in some data
while( my $tree = $in_nexml->next_tree ) {
print "read a tree...\n";
my @taxa = $tree->get_leaf_nodes;
print Dumper \@taxa;
print "taxa: @taxa\n";
my @nodes = $tree->get_nodes;
print Dumper \@nodes;
print "nodes: @nodes\n";
my $root = $tree->get_root_node;
print "root: $root\n";
my $total_length = $tree->total_branch_length;
print "total length: $total_length\n";
}
my $bpaln1  = $in_nexml->next_aln();
my $bpseq1  = $in_nexml->next_seq();

