package News::Verimod::Queue::HTML;

use News::Verimod::Queue;
use News::Web;
use URI::Escape;

use strict;
use vars qw( @ISA );
@ISA = "News::Verimod::Queue";

=item listqueue_html_table ( )

Lists the basic queue information - message-ID, voting stats, last-updated/
last-modified dates - 

=cut

sub listqueue_html_table { 
  my ($self, %args) = @_;
  my @heads = News::Queue::Entry->prettyprint_head;
  my @entries = $self->listqueue_text;
  
  my @return = ( "<table border>", " <tr>" );
  foreach (@heads) { push @return, "  <th>$_</th>" }
  push @return, "<th>Actions</th>";
  push @return, " </tr>";

  foreach my $entry ($self->listqueue_text) { 
    my $id = @{$entry}[0];  
    my $article = $self->get_article( 'id' => $id );
    $id =~ s/^<|>$//g;
    $id =~ s/\+/%2B/g;

    push @return, " <tr>";
    foreach (@{$entry}) { push @return, join('', "  <td>", 
                        News::Web->html_clean($_) || "&nbsp;", "</td>") }
    push @return, join('', " <th>", 
                News::Web->linkback( "Read", 
                          { 'msgid' => $id, 'action' => 'view' } ), "<br />",
                        "</th>");
    # push @return, join('', " <th>", $article->header('subject'), "</th>" );
    push @return, " </tr>";
  }

  push @return, "</table>";

  wantarray ? @return : join("\n", @return, '');
}

=item listqueue_html_css ( )

=cut

sub listqueue_html_css {
  my ($self, %args) = @_;
  my @entries = $self->queue->entries_by_status('queue');
  
  my @return = "";
  if (@entries) { 
    foreach my $entry ( @entries ) { 
      push @return, "<div class='overall'>";
      push @return, " <div class='article'>", 
                        $self->article_box($entry, %args), "</div>";
      push @return, " <div class='actions'>", 
                        $self->actions_box($entry, %args), "</div>";
      push @return, " <div class='artinfo'>", 
                        $self->artinfo_box($entry, %args), "</div>";
      push @return, "</div>";
    }
    
  } else { push @return, "<h4> Queue is Empty </h4>"; }
  
  wantarray ? @return : join("\n", @return, '');
}

sub listhold_html_css {
  my ($self, %args) = @_;
  my @entries = $self->queue->entries_by_status('hold');
  
  my @return = "";
  if (@entries) { 
    foreach my $entry ( @entries ) { 
      push @return, "<div class='overall'>";
      push @return, " <div class='article'>", 
                        $self->article_box($entry, %args), "</div>";
      push @return, " <div class='actions'>", 
                        $self->actions_box($entry, %args), "</div>";
      push @return, " <div class='artinfo'>", 
                        $self->artinfo_box($entry, %args), "</div>";
      push @return, "</div>";
    }
    
  } else { push @return, "<h4> Queue is Empty </h4>"; }
  
  wantarray ? @return : join("\n", @return, '');
}

sub article_box { 
  my ($self, $entry, %args) = @_;
  return "no article" unless $entry;
  my $msgid = $entry->id() || return "No ID offered";
  
  my ( $return, $text ) = $self->get_from_queue('id' => $msgid);
  return $return if $return;
  my $article = new News::Article(@{$text});

  $article->drop_headers('xref');
  $article->rename_header('x-archive-path', 'path', 'clobber');

  return News::Web->_html_article( $article );
}

sub actions_box { 
  my ($self, $entry, %args) = @_;
  return "no article" unless $entry;
  my $msgid = $entry->id() || return "No ID offered";
     $msgid = $self->msgid_escape($msgid);

     # $msgid = uri_escape($msgid);
     # $msgid =~ s/\%/%25/g;
     # $msgid =~ s/\+/%2B/g;
     # $msgid = CGI::escapeHTML($msgid);

  my @return; 
  push @return, "<h2> Article Actions </h2>", "<ul id='actlist'>";
  push @return, join(' ', " <li> ", News::Web->linkback( "Read", 
                          { 'msgid' => $msgid, 'action' => 'view' } ), "</li>");
  push @return, join(' ', " <li> ", News::Web->linkback( "Approve", 
                       { 'msgid' => $msgid, 'action' => 'approve' } ), "</li>");
  push @return, join(' ', " <li> ", News::Web->linkback( "Hold", 
                       { 'msgid' => $msgid, 'action' => 'hold' } ), "</li>");
  
  push @return, join(' ', " <li> ", News::Web->linkback( 
                   "Reject Article (Quiet)", 
                   { 'msgid' => $msgid, 'action' => 'rejectquiet' } ), "</li>");
  push @return, "</ul>";
  push @return, join(' ', $self->rejectbox('msgid' => $msgid) );
  
  wantarray ? @return : join("\n", @return);
}

