package TRParse;

use 5.006;
use strict;
use warnings;

use Data::Dumper;
use Bio::Phylo::NeXML::DOM;
use Bio::Phylo::IO qw(parse unparse);

=head1 NAME

TRParse - The great new TRParse!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use TRParse;

    my $foo = TRParse->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {

    my $class = shift;
    my $self  = {
        'reconciliations' => [],
        'host_trees'      => [],
        'guest_trees'     => [],
    };
    bless $self, $class;
    return $self;
}

sub read_nexml {
    my $self = shift;
    my $filename = shift or die "No filename provided.";

    #Bio::Phylo::NeXML::DOM->new();

    my $blocks = parse(
        '-file'   => $filename,
        '-format' => 'nexml',
    );

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
            $self->display_nested_meta($forest);
            print STDERR "-- end of metadata --\n";

            my $tree_num = 0;

            foreach my $tree ( @{ $forest->get_entities } ) {
                $tree_num++;

                print STDERR "\n\nEvaluating Tree $tree_num \n";

                print STDERR "-- Displaying metadata --\n";
                $self->display_nested_meta($tree);
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
                        print STDERR "\tBranch Length: "
                          . $branch_length . "\n";
                    }

                    foreach my $node_properties ( @{ $node->get_entities } ) {
                        print STDERR "\t" . $node_properties . "\n";
                    }    # End of for each node_property

                    # Get meta data for the nodes
                    $self->display_nested_meta($node);

                }    # End of getting nodes with tree->get_entities

            }

        }    # End of if block is a forest

    }
}

sub display_nested_meta {
    my $self = shift;
    my $obj  = shift or die "No object provided!";
    my $lvl  = shift || 0;                           # indentation level

    if ( my $metadata = $obj->get_meta() ) {

        foreach my $meta ( @{$metadata} ) {
            my $pred = $meta->get_predicate || '';
            my $obj  = $meta->get_object    || '';
            print STDERR "    " x $lvl;
            print STDERR "    " . $pred . " --> " . $obj . "\n";
            if ( scalar( @{ $meta->get_meta() } ) ) {
                $self->display_nested_meta( $meta, ++$lvl );
            }
        }
    }
}



1;

package Reconciliation;

sub new {

    my $class = shift;
    my $self  = {
        'method'     => '',
        'host_tree'  => undef,
        'guest_tree' => undef,
    };
    bless $self, $class;
    return $self;
}

# if valid method, write method
sub method {
    my $self             = shift;
    my @valid_methods    = qw/TREEBEST/;
    my @valid_properties = qw/software/;

    if ( my %properties = shift ) {

        # method is a hash of properties

        for my $p (@valid_properties) {
            if ( exists $properties{$p} ) {
                if ( grep /$p/i, @valid_properties ) {
                    $self->{'method'} = $properties{$p};
                }
            }
        }
    }
    else {
        return $self->{'method'};
    }
}

1;

=head1 AUTHOR

"Daniel Packer", C<< <"dp at danielpacker.org"> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-trparse at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=TRParse>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc TRParse


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=TRParse>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/TRParse>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/TRParse>

=item * Search CPAN

L<http://search.cpan.org/dist/TRParse/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 "Daniel Packer".

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of TRParse
