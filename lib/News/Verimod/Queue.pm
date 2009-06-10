package News::Verimod::Queue;

use strict;
use News::Archive;
use News::Verimod;
use News::Queue;
use SDBM_File;

sub new { my $self = {};  bless $self, shift;  $self->_init(@_) }

### _init ( OPTIONS )
# Actually performs the work of new() and clone().
sub _init {
  my ($self, %opts) = @_;
  my $dir = $opts{'dir'} || return undef;
  my $readonly = $opts{'readonly'};  
  $readonly = 0 unless defined $readonly;

  $dir = News::Verimod->fixpath($dir);

  ## News::Archive object
  my $archive = new News::Archive ( 'basedir' => $dir, 'readonly' => $readonly, 
           'db_type' => 'SDBM_File' )
   || die "Could not create/load queue at $dir: " . News::Archive->error . "\n";
  $$self{ARCHIVE} = $archive;

  ## News::Queue object
  my $queue = new News::Queue ( "$dir/queue", 'readonly' => $readonly )
        || die "Could not create queue: $!\n";;
  $$self{QUEUE} = $queue;

  $self;
}

sub archive { shift->{ARCHIVE} }
sub queue   { shift->{QUEUE} }

###############################################################################
### Queue Listing #############################################################
###############################################################################

sub listqueue_text { 
  my ($self, %args) = @_;
  
  my $entries = $self->queue->entries;
  my @return;
  foreach my $key ( keys %{$entries} ) {
    my $entry = $$entries{$key} || next;
    push @return, [ $key, $entry->prettyprint ];
  }
  @return;
}

sub listqueue_prettytext {
  my ($self, %args) = @_;
  my @heads = News::Queue::Entry->prettyprint_head;
  my @entries = $self->listqueue_text;
  
  my $string = "%-50s %8s %10s %10s %25s %25s";
  my @return = sprintf($string, @heads);
  foreach ($self->listqueue_text) { push @return, sprintf($string, @{$_}); }
  wantarray ? @return : join("\n", @return, '');
}

sub listqueue_html_table { 
  my ($self, %args) = @_;
  my @heads = News::Queue::Entry->prettyprint_head;
  my @entries = $self->listqueue_text;
  
  my @return = ( "<table>", " <tr>" );
  foreach (@heads) { push @return, "  <th>$_</th>" }
  push @return, " </tr>";

  foreach my $entry ($self->listqueue_text) { 
    push @return, " <tr>";
    foreach (@{$entry}) { push @return, "  <td> $_ </td>" }
    push @return, " </tr>";
  }

  push @return, "</table>";

  wantarray ? @return : join("\n", @return, '');
}

sub listqueue_html_css   { }

###############################################################################
### Article Management ########################################################
###############################################################################

=item add_article ( ARGS )

  article       News::Article object for queuing/adding to the archive

Returns 1 if the article is successfully archived, 0 otherwise.

Note that the archive and message queue objects are locked when this is run.
You may want to unlock them later.

=cut

sub add_article { 
  my ($self, %args) = @_;
  my $article = $args{'article'} || return undef;
  my $msgid = $article->header('message-id') || return undef;

  my $status = $args{'status'} || "queue";

  my $archive = $self->archive;         my $queue   = $self->queue;

  my ( $ret, $ret2 );

  ## Lock the archive and add the article to it
  unless ( $archive->article_is_in_archive( $msgid ) ) {
    $archive->lock || return undef;
    $archive->subscribe($status);
    $ret = $archive->save_article( 
                 [ $article->headers, '', @{$article->body} ], $status );
  } else { $ret = 1 }

  ## Lock the queue and update it
  $queue->lock   || return undef;  
  $ret2 = $queue->update_queue( $msgid, $status );
  
  ( $ret && $ret2 ) ? 1 : 0;
}

sub hold_from_queue {
  my ($self, %args) = @_;
  my $msgid = $args{'id'}      || return "No ID offered";
  my $group = $args{'verimod'} || return "No Verimod group offered";
  my $queue = $self->queue     || return "No queue found";
  my $testing = $args{'testing'} || $group->value('testing') || 0;

  my $entry = $queue->entry($msgid);
  return "no message found - bug Tim" unless $entry;
  return "message is already approved" if $entry->status() eq 'approved';
  return "message is already rejected" if $entry->status() eq 'rejected';

  ## Step One: get the article from the queue

  my ( $return, $text ) = $self->get_from_queue('id' => $msgid);
  return $return if $return;
    
  my $article = $group->read(@{$text});
  return "Couldn't load article\n" unless $article;

  ## Step Two: update the queue to note that it's been approved

  if ($testing) { print "Will not actually update the queue.\n"; return 0; } 
  else { 
    $queue->lock   || return "couldn't lock queue";  
    my $ret = $queue->update_queue( $msgid, "hold" );
    return $ret ? 0 : "Queue didn't update";
  }

}

