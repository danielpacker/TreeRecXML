package Bio::TRParse;

use 5.006;
use strict;
use warnings;

use Data::Dumper;
use Bio::Phylo::NeXML::DOM;
use Bio::Phylo::IO qw(parse unparse);

use DBI;

use constant DB_DSN  => 
    'DBI:mysql:database=' . ( $ENV{'TRDB_DB'} || 'trdb' ) . 
    ';host=' . ( $ENV{'TRDB_HOST'} || 'localhost' );
use constant DB_USER => $ENV{'TRDB_USER'} || 'root';
use constant DB_PASS => $ENV{'TRDB_PASS'} || 'root';
    
=head1 NAME

TRParse - A module for interoperable gene tree reconciliation maps

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Read and write reconciled gene and species trees in NeXML.

use Bio::TRParse;

my $TRobject = Bio::TRParse->new();

$TRobject->load(
     'source' => 'myfile.xml',
     'format' => 'nexml'
);

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
        'dbi_connection'  => undef,
    };
    bless $self, $class;
    return $self;
}

sub load {
    my $self = shift;
    my %args = @_;
    
    # clear existing loaded data
    $self->{'reconciliations'} = [];
    $self->{'host_trees'} = [];
    $self->{'guest_trees'} = [];
    
    if (exists $args{'source'}) {
        if (exists $args{'format'}) {
            if ($args{'format'} eq 'nexml') {
                $self->load_from_nexml($args{'source'});
             }
             elsif ($args{'format'} eq 'nhx') {
                 $self->load_from_nhx($args{'source'});
             }
             elsif ($args{'format'} eq 'prime') {
                 $self->load_from_prime($args{'source'});
             }
             elsif ($args{'format'} eq 'iplant') {
                 $self->load_from_iplant(@{ $args{'source'} });
             }
        }
    }
    else {
        die "load must be provided a source argument";
    }
}

sub load_from_nhx {
    my $self = shift;
}

sub load_from_prime {
    my $self = shift;
}

sub load_from_iplant {
    my $self = shift;
    
    my $species_tree_label = shift or die "missing arg";
    my $gene_tree_stable_id = shift or die "missing arg";
    
    # establish database handle if none exists:
    unless (defined $self->{'dbi'}) {
        $self->{'dbi'} = DBI->connect(DB_DSN, DB_USER, DB_PASS)
            or die "Database connection failed: $!"
    };
    
    $self->{'dbh'}->{'RaiseError'} = 1;
    
    # first we'll find the reconciliation between gene_tree and species_tree
    my $check_family_tree_exists_sql =
    'SELECT protein_tree.protein_tree_id, protein_tree.root_node_id FROM reconciliation
        LEFT JOIN protein_tree USING(protein_tree_id)
            LEFT JOIN family USING(family_id)
                WHERE family.stable_id = ?';
                
    my @protein_tree_info = $self->{'dbi'}->selectrow_array(
        $check_family_tree_exists_sql, {}, $gene_tree_stable_id);
    
    # determine that the species tree is in place
    my $check_species_tree_exists_sql = 
    'SELECT species_tree_id, root_node_id FROM species_tree
        WHERE species_tree_name = ?';

    my @species_tree_info = $self->{'dbi'}->selectrow_array(
        $check_species_tree_exists_sql, {}, $species_tree_label);
                
    # get all nodes for species tree
    my $get_species_tree_nodes_sql =
    'SELECT species_tree_node_id, label, parent_id FROM species_tree_node
        WHERE species_tree_id = ?';
    
    my $species_tree_nodes = $self->{'dbi'}->selectall_arrayref(
        $get_species_tree_nodes_sql, {}, $species_tree_info[0]);
    
    # get all nodes for gene tree, while resolving gene names
    my $get_protein_tree_nodes_sql =
    'SELECT n.node_id, n.parent_id, n.root_id, member.stable_id FROM protein_tree_node AS `n`
        LEFT JOIN protein_tree_member USING(node_id)
            LEFT JOIN member USING(member_id)
                WHERE protein_tree_id = ?';
            
    my $protein_tree_nodes = $self->{'dbi'}->selectall_arrayref(
        $get_protein_tree_nodes_sql, {}, $protein_tree_info[0]);    
                
#    for my $row (@$species_tree_nodes) {
#            print "@{$row} \n" if @$row;
#    }    
#    use Data::Dumper;
#    print "@protein_tree_info"
#    . "---\n" .
#    "@species_tree_info"
#    . "---\n" .
#    Dumper $species_tree_nodes
#    . "---\n" .
#    Dumper $protein_tree_nodes;

}

