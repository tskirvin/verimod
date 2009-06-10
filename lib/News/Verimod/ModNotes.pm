$VERSION = "0.10";
package News::Verimod::ModNotes;
our $VERSION = "0.10";

# -*- Perl -*-          Fri 09 Mar 15:57:49 CST 2007
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>
# Copyright 1996-2007, Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::ModNotes - a system to parse moderator notes into utility

=head1 SYNOPSIS

  use News::Verimod::ModNotes;

  my @reject_reasons = <STDIN>;
  my @reasons = News::Verimod::ModNotes->parse_modnotes(@reject_reasons);

  # this is now parseable text
  my @text = News::Verimod::BoilerMIME->report( $verimod, $article,
                                                  'reason' => @reasons );

=head1 DESCRIPTION

News::Verimod::ModNotes is used to convert human-written notes about why an
article was rejected into something legible and useful for a rejection notice.
The moderator can input whatever text he/she wants; if it matches an existing
rejection category, then some useful explanation of why it matched is included
in the rejection notice.  If it doesn't match, then the text is cleaned up
somewhat and offered to the user directly.  Either way, the moderator should be
easily able to reject messages and offer useful information to the user as to
why they did so.

=cut

###############################################################################
### main() ####################################################################
###############################################################################

use strict;
use vars qw( %REPORT %SHORT );

###############################################################################
### Module Text ###############################################################
###############################################################################

=head2 Default Texts

For each key, there are two types of text stored in this module: the short
summary and the description.  For instance, for 'nohtml', the texts are:

  short         HTML is banned
  report        HTML-formatted messages are considered rude on Usenet,
                and are not allowed through this moderation suite.

The 'short' information is stored in %SHORT; the 'report's are stored in
%REPORT.  More can be added with the functions below, but the defaults are:

=over 4

=item nohtml

=item nobinaries

=back

More can be added easily, and will be fairly soon.  

Note that some News::Gateway autoload packages already have the report
information built-in.  This is not an attempt to duplicate them, but to offer a
reasonable way to edit them as necessary.

Also note that the 'short' information is not used for automatically generated
News::Verimod reports - the actual error text is used instead - but the 
'report' information is always used, if available.

=cut

$SHORT{'nohtml'} = "HTML is banned";
$REPORT{'nohtml'} = join("", <<ENDL);
HTML-formatted messages are considered rude on Usenet, and are not allowed through this moderation suite.
ENDL

$SHORT{'nobinaries'} = "Binaries are banned";
$REPORT{'nobinaries'} = join("", <<ENDL);
Binaries are bad.
ENDL

$SHORT{'maxquotes'} = "Too much quoted material";
$REPORT{'maxquotes'} = join("", <<ENDL);
Please trim the number of lines quoted from previous articles before you resubmit this article.
ENDL

$SHORT{'quotemax'}  = $SHORT{'maxquotes'};
$REPORT{'quotemax'} = $SHORT{'maxquotes'};

$SHORT{'anykeyword'} = "No keyword found in Subject";
$REPORT{'anykeyword'} = join("", <<ENDL);
Messages must include a subject tag, of the form: 
  Subject: [tag] Hello!
  Subject: {tag} Hello!
  Subject: Re: {tag} Hello!
ENDL

$SHORT{'keyword'}  = $SHORT{'anykeyword'};
$REPORT{'keyword'} = $SHORT{'anykeyword'};

$SHORT{'blacklist'} = "Message matches a group blocklist";
$REPORT{'blacklist'} = join("", <<ENDL);
Please contact the moderator(s) if you believe this to be an error.
ENDL

$SHORT{'blocklist'}  = $SHORT{'blacklist'};
$REPORT{'blocklist'} = $SHORT{'blacklist'};

$SHORT{'flames'} = "Message contains flames";
$REPORT{'flames'} = join("", <<ENDL);
Please contact the moderator if you think that your message was mis-categorized.
ENDL

###############################################################################
### Subroutines ###############################################################
###############################################################################

=over 4

=head2 Subroutines 

=item parse_modnotes ( TEXT )

Parses command-line or other user-input text lines into a set of entries 
that will go into the 'reasons' array, used with 
News::Verimod::BoilerMIME->report().

Every line if input has its leading and trailing whitespace removed.  If the
remaining input is a key to the %REPORT array, then we add a reason entry of:

  [ $input, $SHORT{$input} ]

If the input is *not* on the list, then it is saved until the function is 
done.  At the end, all of the leftover text is combined together and set 
to the 'modnotes' input, and the reason entry is added:

  [ modnotes, "Moderator Notes" ]

So, if the moderator entered:

  nohtml
  Your article is too long
  I never want to hear from you again.
  ^D

...then the output from News::Verimod::BoilerMIME::report() would be:
  
  HTML is banned
    HTML-formatted messages are considered rude on Usenet, and are 
    not allowed through this moderation suite.

  Moderator Comments
    Your article is too long, I never want to hear from you again.

=cut

sub parse_modnotes {
  my ($self, @lines) = @_;
  my (@return, @text);
  foreach (@lines) {
    next unless $_;
    chomp;  $_ =~ s/^\s+|\s+$//g;  next if /^\s*$/;
    if ($REPORT{lc $_}) { push @return, [ $_, $SHORT{$_} ] }
    else { push @text, $_ }
  }

  if (@text) {
    my $text = join(", ", @text);
    $REPORT{'modnotes'} = $text;
    push @return, [ 'modnotes', "Moderator Notes" ];
  }
  @return;
}

=item add_report ( KEY, SHORT, TEXT )

Adds a report to the %REPORT and %SHORT hashes.  KEY is the key text, SHORT is
the short text, and TEXT is an array of lines that will be combined for the
report text.

=cut

sub add_report {
  my ($self, $key, $short, @text) = @_;
  return "" unless $key;
  $SHORT{$key} = $short;
  $REPORT{$key} = join(' ', @text);
  $SHORT{$key};
}

=item short ( KEY )

=item report ( KEY )

Returns the short/report text with the key of KEY.   

=cut

sub short  { my $key = shift || shift; $key ? $SHORT{$key}  : %SHORT }
sub report { my $key = shift || shift; $key ? $REPORT{$key} : %REPORT }

1;

=back

=head1 NOTES

=head1 REQUIREMENTS

Tied to B<News::Verimod::BoilerMIME>.

=head1 TODO

=head1 AUTHOR

Tim Skirvin <tskirvin@killfile.org>

=head1 HOMEPAGE

B<http://www.killfile.org/~tskirvin/software/verimod/>

=head1 LICENSE

This code may be redistributed under the same terms as Perl itself.

=head1 COPYRIGHT

Copyright 1996-2007, Tim Skirvin <tskirvin@killfile.org>

=cut

###############################################################################
### Version History ###########################################################
###############################################################################
# 0.10          Fri 09 Mar 15:59:21 CST 2007    tskirvin
### Initial version.  Documentation is short.