sub artinfo_box { 
  my ($self, $entry, %args) = @_;
  return "no article" unless $entry;
  my $gateway = $args{'gateway'} || return "<h2> No article info available</h2>";
  my $msgid = $entry->id() || return "No ID offered";

  my ( $return, $text ) = $self->get_from_queue('id' => $msgid);
  return $return if $return;
  my $article = $gateway->read(@{$text});

  my ($score, @notes) = $gateway->gateway->score();   $score ||= 0;

  my @return;
  push @return, "<h2> Article Information </h2>";
  push @return, $self->scorebox( $score, @notes ); 
  
  wantarray ? @return : join("\n", @return);
}

=item scorebox ( TOTAL, SCOREINFO )

Returns a table that contains a human-readable summary of the scoring 
information for the given article.  C<TOTAL> and C<SCOREINFO> are the
information returned by News::Gateway->score() - that is, a number, and an
arrayref of arrayrefs that contain information about the individual tests that
were run.

The table is returned as either an array of lines or as a single, newline-joined
string.  For each arrayref entry, we'll have a 'scorerow'.  The table looks like
this:

  <table id='scoretable'>
   <tr class='scorehead'> 
    <th> Raw </th> <th> Mult </th>
    <th> Total </th> <th> Comments </th>
   </tr>
   <tr class='scorerow'> 
    <td class='num'> rawscore </td>
    <td class='num'> multiplier </td>
    <td class='num'> total </td>
    <td class='text'> text </td> 
    {rows}
   </tr>
   [...]
   <tr class='scorerow'> 
    <td colspan=2> &nbsp; </td>
    <td class='num'> TOTAL </td>
    <td class='text'> Total </td> 
   </tr>
  </table>

=cut

sub scorebox {
  my ($self, $total, @scoreinfo) = @_;
  $total = sprintf("%7.2f", $total || 0);
  
  my @return = "<table id='scoretable'>";
  push @return, " <tr class='scorehead'> <th> Raw </th> <th> Mult </th> <th> Total </th> <th> Comments </th> </tr>";
  foreach my $entry (@scoreinfo) {
    next unless ($entry && ref $entry);
    my ($module, $raw, $mult, $total, $text) = @{$entry};
    next unless defined $total;
    push @return, " <tr class='scorerow'>";
    push @return, "  <td class='num'> " . sprintf("%7.2f", $raw) . " </td>";
    push @return, "  <td class='num'> " . sprintf("%7.2f", $mult) . " </td>";
    push @return, "  <td class='num'> " . sprintf("%7.2f", $total) . " </td>";
    push @return, "  <td class='text'> $text </td>";
    push @return, " </tr>";
  }
  push @return, " <tr class='rowarea'> <td colspan=2> &nbsp; </td>";
  push @return, "  <td class='num'> $total </td> <td> Total </td> </tr>";

  push @return, "</table>";

  wantarray ? @return : join("\n", @return);
}

=item rejectbox ( ARGHASH )

There is definitely more that should be done here, mostly to offer specific
lists of reasons that we should reject under.

=cut

sub rejectbox {
  my ($self, %args) = @_;
  return "no article" unless my $msgid = $args{'msgid'};
  my $url = $0;  $url =~ s%.*/%%g;
  my $cgi = new CGI;
  my @return;

 #  push @return, $cgi->start_form('method' => 'POST');
  push @return, $cgi->start_form();
  push @return, $cgi->hidden('msgid' => $msgid);
  push @return, $cgi->hidden('action' => 'reject');
  push @return, $cgi->textarea(-name=>'reject_reasons', -default => "",
                               -rows=>5, -cols => 30, -maxlength => 65535,
                               -wrap=>'physical');
  push @return, $cgi->submit('action', 'Reject (with notification)' );
  push @return, $cgi->end_form;

  wantarray ? @return : join("\n", @return);
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
  return "Couldn't load article" unless $article;

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
  
sub msgid_escape { 
  my ($self, $msgid) = @_;
  $msgid =~ s/^<+|>+$//g;
  $msgid =~ s/\%/%25/g;
  $msgid =~ s/\+/%2B/g;
  # $msgid = uri_escape($msgid);
  $msgid;
}

sub msgid_unescape { 
  my ($self, $msgid) = @_;
  return $msgid if $msgid =~ /^</;
  # $msgid = uri_unescape($msgid);
  $msgid =~ s/%2B/\+/g;
  $msgid =~ s/%25/\%/g;
  return "" unless $msgid;
  $msgid = join('', '<', $msgid, '>');
  $msgid =~ s/^<</</g;  $msgid =~ s/>>$/>/g;
  $msgid;
}


1;

### Fri 06 Apr 11:03:17 CDT 2007 
# message-IDs are now cleaned up before being put into URL
### Sat 07 Apr 12:47:15 CDT 2007 
# more msgid cleanup; using URI::Escape
