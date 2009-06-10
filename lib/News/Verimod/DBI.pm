$VERSION = "1.1";
package News::Verimod::DBI;
our $VERSION = "1.1";

# -*- Perl -*-			Wed Aug 18 11:15:30 CDT 2004 
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>.  Copyright 1995-2004,
# Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

=head1 SYNOPSIS

=head1 DESCRIPTION

=over 4

=back

See each table's documentation for more information.

=cut

use strict;
use vars qw(@ISA @PROBS @MODULES $SERVER $DATABASE $DBTYPE $USER $PASS $DEBUG );

###############################################################################
### User Variables ############################################################
###############################################################################
@MODULES  = qw( DBIx::Frame Exporter News::Verimod::DBI::Functions 
		News::Verimod::DBI::Article News::Verimod::DBI::HeaderLog );
@ISA      = qw( DBIx::Frame Exporter );
$SERVER   = "db.ks.uiuc.edu";                        # Default web server
$DATABASE = "Verimod";
$DBTYPE   = "mysql";
$USER     = "rgm";
$PASS     = "forest";
$DEBUG    = 0;

###############################################################################
### main() ####################################################################
###############################################################################
foreach ( @MODULES ) { local $@; eval "use $_"; push @PROBS, "$@" if $@; }
die @PROBS if scalar @PROBS;

# Initialize DBIx::Frame (this has already been done a few times, but this
#   allows us to have a definite known state to finish with)
DBIx::Frame->init($SERVER, $DBTYPE, $DATABASE, $USER, $PASS, $SERVER);
###############################################################################

=head1 NOTES

=head1 REQUIREMENTS

=head1 SEE ALSO

=head1 AUTHOR

=head1 HOMEPAGE

=head1 LICENSE

=head1 COPYRIGHT

=cut

###############################################################################
### Version History ###########################################################
###############################################################################