sub load_from_nexml {
    my $self = shift;
    my $filename = shift or die "No filename provided.";
    die "'$filename' not found." unless ( -e $filename );

    my $blocks = parse(
        '-file'   => $filename,
        '-format' => 'nexml',
    );

    for my $block ( @{$blocks} ) {
        if ( $block->isa('Bio::Phylo::Taxa') ) {
            my $taxa = $block;
            my $num_taxa = $taxa->get_ntax;
        }
        elsif ( $block->isa('Bio::Phylo::Forest') ) {
            my $forest = $block;

            # Extract reconciliation meta data
            my $recs = $self->extract_reconciliations_from_nexml($forest);

            #print "RECS: " . Dumper $recs;
            $self->{'reconciliations'} = $recs;
            
            my $trees = $self->extract_trees_from_nexml($forest);
            $self->{'guest_trees'} = $trees->{'guest_trees'};
            $self->{'host_trees'}  = $trees->{'host_trees'};
        }
    }
}

# Return the host and guest trees from the forest
sub extract_trees_from_nexml {
    my $self = shift;
    my $forest = shift or die "No forest provided!";

    print "\n----\n";
         
    my @guest_trees = ();
    my @host_trees = ();
         
    foreach my $tree ( @{ $forest->get_entities } ) {
    
        my $TRtree = Bio::TRParse::Reconciliation::Tree->new();
    
        my ($tree_name, $tree_id) = ($tree->get_name, $tree->get_xml_id);
        
        print "Processing $tree_id ('$tree_name'):\n";
        # access nodes in $tree
    
        my @tree_nodes = @{ $tree->get_entities };
        
        print "Found " . scalar(@tree_nodes) . " nodes in tree.\n";
        
        my $is_guest = 0;   # is tree a guest or host?
        
        foreach my $node ( @tree_nodes ) {
            
            my $TRnode = Bio::TRParse::Reconciliation::Tree::Node->new();
            
            my ($node_name, $node_id) = ($node->get_name, $node->get_xml_id);
            print "Node: $node_id ('$node_name'): " . ref($node) . "\n";
            
            # If there's a reconciliation node_id, then this is a reconciled node
            if (my $tron_rec_node_id = $node->get_meta('tron:reconciliation_node_id')) {
                
                # If this tree has a reconciled node, it's probably a guest tree!
                $is_guest = 1;
                
                $TRnode->{'metadata'}->{'tron:reconciliation_node_id'} = $tron_rec_node_id;
                for (qw/host_node_parent host_node_child guest_node_type/) {
                    $TRnode->{'metadata'}->{'tron:'.$_} = $node->get_meta('tron:'.$_);
                }
            }
            $TRtree->add_node($node);
        }
                
        # Add tree to appropriate array
        if ($is_guest) {
            push @guest_trees, $TRtree;
        } else {
            push @host_trees, $TRtree;
        }
        
    }
    
    print "\n----\n";
    
    my %trees_final = (
      'guest trees' => [@guest_trees],
      'host_trees'  => [@host_trees]  
    );
    
    print Dumper \%trees_final;
    
    return \%trees_final;
}


