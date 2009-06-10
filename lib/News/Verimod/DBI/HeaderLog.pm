$VERSION = "1.01";
package News::Verimod::DBI::HeaderLog;
our $VERSION = "1.01";

# -*- Perl -*-	Wed Aug 18 16:32:00 CDT 2004, tskirvin@killfile.org
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>.  Copyright 1995-2004,
# Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::DBI::HeaderLog - the HeaderLog table in News::Verimod::DBI

=head1 SYNOPSIS

  use News::Verimod::DBI::HeaderLog;
  
See News::Verimod::DBI for more information.

=head1 DESCRIPTION

The 'Headerlog' table is used to store basic information about all articles
that are posted through the Verimod system - header information, current
status information, etc.  

This table contains the following fields:

 Internal Information (TINYTEXT fields, unless noted)
  ID            Unique numeric ID - auto-generated (INT)
  Modified	Timestamp of last modification (auto-created TIMESTAMP)
  
 Primary Information (TINYTEXT unless noted)
  Header	Affected header; lowercase 
  Value		Value of affected header.
  Score		Score to apply to matching header/value pairs.  (INT)

Key fields:     Header, Value

List items:     Header, Value, Score

Required:       Header, Value

Default order:  ID

Admin Fields:   None

No other tables depend on this table.

Doesn't depend on any other table.

=head1 USAGE

=cut

###############################################################################
### Initialization ############################################################
###############################################################################
use vars qw( @ISA $FIELDS $KEYS $NAME $LIST $VERSION $REQUIRED $ADMIN $ORDER ); 
use strict;
use warnings;
use News::Verimod::DBI;
use CGI;
use News::Verimod::DBI::Functions qw( timestamp_print );

unshift @ISA, "News::Verimod::DBI";

###############################################################################
### Database Variables ########################################################
###############################################################################
$NAME = "HeaderLog";
$FIELDS = {
  'ID'          => 'INT NOT NULL PRIMARY KEY AUTO_INCREMENT',
  'Header'      => 'TINYTEXT NOT NULL', 'Value'       => 'TINYTEXT NOT NULL', 
  'Score'        => 'INT',              'Modified'    => 'TIMESTAMP'
	  };
$KEYS     = [ 'Header', 'Value', ];
$LIST     = [ 'Header', 'Value', 'Score' ];
$REQUIRED = [ 'Header', 'Value' ];
$ADMIN    = [];
$ORDER    = [ 'ID' ];

###############################################################################
##### Functions ###############################################################
###############################################################################

=head1 Internal Functions

=over 4

=item html ( ENTRY, TYPE, OPTIONS )

Returns the HTML necessary for database manipulation, as detailed in
DBIx::Frame::CGI.

=cut

sub html { 
  my ($self, $entry, $type, $options, @rest) = @_;
  my $cgi = new CGI; $entry ||= {}; $options ||= {};

  my $modified = $self->timestamp_print($$entry{Modified}) || "";
  my $id   = $$entry{ID} || "<i>not set</i>";

  my @return = <<HTML;
<div class="basetable">
 <div class="row2">
  <span class="label">ID</span> <span class="formw">$id</span>
  <span class="label">Modified</span> <spam class="formw">$modified</span>
 </div>

 <div class="row3">
  <span class="label">Header</span>
  <span class="formw">
   @{[ $cgi->textfield('Header', $$entry{Header} || "", 20, 255) ]}
  </span>
  <span class="label">Value</span>
  <span class="formw">
   @{[ $cgi->textfield('Value', $$entry{Value} || "", 40, 255) ]}
  </span>
  <span class="label">Score</span>
  <span class="formw">
   @{[ $cgi->textfield('Score', $$entry{Score} || "", 10, 255) ]}
  </span>
 </div>

 <div class="submitbar"> @{[ $cgi->submit(-name=>"Submit") ]} </div>
</div>

HTML
  wantarray ? @return : join("\n", @return);
}


=item text ( )

Not currently populated.

=cut

sub text { } 

=back

=cut

###############################################################################
##### main() ##################################################################
###############################################################################

News::Verimod::DBI->table_add($NAME, $FIELDS, $KEYS, $LIST, $ORDER, 
                              $ADMIN, $REQUIRED, \&html, \&text);

1;

=head1 NOTES

These tables were designed as part of News::Verimod, and haven't worked
out all that well.  They do their job, but none of the packages necessary
to make them really useful have ever been implemented...

=head1 TODO

=head1 REQUIREMENTS

Perl, MySQL, News::Verimod

=head1 SEE ALSO

B<DBIx::Frame>, B<News::Verimod>, B<News::Verimod::DBI>

=head1 AUTHOR

Written by Tim Skirvin <tskirvin@killfile.org>

=head1 HOMEPAGE

B<http://www.killfile.org/rgm/>

=head1 LICENSE

This software is available under the terms of the Perl Artistic License.

=head1 COPYRIGHT

Copyright 1995-2004, Tim Skirvin <tskirvin@killfile.org>.

=cut

###############################################################################
### Version History ###########################################################
###############################################################################
# v1.01		Wed Aug 18 16:31:56 CDT 2004 
### Updating for DBIx::Frame, adding comments, and starting the process of
### making this vaguely professional.
