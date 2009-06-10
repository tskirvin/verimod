$VERSION = "0.99.51";
package News::Verimod::BoilerMIME;
our $VERSION = "0.99.51";

# -*- Perl -*-          $Id: $
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>
# Copyright 1996-2008, Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::BoilerMIME - create MIME-based boilerplate responses 

=head1 SYNOPSIS

  use News::Verimod::BoilerMIME;

  ## Create a boilerplate and mail it, as long as we're not testing.

  # $self, $article, and $reason are already populated
  my $boiler = News::Verimod::BoilerMIME->boilerplate(
        'verimod' => $self,  'article' => $article, 
        'reason' => $reason, 'type'    => 'reject', );

  if ( ! $boiler ) { 
    print "Couldn't make boilerplate, so won't send one\n";
  } elsif ($options{'nouserreject'}) { 
    print "No user boilerplate will be sent at mod request\n";
  } elsif ($test) {
    print "Rejection notification would have been sent: \n\n";
    $boiler->print(\*STDOUT);   print STDOUT "\n\n";
  } else {
    print $boiler->send ? "Rejection notice sent\n"
                        : "Could not send rejection notice\n";
  }

  ## Change the boilerplate type to another coderef.
  News::Verimod::BoilerMIME->set_boilerplate('modqueue', 
                                     \&boilerplate_mailqueue);

=head1 DESCRIPTION

News::Verimod::BoilerMIME uses MIME::Lite to create a boilerplate message, 
using the information from the offered News::Verimod and News::Article 
objects.  Several default boilerplates are offered by default; more can 
be added fairly readily by whatever script needs to use them.  The
objects can then be handled in standard MIME::Lite manners, ie they can 
be printed, emailed, or whatever.

Please see the MIME::Lite manpage for information on how to use the 
functions.  Especially note that the default option here is to use 
sendmail, but it will accept SMTP instead, which would make porting to Windows
much easier.

=head1 USAGE

=cut

###############################################################################
### main() ####################################################################
###############################################################################

use strict;
use MIME::Lite;
use Text::Wrap;
use News::Verimod::ModNotes;

###############################################################################
### Variables #################################################################
###############################################################################

=head2 VARIABLES

The following variables are used in this class.

=over 4

=item %News::Verimod::BoilerMIME::BOILER

The keys are the potential types of boilerplates that can be made; the values
are CODEREFs that are invoked to actually create the fully-populated 
MIME::Lite object.  

=item $Text::Wrap::columns

Used by Text::Wrap::wrap() to decide how many columns we will wrap our 
text to.  Used by several of the offered boilerplate functions.

=back

=cut

# $Text::Wrap::columns = 75;            # If we want to set it, we can do so
use vars qw( %BOILER );

%BOILER = (
    'modqueue'         => \&boilerplate_modqueue,
    'reject'           => \&boilerplate_reject,
    'approve'          => \&boilerplate_approve,
    'userqueue'        => \&boilerplate_userqueue,
          );


###############################################################################
### Boilerplate Management ####################################################
###############################################################################

=head2 BOILERPLATE MANGEMENT

=over 4

=item boilerplate ( ARGS )

Creates the MIME::Lite objects.  Required options, passed in C<ARGS>:

  verimod       News::Verimod object
  article       News::Article object (can be in the verimod object)
  type          The type (used as a key for %BOILER)

Returns undef if no boilerplate could be created, and the MIME::Lite object
otherwise.

=cut

sub boilerplate {
  my ( $self, %args ) = @_;
  my $verimod = $args{'verimod'} || return undef;
  my $article = $args{'article'} || $verimod->article || return undef;
  my $type    = $args{'type'} || return undef;

  my $msg = _create_msg( $self, $BOILER{$type}, %args ) || return undef;

  return $msg;
}

=item set_boilerplate ( TYPE, CODE )

Sets %BOILER{TYPE} equal to CODE.  This is fairly unforgiving at this point.
Returns the appropriate coderef.

=cut

sub set_boilerplate {
  my ($self, $type, $code) = @_;
  return undef unless ($type && $code);
  $BOILER{$type} = $code;
  $code;
}

###############################################################################
### Information Parsing #######################################################
###############################################################################

=back

=head INFORMATION PARSING 

The following functions are available within the boilerplate creation
functions, to make things just a bit easier.

=over 4

=item modbot ( VERIMOD, ARTICLE, OPTIONS )

Returns the name of the moderation 'bot, and its contact address.  Suitable 
as a From: line.  

=cut

