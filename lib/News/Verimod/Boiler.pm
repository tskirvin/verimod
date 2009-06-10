$VERSION = "0.60";
package News::Verimod::Boiler;
our $VERSION = "0.60";

# -*- Perl -*-          Wed 07 Mar 17:56:03 CST 2007 
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>
# Copyright 1996-2007, Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::Boiler - create boilerplate responses for News::Verimod

=head1 SYNOPSIS
 
  use News::Verimod::Boiler;
  my $verimod = new News::Verimod ( 'default' => \%DEFAULT,
				    'group'   => \%GROUP );
  my $article = News::Article->new(\*STDIN);
  my $boiler = News::Verimod::Boiler->new('reject', 
	'verimod' => $verimod, 'article' => $article, 
	'reason' => [ [ 'testing', "Testing" ] ]);
  $boiler->mail;

=head1 DESCRIPTION

News::Verimod::Boiler is used to create boilerplate responses to
News::Verimod articles, primarily for use as confirmation or rejection
notices.  It also offers enough functions to perform reasonable text
substitution.  Finally, sub-classes actually contain the necessary
boilerplate text for approvals and rejections.

This process is fairly simple except for one thing: text replacements.
The boilerplates contain variables that are meant to be replaced, or text
that starts with a '$' ('$$' is a literal '$') or a '@' ('@@' is a literal
'@').  Scalars ($) are replaced by the first item that matches from the
list:

  $SCALAR{lc variable}
  $verimod->value(lc variable)
  $article->header(lc variable)

Scalars are replaced in place - ie, 'Subject: $subject' will become
'Subject: $article->header(subject)'.

Arrays (@) are replaced in place as well, but each item that is returned is
combined with a newline.  They are only replaced if something returns from:

  $ARRAY{lc variable}

If any of the responses is a coderef, then that code is invoked with the options
CODE($verimod, $article, $options), where $verimod is the invoking News::Verimod
object, $article is the News::Article object, and $options is a hashref
containing extra options passed to new() in the first place.  So, '@REPORT' will
return the value of report($verimod, $article, $options).

Variables are word characters plus '-'.

=head1 USAGE

=cut

###############################################################################
### main() ####################################################################
###############################################################################

use strict;
use News::Verimod;
use News::Article;
use Text::Wrap;
use FileHandle();
use News::Verimod::Boiler::Approve;
use News::Verimod::Boiler::Reject;
use News::Verimod::Boiler::Enqueue;
use News::Verimod::Boiler::MailQueue;

use vars qw( %BOILER %SCALAR %ARRAY @ISA );
@ISA = qw( News::Article );

=head2 Variables

The following variables are used in this class.

=over 4

=item %News::Verimod::Boiler::BOILER

Text for each of the different types of boilerplate that we want to write.
These are found from the __DATA__ section of the appropriate sub-module.
More can be added by loading sub-modules that insert additional
information:

  $News::Verimod::Boiler::$BOILER{'myclass'} = \*myclass::DATA;

By default, values are available for 'approve' (::Approve), 'reject'
(::Reject), 'mailqueue' (::MailQueue), and 'enqueue' (::Enqueue).

=cut

%BOILER = (
	'approve' => \*News::Verimod::Boiler::Approve::DATA, 
	'reject'  => \*News::Verimod::Boiler::Reject::DATA, 
	'enqueue' => \*News::Verimod::Boiler::Enqueue::DATA, 
	'mailqueue' => \*News::Verimod::Boiler::MailQueue::DATA, 
	  );

=item %News::Verimod::Boiler::SCALAR

This hash contains replacements that are invoked with a scalar replacement
from the text of the boilerplate.  The keys are the text to be replaced,
and the value is the code that will return the appropriate response - ie 
$POSTER is replaced with the results of running poster().  This is further
discussed above.  

Additional coderefs can be added by other modules as necessary.  Default
coderefs:

  poster		poster()
  modbot		modbot()
  poster-noreject	poster_noreject()
  poster-noconfirm	poster_noconfirm()
  moderators            moderators()

=cut

%SCALAR = (
	'poster' => \&poster,
	'modbot' => \&modbot,
	'poster-noreject' => \&poster_noreject,
	'poster-noconfirm' => \&poster_noconfirm,
        'moderators' => \&moderators,
	   );

=item %News::Verimod::Boiler::ARRAY

As with SCALAR, but returns arrays of information.  

Additional coderefs can be added by other modules as necessary.  Default
coderefs:

  signature		signature()
  article		rawarticle()
  newarticle		article()
  report		report()

=cut

%ARRAY  = (
	'signature'  => \&signature,
	'article'    => \&rawarticle,
	'newarticle' => \&article,
	'report'     => \&report,
	  );

=back

=cut