sub approve_from_queue { 
  my ($self, %args) = @_;
  my $msgid = $args{'id'}      || return "No ID offered";
  my $group = $args{'verimod'} || return "No Verimod group offered";
  my $queue = $self->queue     || return "No queue found";
  my $testing = $args{'testing'} || $group->value('testing') || 0;

  ## Step Zero: do we really need to do this?  Check the queue.

  my $entry = $queue->entry($msgid);
  return "no message found - bug Tim" unless $entry;
  return "message is already approved" if $entry->status() eq 'approved';
  return "message is already rejected" if $entry->status() eq 'rejected';

  ## Step One: get the article from the queue

  my ( $return, $text ) = $self->get_from_queue('id' => $msgid);
  return $return if $return;
    
  my $article = $group->read(@{$text});
  return "Couldn't load article\n" unless $article;

  ## Step Two: approve the article (code is from battloid)

  ## Articles that went in are pre-formatted; so just drop the headers 
  ## that News::Archive added.

  $article->drop_headers('xref');
  $article->rename_header('x-archive-path', 'path', 'clobber');

  ## Massage the article, and see if we can post it; if there are errors, 
  ## we'll handle them shortly.
  my @errors;
      
  ## Try to approve the article, leaving open the possibility of errors.
  my $resp = $group->approve( 'article' => $article, 'testing' => $testing,
                                                     ( $group->groupopts ) );
  push @errors, [ 'process', $resp ] if $resp;

  ## If we have an error, reject the message.
  if (scalar @errors) {
    my $rejerr = $group->reject( 'article' => $article, 'testing' => $testing,
                                 'reason'  => [ @errors ],
                                 ( $group->groupopts ) );
    return "Error in sending rejection notice: $rejerr\n" if $rejerr;
  }

  ## Step Three: update the queue to note that it's been approved

  if ($testing) { print "Will not actually update the queue.\n"; return 0; } 
  else { 
    $queue->lock   || return "couldn't lock queue";  
    my $ret = $queue->update_queue( $msgid, "approved" );
    return $ret ? 0 : "Queue didn't update";
  }
  
}

=item reject_from_queue ( )

=cut

sub reject_from_queue  {
  my ($self, %args) = @_;
  my $msgid = $args{'id'}      || return "No ID offered";
  my $group = $args{'verimod'} || return "No Verimod group offered";
  my $queue = $self->queue     || return "No queue found";
  my $reason = $args{'reason'}  || [ [ 'unknown', 'Unknown Reason' ] ];
  my $testing = $args{'testing'} || $group->value('testing') || 0;

  ## Step Zero: do we really need to do this?  Check the queue.

  # $msgid = uri_unescape($msgid);

  my $entry = $queue->entry($msgid);
  return "no message found - bug Tim" unless $entry;
  return "message is already approved" if $entry->status() eq 'approved';
  return "message is already rejected" if $entry->status() eq 'rejected';

  ## Step One: get the article from the queue

  my ( $return, $text ) = $self->get_from_queue('id' => $msgid);
  return $return if $return;
    
  my $article = $group->read(@{$text});
  return "Couldn't load article\n" unless $article;

  ## Step Two: approve the article (code is from battloid)

  ## Articles that went in are pre-formatted; so just drop the headers 
  ## that News::Archive added.

  $article->drop_headers('xref');
  $article->rename_header('x-archive-path', 'path', 'clobber');

  ## Massage the article, and see if we can post it; if there are errors, 
  ## we'll handle them shortly.
  my @errors;

  ## Try to reject the article, leaving open the possibility of errors.
  my $resp = $group->reject( 'article' => $article, 'testing' => $testing,
                             'reason' => $reason, ( $group->groupopts ),
                             'nouserreject' => $args{'nouserreject'} ? 1 : 0 );
  push @errors, [ 'process', $resp ] if $resp;

  ## If we have an error, reject the message.
  if (scalar @errors) {
    my $rejerr = $group->reject( 'article' => $article, 'testing' => $testing,
                                 'reason'  => [ @errors ], 
                                 ( $group->groupopts ) );
    return "Error in sending rejection notice: $rejerr\n" if $rejerr;
  }

  ## Step Three: update the queue to note that it's been approved

  if ($testing) { print "Will not actually update the queue.\n"; return 0; } 
  else { 
    $queue->lock   || return "couldn't lock queue";  
    my $ret = $queue->update_queue( $msgid, "rejected" );
    return $ret ? 0 : "Queue didn't update";
  }
}
  
sub get_from_queue {
  my ($self, %args) = @_;
  my $archive = $self->archive || return ( "Couldn't open archive", [] ); 

  my $id = $args{'id'} || ""; 
  return ( "Bad ID", $id ) unless $id;
  return ( "Message $id not in archive, []" ) 
                        unless $archive->article_is_in_archive( $id );
  my @text = $archive->article($id);
  return scalar @text ? ( "", \@text ) : ( "Bad article", [] );
}

sub queuevote {}

sub get_article { 
  my ($self, %args) = @_;
  my ($notes, $text) = $self->get_from_queue(%args);
  return $notes if $notes;
  my $article = News::Article->new(@{$text});
  return $article || undef;
}     

sub get_overview { 
  my ($self, %args) = @_;
  my $archive = $self->archive || return ( "Couldn't open archive", [] ); 

  my $id = $args{'id'} || ""; 
  return ( "Bad ID", $id ) unless $id;
  return ( "Message $id not in archive, []" ) 
                        unless $archive->article_is_in_archive( $id );
}    
sub remove_article { }  # take it out of the queue

sub close { $_[0]->unlock; }

sub unlock { my ($self) = @_;  $self->archive->unlock;  $self->queue->write; }

1;