sub modbot {
  my ( $self, $verimod, $article, %opts ) = @_;

  my $botname = $verimod->value('botname') || "Unknown Modbot";
  my $contact = $verimod->value('contact') || "";

  "$botname <$contact>"
}

=item poster ( VERIMOD, ARTICLE, OPTIONS )

Returns the appropriate response address for the original poster - either
Reply-To: or From:, or "(unknown)" if neither of those exist.  This could
probably be more sophisticated.

=cut 

sub poster {
  my ( $self, $verimod, $article, %opts ) = @_;
  $article->header('reply-to') || $article->header('from') || "(unknown)";
}

=item moderators ( VERIMOD, ARTICLE, OPTIONS )

Returns the address to contact the moderators, from MODLIST.  

=cut

sub moderators {
  my ( $verimod, $article, %opts ) = @_;
  my $mods = $verimod->value('modlist');
  $mods || "";
}

=item poster_noreject ( VERIMOD, ARTICLE, OPTIONS )

=item poster_noconfirm ( VERIMOD, ARTICLE, OPTIONS )

Like poster(), but only if the x-no-reject or x-no-confirm headers
(respectively) are not set.  This ensures that those headers are followed.

=cut

sub poster_noreject {
  my ( $self, $verimod, $article, %opts ) = @_;
  return "" if $article->header('x-no-reject');
  poster(@_);
}

sub poster_noconfirm {
  my ( $self, $verimod, $article, %opts ) = @_;
  return "" if $article->header('x-no-confirm');
  poster(@_);
}

=item signature ( VERIMOD, ARTICLE, OPTIONS )

Returns a message suitable as a .signature.  Starts with the botname, signed 
in the (controversial) Tim Skirvin style, as so: 

                - Modbot Name <modbot@example.com.invalid>

If there is a signature file, as set in $verimod->value('signature'), then
this is added as well, with the standard sigsep ("-- "):

  -- 
  Some text that is found in the 'signature' file.

Note that the file path is passed through News::Verimod's fixpath().

=cut

sub signature {
  my ( $self, $verimod, $article, %opts ) = @_;
  my @return = sprintf("%+70s", "- " . $self->modbot($verimod,$article) ); 
  my $sigfile = $verimod->value('signature');
  if ( $sigfile ) { push @return, "-- ", _readfile( $sigfile ) } 
  @return;
}

=item report ( VERIMOD, ARTICLE, OPTIONS )

Creates an error report explaining just why a given article was rejected.  This
information is gathered from the names of the modules that offered error
messages, the error messages themselves, and any data from 
$News::Verimod::ModNotes::REPORT or %News::Gateway::REPORT that corresponds 
with those module names.  The text is then formatted into a vaguely useful 
layout.

Options:

  reason        The 'reasons' arrayref ("No reasons" if empty)

The 'reasons' arrayref contains further arrayrefs with two items each: the
module name and the error code. 

=cut

sub report {
  my ( $self, $verimod, $article, %opts ) = @_;
  my @reasons = ( defined $opts{'reason'} && ref $opts{'reason'} ) 
                ? @{$opts{'reason'}} : ();
  my @return = ();
  push @return, ( "No reasons", '' ) unless scalar @reasons;
  foreach (@reasons) { 
    my ($reason, $text) = ref $_ ? ( @$_ ) : ( $_, $_ );
    next unless $reason;
    if (my $report = $News::Verimod::ModNotes::REPORT{$reason} 
                     || $News::Gateway::REPORT{$reason}) { 
      $report = wrap("  ", "  ", $report);
      my @report = split("\n", $report);
      push @return, $text, @report, "";
    } else { push @return, $text, "" }
  }
  map { $_ = "  $_" } @return;          # Indent by two characters on reports
  @return;
}

###############################################################################
### Boilerplates ##############################################################
###############################################################################

=back

=head2 DEFAULT BOILERPLATES 

The following boilerplates are offered by default.  Note that all of these
functions use the options:

  verimod       News::Verimod object
  article       News::Article object (can be in the verimod object)

=over 4

=item boilerplate_approve ( ARGS )

Creates a basic approval message, with text like this:

  Your article has been posted to news.admin.net-abuse.policy.

  If you do not wish to receive these notices in the future, include
  the line "X-No-Confirm: yes" in the headers or the first line of
  your posts.  It may also be possible to turn off these confirmations
  permanently, consult the newsgroup's FAQ for details.
  
  Thank you for your post, and you can look forward to seeing it on
  your server soon!
                        
  (signature)

Also includes the posted message as an attachment.

=cut