###############################################################################
### Subroutines ###############################################################
###############################################################################

=head2 Object Functions 

=over 4

=item new ( TYPE, OPTIONS )

Returns a new object like News::Article that contains the full text and headers
of a message to mail to the poster or group moderators.  Does not actually do
the mailing.  

Options:

  article	News::Article object to get information from
  verimod	News::Verimod object to get information from

=cut

sub new {
  my ($class, $type, %options) = @_;
  my $article = $options{'article'} or return 'no article';
  my $verimod = $options{'verimod'} or return 'no verimod';

  my $contact = $verimod->value('contact') or return 'no contact address';

  my $source = $BOILER{$type} || \*DATA;
  my $src = News::Article::source_init( $BOILER{$type} || \*DATA );

  my $return = News::Article->new(
	sub { _process_line($src, [ $verimod,$article, { %options } ]) })
        || return "";

  $return->envelope($contact);
  $return;
}


=back

=head2 Scalar Functions 

=over 4

=cut

=item poster ( VERIMOD, ARTICLE, OPTIONS )

Returns the appropriate response address for the original poster - either
Reply-To: or From:, or "(unknown)" if neither of those exist.  This could
probably be more sophisticated.

=cut 

sub poster { 
  my ( $verimod, $article, $opts ) = @_;
  $article->header('reply-to') || $article->header('from') || "(unknown)";
}

sub moderators {
  my ( $verimod, $article, $opts ) = @_;
  my $mods = $verimod->value('modlist');
  $mods || "";
}

=item modbot ( VERIMOD, ARTICLE, OPTIONS )

Returns the name of the moderation 'bot, and its contact address.  Suitable 
as a From: line.  

=cut

sub modbot {
  my ( $verimod, $article, $opts ) = @_;

  my $botname = $verimod->value('botname') || "Unknown Modbot";
  my $version = $verimod->value('version') || $VERSION;
  my $contact = $verimod->value('contact') || "";

  "$botname <$contact>"
}

=item poster_noreject ( VERIMOD, ARTICLE, OPTIONS )

=item poster_noconfirm ( VERIMOD, ARTICLE, OPTIONS )

Like poster(), but only if the x-no-reject or x-no-confirm headers
(respectively) are not set.  This ensures that those headers are followed.

=cut

sub poster_noreject {
  my ( $verimod, $article, $opts ) = @_;
  return "" if $article->header('x-no-reject');
  poster(@_);
}

sub poster_noconfirm {
  my ( $verimod, $article, $opts ) = @_;
  return "" if $article->header('x-no-confirm');
  poster(@_);
}

=back

=head2 Array Functions 

=over 4

=cut

=item signature ( VERIMOD, ARTICLE, OPTIONS )

Reads the signature file from $verimod->value('signature') and returns the
contents of the file.  This can then be appended to the boilerplate as a
standard signature file.

If it's not set, just return "-- ", the standard signature delimiter.

Note that the file path is passed through News::Verimod's fixpath().

=cut

sub signature {
  my ( $verimod, $article, $opts ) = @_;
  my $sigfile = $verimod->value('signature') || return "-- ";
  _readfile($verimod, $article, { 'file' => $sigfile });
}


=item rawarticle ( VERIMOD, ARTICLE, OPTIONS )

Returns the lines that originally made up the article we are now responding to,
by getting it from $verimod->rawarticle.

=cut

sub rawarticle {
  my ( $verimod, $article, $opts ) = @_;
  ( @{$article->{RawHeaders}}, "", @{$verimod->rawarticle->{Body}} );
}

sub article {
  my ( $verimod, $article, $opts ) = @_;
  ( $article->headers, '', $article->body );
}

=item report ( VERIMOD, ARTICLE, OPTIONS )

Creates an error report explaining just why a given article was rejected.  This
information is gathered from the names of the modules that offered error
messages, the error messages themselves, and any data from 
%News::Gateway::REPORT that corresponses with those module names.  The text is
then formatted into a vaguely useful layout.

Options:

  reason	The 'reasons' arrayref ("No reasons" if empty)

The 'reasons' arrayref contains further arrayrefs with two items each: the
module name and the error code. 

=cut

sub report {
  my ( $verimod, $article, $opts ) = @_;
  my @reasons = ( defined $$opts{'reason'} && ref $$opts{'reason'} ) 
			? @{$$opts{'reason'}} : ();
  my @return = ();
  push @return, "No reasons" unless scalar @reasons;
  foreach (@reasons) { 
    my ($reason, $text) = ref $_ ? ( @$_ ) : ( $_, $_ );
    next unless $reason;
    if (my $report = $News::Gateway::REPORT{$reason}) { 
      my @report = split("\n", $report);
      map { $_ = "  $_" } @report;  
      push @return, $text, @report, "";
    } else { push @return, $text, "" }
  }
  
  map { $_ = "  $_" } @return;		# Indent by two characters on reports
  @return;
}