# Returns arrayref of Reconciliations objects populated via bio::phylo forest
sub extract_reconciliations_from_nexml {
    my $self = shift;
    my $obj  = shift or die "No object provided!";
    
    my @recs = ();    # return the reconciliation objects

    if ( my $metadata = $obj->get_meta('tron:reconciliations') ) {

        foreach my $meta ( @{$metadata} ) {
            my $pred = $meta->get_predicate || '';
            my $obj  = $meta->get_object    || '';

            if ( $pred eq 'tron:reconciliations' ) {

                my $recs = $meta->get_meta();

                for my $rec (@$recs) {
                    my $pred = $rec->get_predicate || '';
                    my $rec_metas = $rec->get_meta();

                    # create new reconciliation object
                    my $rec_obj = Bio::TRParse::Reconciliation->new();

                    # extract reconciliation properties
                    for my $rec_meta (@$rec_metas) {
                        my $rm_pred = $rec_meta->get_predicate || '';
                        my $rm_obj  = $rec_meta->get_object    || '';
                        
                        # set appropriate reconcilation property
                        if ( $rm_pred eq 'tron:reconciliation_id' ) {
                            $rec_obj->id($rm_obj);
                        }
                        elsif ( $rm_pred eq 'tron:host_tree_id' ) {
                            $rec_obj->host_tree($rm_obj);
                        }
                        elsif ( $rm_pred eq 'tron:guest_tree_id' ) {
                            $rec_obj->guest_tree($rm_obj);
                        }
                        elsif ( $rm_pred eq 'tron:reconciliation_method' ) {
                            my $rec_method_metas = $rec_meta->get_meta();
                            for my $rec_method_meta (@$rec_method_metas) {
                                if ( $rec_method_meta->get_predicate eq
                                    'tron:reconciliation_software' )
                                {
                                    $rec_obj->method( 'software' =>
                                          $rec_method_meta->get_object );
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

# Display nested meta tags (if there are any) on a tree node
sub display_nested_meta_in_nexml {
    my $self = shift;
    my $obj  = shift or die "No object provided!";
    my $lvl  = shift || 0;  # indentation level

    if ( my $metadata = $obj->get_meta() ) {

        foreach my $meta ( @{$metadata} ) {
            my $pred = $meta->get_predicate || '';
            my $obj  = $meta->get_object    || '';
            print STDERR "    " x $lvl;
            print STDERR "    " . $pred . " --> " . $obj . "\n";
            if ( scalar( @{ $meta->get_meta() } ) ) {
                $self->display_nested_meta_in_nexml( $meta, ++$lvl );
            }
        }
    }
}

# Show everything in the object
sub dump {
    my $self = shift;
    use Data::Dumper;
    return Dumper $self;
}



# The object
package Bio::TRParse::Reconciliation;

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
        for my $p ( keys %properties ) {
            if ( grep $p, @valid_properties ) {
                $self->{'method'}->{$p} = $properties{$p};
            }
        }
    }
    else {
        return $self->{'method'};
    }
}

sub id {
    my $self = shift;
    my $id   = shift;
    if ( defined($id) ) {
        $self->{'id'} = $id;
    }
    else {
        return $self->{'id'};
    }
}

sub host_tree {
    my $self = shift;
    if ( my $tree_id = shift ) {
        $self->{'host_tree'} = $tree_id;
    }
    else {
        return $self->{'host_tree'};
    }
}

sub guest_tree {
    my $self = shift;
    if ( my $tree_id = shift ) {
        $self->{'guest_tree'} = $tree_id;
    }
    else {
        return $self->{'guest_tree'};
    }
}



package Bio::TRParse::Reconciliation::Tree;

sub new {

    my $class = shift;
    my %args = @_;
    
    my $self  = {
        'tree_id'      => undef,
        'label'        => undef,
        'root_node_id' => undef,
        'nodes'        => [],
    };
    
    for (keys %$self) {
        defined($args{$_}) && ($self->{$_} = $args{$_});
    }
    bless $self, $class;
    return $self;    
}

sub copy {
    
    my $self = shift;
    my $obj  = shift;
    
    return Bio::TRParse::Reconciliation::Tree->new(
        'tree_id'      => $obj->tree_id,
        'label'        => $obj->label,
        'root_node_id' => $obj->root_node_id,
        'nodes'        => $obj->nodes,
    );
}

sub tree_id {
    my $self = shift;
    my $id   = shift;
    if ( defined($id) ) {
        $self->{'tree_id'} = $id;
    }
    else {
        return $self->{'tree_id'};
    }
}

sub label {
    my $self  = shift;
    my $label = shift;
    if ( defined($label) ) {
        $self->{'label'} = $label;
    }
    else {
        return $self->{'label'};
    }
}

sub root_node_id {
    my $self = shift;
    my $id   = shift;
    if ( defined($id) ) {
        $self->{'root_node_id'} = $id;
    }
    else {
        return $self->{'root_node_id'};
    } 
}

sub nodes {
    my $self = shift;
    my @nodes = @_;
    
    if (scalar(@nodes)) {
        $self->{'nodes'} = [@nodes];
    }
    else {
        return $self->{'nodes'};
    }
}

sub add_node {
    my $self = shift;
    my $node = shift or die "No node provided.";
    push @{$self->{'nodes'}}, $node;
}



package Bio::TRParse::Reconciliation::Tree::Node;

sub new {

    my $class = shift;
    my %args = @_;
    
    my $self  = {
        'node_id'        => undef,
        'label'          => undef,
        'root_node_id'   => undef,
        'parent_node_id' => undef,
        'metadata'       => {},        
    };
    
    for (keys %$self) {
        defined($args{$_}) && ($self->{$_} = $args{$_});
    }
    bless $self, $class;
    return $self;    
}

sub copy {
    
    my $self = shift;
    my $obj  = shift;
    
    return Bio::TRParse::Reconciliation::Tree->new(
        'node_id'        => $obj->node_id,
        'label'          => $obj->label,
        'root_node_id'   => $obj->root_node_id,
        'parent_node_id' => $obj->parent_node_id,
        'metadata'       => %{ $obj->metadata }, 
    );
}

sub node_id {
    my $self = shift;
    my $id   = shift;
    if ( defined($id) ) {
        $self->{'node_id'} = $id;
    }
    else {
        return $self->{'node_id'};
    }
}

sub label {
    my $self  = shift;
    my $label = shift;
    if ( defined($label) ) {
        $self->{'label'} = $label;
    }
    else {
        return $self->{'label'};
    }
}

sub root_node_id {
    my $self = shift;
    my $id   = shift;
    if ( defined($id) ) {
        $self->{'root_node_id'} = $id;
    }
    else {
        return $self->{'root_node_id'};
    } 
}

sub node_id {
    my $self = shift;
    my $id   = shift;
    if ( defined($id) ) {
        $self->{'parent_node_id'} = $id;
    }
    else {
        return $self->{'parent_node_id'};
    }
}

sub metadata {
    my $self = shift;
    my %meta = @_;
    if ( scalar(keys %meta) ) {
        $self->{'metadata'} = \%meta;
    }
    else {
        return $self->{'metadata'};
    }
}

sub add_metadata {
    my $self = shift;
    my %keyval = @_;
    for (keys %keyval) {
        die "undefined term" unless (defined $keyval{$_});
        $self->{'metadata'}->{$_} = $keyval{$_};
    }
}




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
