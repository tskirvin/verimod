$VERSION = "1.01";
package News::Verimod::DBI::Article;
our $VERSION = "1.01";

# -*- Perl -*-	Wed Aug 18 16:33:42 CDT 2004, tskirvin@killfile.org
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>.  Copyright 1995-2004,
# Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::DBI::Article - the Article table in News::Verimod::DBI

=head1 SYNOPSIS

  use News::Verimod::DBI::Article;
  
See News::Verimod::DBI for more information.

=head1 DESCRIPTION

The 'Article' table is used to store basic information about all articles
that are posted through the Verimod system - header information, current
status information, etc.  

This table contains the following fields:

 Internal Information (TINYTEXT fields, unless noted)
  ID            Unique numeric ID - auto-generated (INT)
  Modified      Timestamp of last modification (auto-created TIMESTAMP)
  File		File location of the whole article
  Status	Current status of this article

 Article Headers (TINYTEXT fields, unless noted)
  MessageID	'Message-ID:' header
  Newsgroups	'Newsgroups' header
  Author	'From:' header, or equivalent
  Subject	'Subject:' header
  Date		'Date: header
  Approved	'Approved' header
  ProcessedBy	'Processed-By' header

 Other Information
  Notes		Notes about the article (TEXT)
  History	Auto-generated history of the article  (TEXT)

Key fields:     MessageID, Author, Subject

List items:     Author, Subject, Modified (using timestamp_print)

Required:       MessageID, Author, Subject, Newsgroups

Default order:  Modified (reversed)

Admin Fields:   None

No other tables depend on this table.

Doesn't depend on any other table.

=head2 Variables

The following variables are set in the module, and are used as defaults
for creation and searching.

=over 4

=item @News::Verimod::DBI::Article::STATUS

Possible status types for the article.  Default possibilities: posted,
rejected, enqueue, error.

=back

=head1 USAGE

=cut

###############################################################################
### Initialization ############################################################
###############################################################################
use vars qw( @ISA $FIELDS $KEYS $NAME $LIST $REQUIRED $ADMIN $ORDER @STATUS ); 
use strict;
use warnings;
use News::Verimod::DBI qw( timestamp_print );
use CGI;
# use News::Verimod::DBI qw( timestamp_print );

unshift @ISA, "News::Verimod::DBI";

###############################################################################
### Database Variables ########################################################
###############################################################################
$NAME = "Article";
$FIELDS = {
  'ID'          => 'INT NOT NULL PRIMARY KEY AUTO_INCREMENT',
  'MessageID' => 'TINYTEXT NOT NULL', 'Newsgroups'=> 'TINYTEXT NOT NULL',
  'Author'    => 'TINYTEXT NOT NULL', 'Subject'   => 'TINYTEXT NOT NULL',
  'Date'      => 'TINYTEXT',          'Notes'     => 'TEXT',
  'Modified'  => 'TIMESTAMP',         'Status'    => 'TINYTEXT',
  'File'      => 'TINYTEXT',          'History'   => 'TEXT',
  'ProcessedBy' => 'TINYTEXT',        'Approved'  =>'TINYTEXT',
	  };
$KEYS     = [ 'MessageID', 'Author', 'Subject' ];  # Hack
$LIST     = [ 'Author', 'Subject', 
  		{ 'Modified' => [ \&timestamp_print, '$$Modified$$' ] } ];
$REQUIRED = [ 'MessageID', 'Author', 'Subject', 'Newsgroups' ];
$ADMIN    = [];
$ORDER    = [ '-ID' ];
@STATUS   = ( qw( posted rejected enqueue error ) );

# sub timestamp_print { }

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
  my $modified = News::Verimod::DBI->timestamp_print($$entry{Modified}) || "";

  my @status = @STATUS;
  push @status, '' if (lc $type eq 'search');

  my $file = $$entry{File} || "";
  my $id   = $$entry{ID} || "<i>not set</i>";
  my $url = $file 
        ? "<a href='/~rgm/moderators/article.cgi?ID=$$entry{ID}'>$file</a>"
        : "<i>file not found</i>";

  my @return = <<HTML;
<div class="basetable">
 <div class="row3">
  <span class="label">ID</span> <span class="formw">$id</span>
  <span class="label">File</span> <span class="formw">$url</span>
  <span class="label">Modified</span> <spam class="formw">$modified</span>
 </div>

 <div class="row2">
  <span class="label">From</span>
  <span class="formw">
   @{[ $cgi->textfield('Author', $$entry{Author} || "", 40, 255) ]}
  </span>
  <span class="label">Newsgroups</span>
  <span class="formw">
   @{[ $cgi->textfield('Newsgroups', $$entry{Newsgroups} || "", 25, 255) ]}
  </span>
 </div>

 <div class="row2">
  <span class="label">Subject</span>
  <span class="formw">
   @{[ $cgi->textfield('Subject', $$entry{Subject} || "", 40, 255) ]}
  </span>
  <span class="label">Approved</span>
  <span class="formw">
   @{[ $cgi->textfield('Approved', $$entry{Approved} || "", 25, 255) ]}
  </span>
 </div>

 <div class="row2">
  <span class="label">Date</span>
  <span class="formw">
   @{[ $cgi->textfield('Date', $$entry{Date} || "", 40, 255) ]}
  </span>
  <span class="label">Processed-By</span>
  <span class="formw">
   @{[ $cgi->textfield('ProcessedBy', $$entry{ProcessedBy} || "", 25, 255) ]}
  </span>
 </div>

 <div class="row2">
  <span class="label">Message-ID</span>
  <span class="formw">
   @{[ $cgi->textfield('MessageID', $$entry{MessageID} || "", 40, 255) ]}
  </span>
  <span class="label">Status</span>
  <span class="formw">
   @{[ $cgi->popup_menu('Status', \@status, $$entry{Status}) || "" ]}
  </span>
 </div>

 <div class="row1">
  <span class="label">History</span>
  <span class="formw">
   @{[ $cgi->textarea(-name=>'History', -default=>$$entry{History} || "",
                      -rows=>5, -cols=>80, -maxlength=>65535,
                      -wrap=>'physical') ]}
  </span>
 </div>

 <div class="row1">
  <span class="label">Notes</span>
  <span class="formw">
   @{[ $cgi->textarea(-name=>'Notes', -default=>$$entry{Notes} || "",
                      -rows=>5, -cols=>80, -maxlength=>65535,
                      -wrap=>'physical') ]}
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
# v1.01		Wed Aug 18 16:09:06 CDT 2004 
### Updating for DBIx::Frame, adding comments, and starting the process of
### making this vaguely professional.
