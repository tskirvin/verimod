$VERSION = "0.82";
package News::Verimod::Sample;
our $VERSION = "0.82";

# -*- Perl -*- 		Fri 16 Mar 14:49:37 CDT 2007 
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>
# Copyright 1996-2007, Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::Sample - sample article methods for News::Verimod

=head1 SYNOPSIS

  use News::Verimod::Sample qw( approve reject enqueue
                                process_approve_by_default );  

=head1 DESCRIPTION

This module offers several standard subroutines which can be imported to other
News::Verimod modules, if so desired, or just run directly.  This should 
simplify 'bot writing dramatically.

=cut

###############################################################################
### main() ####################################################################
###############################################################################

use strict;
use Exporter;
use News::Queue;
use News::Verimod;
use News::Verimod::BoilerMIME;
use News::Verimod::BoilerMIME::Logger qw( log_approve log_enqueue log_reject );
use News::Verimod::Mbox qw( log_error );
use News::Verimod::Queue;

use vars qw( @ISA @EXPORT @EXPORT_OK %OPTS %GROUP );

@ISA = qw ( News::Verimod Exporter );
@EXPORT_OK = qw( approve reject enqueue process process_enqueue_by_default
                 process_reject_by_default process_approve_by_default );

###############################################################################
### Subroutines ###############################################################
###############################################################################

=head1 FUNCTIONS 

=over 4

=item approve ( OPTIONS )

Approves an article and attempts to post it.  This consists of the following
actions: 

=over 2

=item PGPMoose Signing

Uses B<News::Verimod>'s sign_pgpmoose() function to sign the article as
appropriate.  Returns the error if one is offered; note that not having 
a key is not considered an error!

=item Add Approved Header

The Approved: header is set to the value of the submissions address, if 
one is not already set.

=item Post Article

Posts the article using B<News::Verimod>'s post().  Error messages are the later
return value.  

=item Log Article

Saves the article in mbox format with B<News::Verimod::Mbox>.

=item Confirmation Notice

Sends a confirmation message with B<News::Verimod::BoilerMIME>.  Can be 
overriden with 'nouserconfirm'.

=back

Prints status information on STDOUT.

Options:

  article	The article to post.  Defaults to $self->article
  testing	If this (or $self->value('testing')) is set, then we 
		won't actually post/mail anything, we'll just print 
		what we would have done to STDOUT.
  approvedby    Username that approved the message
  noapprovedby  If set, don't set the x-approved-by header
  nouserconfirm If set, doesn't send a confirmation message, ever.

Returns an error if there is an error; otherwise, returns undef.

=cut

sub approve {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $self->article or return 'no article';
  my $test = $self->value('testing') || $options{'testing'} || 0;
  
  ## Sign the article with PGPMoose
  my $pgperror = $self->sign_pgpmoose('article' => $article);
  return $pgperror if $pgperror;

  ## Add the 'x-approved-by' header
  my $approvedby = $self->value('approvedby') || $ENV{'VERIMOD_USER'}
                                || $ENV{'REMOTE_USER'} || 
                                $self->value('botname') || "unknown";
  if ($approvedby =~ /^(\w+)$/) { $approvedby = $1 }    # untaint
  $article->set_headers('x-approved-by', $approvedby)
                        unless defined ($options{'noapprovedby'});
  
  ## Add an 'approved' header if necessary
  $article->set_headers('approved', $self->value('submit'))
                        unless defined ($article->header('approved'));
                        
  ## Print some test information if we're just testing
  my $retvalue;
  if ($self->value('testing') || $options{'testing'}) {
    my $server = $options{'nntpserver'} || $self->value('nntpserver')
                                        || "(unknown server)";
    print "Article would be posted to $server as follows:\n***\n";
    $article->write(\*STDOUT);  print STDOUT "***\n";
    $retvalue = undef;
  } else { 
    my $mid   = $article->header('Message-ID');
    my $group = $article->header('newsgroups');

    my $return = $self->post('article' => $article);
    print $return ? "Couldn't post article: $return"
                  : "Article $mid posted to $group\n";
    # print "Article $mid posted to $group\n" unless $return;
    $retvalue = $return ? $return : undef;
  }

  ## If we failed to post, we don't want to send a confirmation message
  return $retvalue if $retvalue;

  ## Create and send the approval notice.
  my $boiler = News::Verimod::BoilerMIME->boilerplate(
        'verimod' => $self,  'article' => $article, 
                             'type'    => 'approve' );

  ## Log a copy of the message with log_approve()
  my $logerr = $self->log_approve('article' => $boiler) unless $test;
  warn "Logging error: $logerr\n" if $logerr;

  if ( ! $boiler ) { 
    print "Couldn't make boilerplate, so won't send one\n";
  } elsif ($options{'nouserconfirm'}) { 
    print "No user boilerplate will be sent at mod request\n";
  } elsif ($test) { 
    print "Approval notification would have been sent: \n\n";
    $boiler->print(\*STDOUT);   print STDOUT "\n\n";
  } else { 
    print $boiler->send ? "Approval notice sent\n"
                        : "Could not send approval notice\n";
  }

  return $retvalue || undef;
}