=back

=cut


###############################################################################
### Internal Functions ########################################################
###############################################################################

### _readfile ( $verimod, $article, $opts )
# Reads a filename (from $opts{'file'} parsed through fixpath()), 
sub _readfile {
  my ( $verimod, $article, $opts ) = @_;
  $opts ||= {};
  my $file = $$opts{'file'};
  $file = News::Verimod->fixpath($file);
  open ( FILE, $file ) or return '';
  my @return = <FILE>;
  chomp @return;
  close FILE;
  @return;
}

### _subst_scalar ( $name, $substs ) 
## Substitite scalars as appropriate.  Mostly stolen from News::FormArticle.
sub _subst_scalar {
  my ($name, $substs) = @_;
  return "" unless ref $substs;
  my $val = undef;
  my ($verimod, $article, $opts) = @$substs;

  if    (my $tmp  = $SCALAR{lc $name})       { $val = $tmp }
  elsif (my $tmp1 = $verimod->value($name))  { $val = $tmp1 }
  elsif (my $tmp2 = $article->header($name)) { $val = $tmp2 }
  else 					     { $val = "" }

  if      (ref(\$val) eq 'GLOB') { 
    $val = defined($ {*$val}) ? $ {*$val} : undef;
  } elsif (ref($val) eq 'CODE') { 
    $val = &$val($verimod, $article, $opts);
  }

  $val;
}

### _subst_array ( $name, $substs ) 
## Substitite arrays as appropriate.  Mostly stolen from News::FormArticle.
sub _subst_array { 
  my ($name, $substs) = @_;
  return "" unless ref $substs;
  my $val = undef;
  my ($verimod, $article, $options) = @$substs;

  if    (my $tmp  = $ARRAY{lc $name})        { $val = $tmp }
  else 					     { $val = [ ] }

  if      (ref(\$val) eq 'GLOB') { 
    $val = defined(@{*$val}) ? \@{*$val} : undef;
  } elsif (ref($val) eq 'CODE') { 
    $val = [ &$val($verimod, $article, $options) ];
  }

  my $text = join("\n", @$val);
  $text =~ s/\s+$//gsx;
  $text;
}

### _process_line( $name, $substs ) 
# Processes a single line of the boilerplate.  Mostly from News::FormArticle.
sub _process_line {
  my ($src, $substs) = @_;

  local $_ = &$src();
  return undef unless defined($_);
  chomp;
  $_ .= "\n";

  # look for substitution patterns. We recognize: 
  #   ?WORD
  # where ? is either $ or @. Also, $$ = $ and @@ = @.

  s{ ([\$\@]) (\1|[\w-]+) }
   { (($1 eq $2) ? $1 : (($1 eq "\$") ? _subst_scalar($2,$substs)
                                      : _subst_array($2,$substs))) }gex;

  $_;
}

1;

=head1 NOTES

This program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.  

=head1 REQUIREMENTS 

B<News::Verimod>

=head1 TODO

=head1 AUTHOR

Tim Skirvin <tskirvin@killfile.org>, based on code by Andrew Gierth
<andrew@erlenstar.demon.co.uk>.

=head1 HOMEPAGE

B<http://www.killfile.org/~tskirvin/software/verimod/>

=head1 LICENSE

This code may be redistributed under the same terms as Perl itself.

=head1 COPYRIGHT

Copyright 1996-2005, Tim Skirvin <tskirvin@killfile.org>

=cut

=cut 

### _wordwrap ( TEXT )
# We used this briefly to wrap the text of the final boilerplate, but we 
# aren't doing so now.  We really need something more sophisticated.
sub _wordwrap {
  my @text = @_;
  my @fixed = fill("", "", @text);
  
  my ($length, $wrap, @lines) = @_;
  my (@newlines, $count);

  foreach my $line (@lines) {
    while ($line =~ /^.{$length,}$/) {     # If the line has >$max chars
      $count++;
      my ($first, $second) = $line =~ /^(.{$wrap})(.*)$/;
      if ($first =~ /^(.*)\s+(\S+)$/) {
        $first = $1;  $second = join('', $2, $second);
      }
      push (@newlines, $first);     # Process the lines
      $line = $second;
    }
    push (@newlines, $line);
  }

  (\@newlines, $count);
}

=cut

###############################################################################
### Version History ###########################################################
###############################################################################
# 0.50		Wed Feb 23 15:08:29 CST 2005
### Generally works.
# 0.60          Wed 07 Mar 17:56:11 CST 2007 
### Added MailQueue type.

__DATA__
