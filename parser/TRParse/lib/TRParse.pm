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
    die "'$filename' not found." unless (-e $filename);

    #Bio::Phylo::NeXML::DOM->new();

    my $blocks = parse(
        '-file'   => $filename,
        '-format' => 'nexml',
    );

    for my $block ( @{$blocks} ) {
        if ( $block->isa('Bio::Phylo::Taxa') ) {
            my $taxa = $block;

            my $num_taxa = $taxa->get_ntax;
            #print STDERR "NUM TAXA: " . $num_taxa . "\n";

            # do something with the taxa
        }
        elsif ( $block->isa('Bio::Phylo::Forest') ) {
            my $forest = $block;

            #print STDERR "-- Displaying metadata --\n";
            my $recs = $self->extract_reconciliations($forest);
            #print STDERR "-- end of metadata --\n";

print "RECS: " . Dumper $recs;
return $recs;


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

# Returns arrayref of Reconciliations objects populated via bio::phylo forest
sub extract_reconciliations {
    my $self = shift;
    my $obj  = shift or die "No object provided!";
    my $lvl  = shift || 0;                           # indentation level

    my @recs = (); # return the reconciliation objects
    
    if ( my $metadata = $obj->get_meta('tron:reconciliations') ) {

        foreach my $meta ( @{$metadata} ) {
            my $pred = $meta->get_predicate || '';
            my $obj  = $meta->get_object    || '';
            
            if ($pred eq 'tron:reconciliations') {
                
                my $recs = $meta->get_meta();
                
                for my $rec (@$recs) {
                   my $pred = $rec->get_predicate || '';
                   my $rec_metas = $rec->get_meta();
                   
                   # create new reconciliation object
                   my $rec_obj = Reconciliation->new();
                       
                   # extract reconciliation properties
                   for my $rec_meta (@$rec_metas) {
                       my $rm_pred = $rec_meta->get_predicate || '';
                       my $rm_obj = $rec_meta->get_object || '';
                       #print "[$rm_pred -> $rm_obj]\n";
                       
                       if      ($rm_pred eq 'tron:reconciliation_id') {
                           $rec_obj->id($rm_obj);
                       } elsif ($rm_pred eq 'tron:host_tree_id') {
                           $rec_obj->host_tree($rm_obj);
                       } elsif ($rm_pred eq 'tron:guest_tree_id') {
                            $rec_obj->guest_tree($rm_obj);
                       } elsif ($rm_pred eq 'tron:reconciliation_method') {
                           my $rec_method_metas = $rec_meta->get_meta();
                           for my $rec_method_meta (@$rec_method_metas) {
                               if ($rec_method_meta->get_predicate eq 'tron:reconciliation_software') {
                                   $rec_obj->method( 'software' => $rec_method_meta->get_object );
                               }
                           }
                       }
                       
                       
                   }
                   
                   # save the reconciliation object
                   push @recs, $rec_obj;
                }
            }
        }
    }
    
    return \@recs;
}


1;

package Reconciliation;

sub new {

    my $class = shift;
    my $self  = {
        'id'         => undef,
        'host_tree'  => undef,
        'guest_tree' => undef,
        'method'     => { 'software' => {} },
        
    };
    bless $self, $class;
    return $self;
}

# if valid method, write method
sub method {
    my $self             = shift;
    my @valid_properties = qw/software/;

    if ( my %properties = @_ ) {
        for my $p (keys %properties) {
            if ( grep $p, @valid_properties ) {
                    $self->{$p} = $properties{p};
            }
        }
    }
    else {
        return $self->{'method'};
    }
}

sub id {
    my $self = shift;
    my $id = shift;
    if (defined($id)) {
        $self->{'id'} = $id;
    }
    else {
        return $self->{'id'};
    }
}

sub host_tree {
    my $self = shift;
    if (my $tree_id = shift) {
        $self->{'host_tree'} = $tree_id;
    }
    else {
        return $self->{'host_tree'};
    }
}


sub guest_tree {
    my $self = shift;
    if (my $tree_id = shift) {
        $self->{'guest_tree'} = $tree_id;
    }
    else {
        return $self->{'guest_tree'};
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