=item reject ( OPTIONS )

Rejects a message and attempts to send a rejection notification.  This 
consists of the following actions: 

=over 2

=item Log Article

Saves the article in mbox format with B<News::Verimod::Mbox>.

=item Rejection Notice

Sends a rejection message with B<News::Verimod::BoilerMIME>.  

=back 2

Prints status information on STDOUT.

Options:

  article	The article to post.  Defaults to $self->article
  reason	An arrayref of arrayrefs, used by report() in 
		News::Verimod::Boiler.
  testing	If this (or $self->value('testing')) is set, then we 
		won't actually post/mail anything, we'll just print 
		what we would have done to STDOUT.
  rejectedby    Username that rejected the message
  norejectedby  If set, don't set the x-rejected-by header
  nouserreject  If set, don't send a rejection notice, ever.

Returns an error if there is an error; otherwise, returns undef.

=cut

sub reject { 
  my ($self, %options) = @_;
  my $article = $options{'article'} || $self->article or return 'no article';
  my $reason  = $options{'reason'}  || [ [ 'unknown', 'Unknown Reason' ] ];
  my $test = $self->value('testing') || $options{'testing'} || 0;

  ## Add the 'x-rejected-by' header
  my $rejectedby = $self->value('rejectedby') || $ENV{'VERIMOD_USER'}
                                || $ENV{'REMOTE_USER'} ||
                                $self->value('botname') || "unknown";
  if ($rejectedby =~ /^(\w+)$/) { $rejectedby = $1 }    # untaint
  $article->set_headers('x-rejected-by', $rejectedby)   
                        unless defined ($options{'norejectedby'});

  ## Create and send the rejection notice.
  my $boiler = News::Verimod::BoilerMIME->boilerplate(
        'verimod' => $self,  'article' => $article, 
        'reason' => $reason, 'type'    => 'reject', );

  ## Log a copy of the message with log_reject()
  my $logerr = $self->log_reject('article' => $boiler) unless $test;
  warn "Logging error: $logerr\n" if $logerr;

  if ( ! $boiler ) { 
    print "Couldn't make rejection boilerplate, so won't send one\n";
  } elsif ($options{'nouserreject'}) { 
    print "Message rejected, no rejection notice sent at mod request\n";
  } elsif ($test) { 
    print "Rejection notification would have been sent: \n\n";
    $boiler->print(\*STDOUT);   print STDOUT "\n\n";
  } else { 
    my $mid = $article->header('message-id') || "unknown mid";
    print $boiler->send ? "Rejection notice sent for $mid\n"
                        : "Could not send rejection notice for $mid\n";
  }

  return undef;
}

=item enqueue ( OPTIONS ) 

Enqueues a message.  This means:

=over 2

=item News::Verimod::Queue->add_article

Add the article to a News::Verimod::Queue object.  If it's already in there,
great; if not, then we'll enter it.  See that manpage for more info.

=item Send confirmation message to poster.

Create a News::Verimod::BoilerMIME object and send it to the poster.

Can be overridden with 'nouserconfirm'.  

=item Send queue notice to moderators

Create a News::Verimod::BoilerMIME object and send it to the moderators, 
letting them know that there's a post to worry about.

Can be overridden with 'nomodconfirm'.  

=back

Note that if you want to change the text of the boilerplates, can do so with
News::Verimod::BoilerMIME->set_boilerplate(); but it is global...

Options:

  article	The article to post.  Defaults to $self->article
  reason	An arrayref of arrayrefs, used by report() in 
		News::Verimod::BoilerMIME.
  testing	If this (or $self->value('testing')) is set, then we 
		won't actually post/mail anything, we'll just print 
		what we would have done to STDOUT.
  nouserconfirm If set, don't send a user confirmation message, ever.
  nomodconfirm  If set, don't send a message to the moderators telling
                them that a message has been queued.
  queuedir      Directory for the queue for News::Verimod::Queue; defaults
                to QUEUEDIR, so you probably don't have to set this.

=cut