sub boilerplate_approve {
  my ( $self, %args ) = @_;
  my $verimod = $args{'verimod'} || return undef;
  my $article = $args{'article'} || $verimod->article || return undef;

  ## Generate the text of the message we'll include in the body.
  my @msg;
  push @msg, join('', "Your article has been posted to ", 
                $verimod->value('groupname'), "." );
  push @msg, "", "If you do not wish to receive these notices in the future, include the line \"X-No-Confirm: yes\" in the headers or the first line of your posts.  It may also be possible to turn off these confirmations permanently, consult the newsgroup's FAQ for details.";

  push @msg, "", "Thank you for your post, and you can look forward to seeing it on your server soon!";

  # Wordwrap the message to this point
  @msg = wrap("", "", join ("\n", @msg));

  push @msg, "", $self->signature($verimod);

  ## Create the actual MIME::Lite object.
  my $msg = MIME::Lite->new(
        'Type'    =>    'multipart/mixed',
        'To'      =>    $self->poster_noconfirm($verimod, $article), 
        'From'    =>    $self->modbot($verimod, $article), 
        'Subject' =>    join('', "[", scalar $verimod->value('shortname'), "] ",
                           $article->header('message-id'), " - post approved" ),
        'Reply-To' =>   $verimod->value('contact'),
                );
  $msg->attach( 'Type' => 'TEXT', 'Data' => join("\n", @msg) );

  ## Attach the article
  $msg->attach( 
        'Type'     => 'text',
        'Filename' => $article->header('message-id'),
        'Data' => [ join("\n", $article->headers, '', $article->body ) ]
              );

  $msg;
}

=item boilerplate_reject ( ARGS )

Creates a basic rejection message, with text like this:

  Your article has been rejected for the following reasons:
  
    (report)

  If you feel that your post was rejected in error, please do not
  hesitate to contact the moderators on the matter; you may do so by
  replying to this post.  If the problems were minor, feel free to fix
  them and resubmit your article.

  Thank you for your post, regardless.  Your post is appended for future 
  reference.
                        
  (signature)

Also includes the rejected message as an attachment.

=cut

sub boilerplate_reject {
  my ( $self, %args ) = @_;
  my $verimod = $args{'verimod'} || return undef;
  my $article = $args{'article'} || $verimod->article || return undef;

  ## Generate the text of the message we'll include in the body.
  my @msg;
  push @msg, "Your article has been rejected for the following reasons:", "";
  push @msg, $self->report($verimod, $article, %args);
  
  push @msg, "If you feel that your post was rejected in error, please do not hesitate to contact the moderators on the matter; you may do so by replying to this post.  If the problems were minor, feel free to fix them and resubmit your article.", "";
  push @msg, "Thank you for your post, regardless.  Your post is appended for future reference.";

  # Wordwrap the message to this point
  @msg = wrap("", "", join ("\n", @msg));

  push @msg, "", $self->signature($verimod);

  ## Create the actual MIME::Lite object.
  my $msg = MIME::Lite->new(
        'Type'    =>    'multipart/mixed',
        'To'      =>    $self->poster_noreject($verimod, $article), 
        'Cc'      =>    $verimod->value('modlist'),
        'From'    =>    $self->modbot($verimod, $article), 
        'Subject' =>    join('', "[", scalar $verimod->value('shortname'), "] ",
                           "rejected: ", $article->header('message-id')),
        'Reply-To' =>   $verimod->value('contact'),
                );
  $msg->attach( 'Type' => 'TEXT', 'Data' => join("\n", @msg) );

  ## Attach the article
  $msg->attach( 
        'Type'     => 'text',
        'Filename' => $article->header('message-id'),
        'Data' => [ join("\n", $article->headers, '', $article->body ) ]
              );
  
  $msg;
}

=item boilerplate_modqueue ( ARGS )

Creates a short message for the moderators, to inform them that there is 
a message to be reviewed.  

Includes the enqueued message as an attachment.

=cut

sub boilerplate_modqueue {
  my ( $self, %args ) = @_;
  my $verimod = $args{'verimod'} || return undef;
  my $article = $args{'article'} || $verimod->article || return undef;

  my @msg;
  push @msg, join('', 
        "The attached article has been received by the moderation 'bot for ", 
        $verimod->value('groupname'), " and should be looked over shortly." );
  
  # Wordwrap the message to this point
  @msg = wrap("", "", join ("\n", @msg));

  push @msg, "", $self->signature($verimod);

  my $msg = MIME::Lite->new(
        'Type'    =>    'multipart/mixed',
        'To'      =>    $verimod->value('modlist'),
        'From'    =>    $self->modbot($verimod, $article), 
        'Subject' =>    join('', "[", scalar $verimod->value('shortname'), "] ",
                           $article->header('message-id'), " - enqueued" ),
        'Reply-To' =>   $verimod->value('contact'),
                );
  $msg->attach( 'Type' => 'TEXT', 'Data' => join("\n", @msg) );
  $msg->attach( 
        'Type'     => 'text',
        'Filename' => $article->header('message-id'),
        'Data' => [ join("\n", $article->headers, '', $article->body ) ]
              );
  
  $msg;
}

