package News::Verimod::Queue::Article;

use strict;
use vars qw ( @ISA );
@ISA = qw( News::Article );

sub vote { 
  my ($self, %args) = @_;
  my $person = $args{'person'} || return 0;
  my $vote   = $args{'vote'};  my $time = $args{'timestamp'} || time;
  if (defined $vote && $vote = "+1" ) { 

  } elsif (defined $vote && $vote = "-1" ) { 
    
  }
  $self->votes->{$person} || 0;
}

sub votes_approve { split(',' shift->header('x-vote-approve') ); }
sub votes_reject  { split(',' shift->header('x-vote-reject') ); }
sub votes { 
  my ($self) = @_;
  my (%votes, %people);
  foreach ($self->votes_approve) { $votes{$_}++ unless $people{$_}++ }
  foreach ($self->votes_reject) { $votes{$_}-- unless $people{$_}++ }
  %votes;
}


1;