sub enqueue { 
  my ($self, %options) = @_;
  my $article = $options{'article'} || $self->article or return 'no article';
  my $reason  = $options{'reason'}  || [ [ 'unknown', 'Unknown Reason' ] ];
  my $test = $self->value('testing') || $options{'testing'} || 0;

  # add an explanation of the score info to the headers; leave this for later
  # my $scoreinfo = $options{'score'} || [];
  # my @report = $self->gateway->score_report( @{$scoreinfo} );
  # $article->set_headers('x-score-report', join("\n      ", 
  #     "Score, as determined by the moderation bot:", @report)) if $scoreinfo;
  
  my $queuedir = $options{'queuedir'} || $self->value('QUEUEDIR') || "";
  return "Tried to queue message, but no queue implemmented" unless $queuedir;
  my $queue = new News::Verimod::Queue('dir' => $queuedir, 'readonly' => 0);
  return "Couldn't make a queue" unless $queue;

  if ($self->value('testing') || $options{'testing'}) {
    print "Would have enqueued message\n";    
  } else { # take this out later
    $queue->add_article('article' => $article); 
  }

  $queue->close;

  my $boiler = News::Verimod::BoilerMIME->boilerplate(
        'verimod' => $self,  'article' => $article, 
        'reason' => $reason, 'type'    => 'modqueue', );

  if ( ! $boiler ) { 
    print "Couldn't make mod-boilerplate, so won't send one\n";
  } elsif ($options{'nomodconfirm'}) { 
    print "No moderator boilerplate will be sent at mod request\n";
  } elsif ($test) { 
    print "Moderator notification would have been sent: \n\n";
    $boiler->print(\*STDOUT);   print STDOUT "\n\n";
  } else { 
    my $to = $boiler->get('To');
    if ($to) { print $boiler->send ? "Queue notice sent to $to\n"
                                   : "Could not send queue notice\n"; }
    else     { print "Nobody to send queue message to\n" }
  }

  my $boiler2 = News::Verimod::BoilerMIME->boilerplate(
        'verimod' => $self,  'article' => $article, 
        'reason' => $reason, 'type'    => 'userqueue', );

  if ( ! $boiler2 ) { 
    print "Couldn't make user-boilerplate, so won't send one\n";
  } elsif ($options{'nouserconfirm'}) { 
    print "No user boilerplate will be sent at mod request\n";
  } elsif ($test) { 
    print "User notification would have been sent: \n\n";
    $boiler2->print(\*STDOUT);   print STDOUT "\n\n";
  } else { 
    my $to = $boiler2->get('To');
    if ($to) { print $boiler2->send ? "Queue notice sent to $to\n"
                                    : "Could not send queue notice\n"; }
    else     { print "Nobody to send queue message to\n" }
  }

  undef;
} 

=item process ( OPTIONS ) 

=item process_approve_by_default ( OPTIONS ) 

=item process_enqueue_by_default ( OPTIONS ) 

=item process_reject_by_default ( OPTIONS ) 

Chooses how to actually handle the articles, using message scoring and 
some combination of approve(), enqueue(), and reject().  process(), by 
default, invokes process_enqueue_by_default(), but this is easily reset in
other functions.

  approve_by_default    approve if score <= 0; reject if score >= 100;
                        enqueue otherwise
  enqueue_by_default    approve if score < 0; reject if score >= 100;
                        enqueue otherwise
  reject_by_default     approve if score <= -100; reject if score >= 0;
                        enqueue otherwise

=cut

sub process { process_enqueue_by_default (@_) } 

sub process_approve_by_default {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $$self->article or return 'no article';

  my ($score, @notes) = $self->gateway->score();   $score ||= 0;

  if    ( $score <= 0  ) { $self->approve('article' => $article, %options) }
  elsif ( $score < 100 ) { $self->enqueue('article' => $article,
                                'score' => [ $score, @notes ],
                                'nouserconfirm' => 1, %options) }
  else                   { $self->reject( 'article' => $article, %options) }
}

sub process_enqueue_by_default {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $$self->article or return 'no article';

  my ($score, @notes) = $self->gateway->score();   $score ||= 0;

  if    ( $score <  0  ) { $self->approve('article' => $article, %options) }
  elsif ( $score < 100 ) { $self->enqueue('article' => $article,
                                'score' => [ $score, @notes ], %options) }
  else                   { $self->reject( 'article' => $article, %options) }
}

sub process_reject_by_default {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $$self->article or return 'no article';

  my ($score, @notes) = $self->gateway->score();   $score ||= 0;

  if    ( $score <= -100 ) { $self->approve('article' => $article, %options) }
  elsif ( $score <   0   ) { $self->enqueue('article' => $article,
                                'score' => [ $score, @notes ],
                                'nouserconfirm' => 1, %options) }
  else                     { $self->reject( 'article' => $article, %options) }
}

=item groupopts ( )

Returns the information regarding the %OPTS hash.  If invoked as a scalar,
returns a hashref; returns the hash itself otherwise.  Returns an empty
hashref/array if %OPTS is not set, for some reason.

=item groupinfo ( )

Returns a hashref containing all of the basic information used to create the
group - ie, offers convenient access to the main variables.

=cut

sub groupopts { \%OPTS ? wantarray ? %OPTS : \%OPTS
                       : wantarray ? () : {} }
sub groupinfo  { \%GROUP }

1;

=back

=head1 NOTES

=head1 REQUIREMENTS 

B<News::Verimod>, B<News::Verimod::BoilerMIME>, B<News::Verimod::Mbox>

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
# 0.50		Wed Feb 23 10:20:07 CST 2005 
### Code written for a single newsgroup has been standardized and commented.
# 0.80          Thu 08 Mar 11:30:16 CST 2007    tskirvin
### Wrote enqueue() code; standardized processing systems, and offered more
### general options.  Now use BoilerMIME instead of Boiler.
# 0.81          Tue 13 Mar 14:07:33 CST 2007    tskirvin
### Changed thresholds from 10 to 100, which is just easier to work with.
# 0.82          Fri 16 Mar 14:49:41 CDT 2007    tskirvin
### Added x-approved-by and x-rejected-by headers, where appropriate