=item boilerplate_userqueue ( ARGS )

Creates a basic confirmation message, with text like this:

  Your article has been received, and has been forwarded to the
  moderators of news.admin.net-abuse.policy for further processing.

  If you do not wish to receive these notices in the future, include
  the line "X-No-Confirm: yes" in the headers or the first line of
  your posts.  It may also be possible to turn off these confirmations
  permanently, consult the newsgroup's FAQ for details.
  
  Thank you for your post, and you can look forward to seeing it on
  your server soon!
                        
  (signature)

Also includes the posted message as an attachment.

=cut

sub boilerplate_userqueue {
  my ( $self, %args ) = @_;
  my $verimod = $args{'verimod'} || return undef;
  my $article = $args{'article'} || $verimod->article || return undef;

  ## Generate the text of the message we'll include in the body.
  my @msg;
  push @msg, join(' ', "Your article has been received, and has been forwarded to the moderators of", $verimod->value('groupname'), "for further processing." );

  push @msg, "", "If you do not wish to receive these notices in the future, include the line \"X-No-Confirm: yes\" in the headers or the first line of your posts.  It may also be possible to turn off these confirmations permanently, consult the newsgroup's FAQ for details.";

  push @msg, "", "Thank you for your post, and we hope that you can look forward to seeing it on your server soon.";

  # Wordwrap the message to this point
  @msg = wrap("", "", join ("\n", @msg));

  push @msg, "", $self->signature($verimod);

  ## Create the actual MIME::Lite object.
  my $msg = MIME::Lite->new(
        'Type'    =>    'multipart/mixed',
        'To'      =>    $self->poster_noconfirm($verimod, $article), 
        'From'    =>    $self->modbot($verimod, $article), 
        'Subject' =>    join('', "[", scalar $verimod->value('shortname'), "] ",
                           $article->header('message-id'), " - post enqueued" ),
        'Reply-To' =>   $verimod->value('contact'),
                );
  $msg->attach( 'Type' => 'TEXT', 'Data' => join("\n", @msg) );

  ## Attach the article
  $msg->attach( 
        'Type'     => 'text',
        'Filename' => $article->header('message-id'),
        'Data' => [ join("\n", $article->headers, '', $article->body ) ]
              );

  $msg;
}

=back

=cut

###############################################################################
### Internal Functions ########################################################
###############################################################################

### _readfile ( FILE )
# Reads the file from FILE, after passing it through News::Verimod->fixpath().
# Returns the contents of that file, or nothing if it's empty/not there.
sub _readfile {
  my ( $file ) = @_;
  $file = News::Verimod->fixpath($file);
  open ( FILE, $file ) or return '';
  my @return = <FILE>; chomp @return; close FILE;
  @return;
}

sub _create_msg {
  my ($self, $type, %args) = @_;
  if ( ref $type eq 'CODE' ) {  return $self->$type( %args ); }
  0;
}

=head1 NOTES

This package replaces News::Verimod::Boiler, and I think it does a much better
job (mostly because it's a whole lot simpler).  

=head1 REQUIREMENTS

B<News::Verimod::ModNotes>, B<MIME::Lite>, B<Text::Wrap>

=head1 TODO

boilerplate_error() (or at least I imagine that this will be necessary at some
point).

=head1 AUTHOR

Tim Skirvin <tskirvin@killfile.org>

=head1 HOMEPAGE

B<http://www.killfile.org/~tskirvin/software/verimod/>

=head1 LICENSE

This code may be redistributed under the same terms as Perl itself.

=head1 COPYRIGHT

Copyright 1996-2007, Tim Skirvin <tskirvin@killfile.org>

=cut

1;

###############################################################################
### Version History ########################################################### 
###############################################################################
# 0.99          Thu 08 Mar 16:07:53 CST 2007    tskirvin
### Initial documented version, but it actually works!
# 0.99.50       Fri 09 Mar 15:49:48 CST 2007    tskirvin
### Report information now goes through wrap(), and uses information from
### News::Verimod::ModNotes.
# 0.99.51       Thu 24 Jan 21:10:56 PST 2008    tskirvin
### Changed rejected() text.
