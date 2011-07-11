use strict;
use warnings;

use Data::Dumper;
use Bio::Phylo::NeXML::DOM;
use Bio::Phylo::IO qw(parse unparse);


my $infile = $ARGV[0] || "tr_nexml_test02.xml";

Bio::Phylo::NeXML::DOM->new();

my $blocks = parse(
	'-file'       => $infile,
	'-format'     => 'nexml',
	#'-as_project' => 1,
);

#print "PROJECT:\n"; print Dumper $project;
#
#my $document = $project->get_document;
#
## print "DOCUMENT:\n"; print Dumper $document;
#
## get meta tags in document
#
#my @meta = @{ $project->get_meta };
#
#print "METAS: " . Dumper \@meta;
#
#exit;

print "BLOCKS: " . Dumper $blocks;

for my $block ( @{$blocks} ) {
	if ( $block->isa('Bio::Phylo::Taxa') ) {
		my $taxa = $block;

		my $num_taxa = $taxa->get_ntax;
		print STDERR "NUM TAXA: " . $num_taxa . "\n";

		# do something with the taxa
	}
	elsif ( $block->isa('Bio::Phylo::Forest') ) {
		my $forest = $block;

		print STDERR "-- Displaying metadata --\n";
			display_nested_meta($forest);
			print STDERR "-- end of metadata --\n";
			
		my $tree_num = 0;
		
		foreach my $tree ( @{ $forest->get_entities } ) {
			$tree_num++;

			print STDERR "\n\nEvaluating Tree $tree_num \n";

			print STDERR "-- Displaying metadata --\n";
			display_nested_meta($tree);
			print STDERR "-- end of metadata --\n";

			my $num_nodes = $tree->calc_number_of_nodes;
			print STDERR "NUM NODES: " . $num_nodes . "\n";

			my $tree_name = $tree->get_name;
			if ($tree_name) {
				print STDERR "TREE NAME: " . $tree_name . "\n";
			}

			my $tree_id = $tree->get('get_id');
			print STDERR "Tree ID: " . $tree_id . "\n";

			foreach my $node ( @{ $tree->get_entities } ) {

				# NODE ID AS USED BY Bio::Phylo
				my $node_id = $node->get_id;
				print STDERR "\tID: " . $node_id . "\n";

				# We can get the node parent with get_parent
				# this returns a Bio::Phylo::Forest::Node object
				my $node_parent = $node->get_parent;

				# We can also get information about the branch
				# length if it is available
				my $branch_length = $node->get_branch_length;
				if ($branch_length) {
					print STDERR "\tBranch Length: " . $branch_length . "\n";
				}

				foreach my $node_properties ( @{ $node->get_entities } ) {
					print STDERR "\t" . $node_properties . "\n";
				}    # End of for each node_property

				# Get meta data for the nodes
				display_nested_meta($node);

			}    # End of getting nodes with tree->get_entities

		}

	}    # End of if block is a forest

}

sub display_nested_meta {
	my $obj = shift or die "No object provided!";
	my $lvl = shift || 0;    # indentation level

	if ( my $metadata = $obj->get_meta() ) {

		foreach my $meta ( @{$metadata} ) {
            my $pred = $meta->get_predicate || '';
            my $obj  = $meta->get_object || '';
			print STDERR "    " x $lvl;
			print STDERR "    " . $pred . " --> " . $obj . "\n";
			if ( scalar( @{ $meta->get_meta() } ) ) {
				display_nested_meta ( $meta, ++$lvl );
			}
		}
	}
}

exit;

