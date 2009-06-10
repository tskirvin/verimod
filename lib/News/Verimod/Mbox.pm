$VERSION = "0.50";
package News::Verimod::Mbox;
our $VERSION = "0.50";

# -*- Perl -*-		Wed Feb 23 14:18:28 CST 2005 
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>
# Copyright 1996-2005, Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::Mbox - log News::Verimod articles into mbox files

=head1 SYNOPSIS

  use News::Verimod::Mbox qw( log_approve log_reject );  

=head1 DESCRIPTION

This module offers several logging functions that can save articles into
mbox files, based on how they were processed.  It is used by
B<News::Verimod::Standard> for its logging, though other functions may take
advantage of it as well.

=cut

###############################################################################
### main() ####################################################################
###############################################################################

use strict;
use Exporter;
use News::Verimod;
use vars qw( @ISA @EXPORT_OK @EXPORT);

@ISA       = qw( News::Verimod Exporter );
@EXPORT    = qw( );
@EXPORT_OK = qw( log_approve log_reject log_error log_enqueue );

###############################################################################
### Subroutines ###############################################################
###############################################################################

=head1 FUNCTIONS 

All of the 

=over 4

=item log_approve ( OPTIONS )

=item log_reject  ( OPTIONS )

=item log_error   ( OPTIONS )

Logs the passed article into an appropriately named mbox, creating it if
necessary.  Specifically, log_approve uses the file $logdir/approve,
log_reject uses $logdir/reject, and log_error uses $logdir/error.

Options:
  
  article	News::Article object to log.
		Default: $self->article
  logdir	Directory to save mboxes into.
		Default: $self->value('logdir')

Note that the log directory must already exist, or we will return an error!
Also, we pass logdir through B<News::Verimod>'s fixpath(), so '~' characters are
translated appropriately.

Return an error message if there is an error, otherwise return undef.

=cut

sub log_approve {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $$self->article or return 'no article';
  my $logdir  = $options{'logdir'} || $self->value('logdir');
  _log($self, $article, "$logdir/approve");
}

sub log_reject {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $$self->article or return 'no article';
  my $logdir  = $options{'logdir'} || $self->value('logdir');
  _log($self, $article, "$logdir/reject");
}

sub log_error {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $$self->article or return 'no article';
  my $logdir  = $options{'logdir'} || $self->value('logdir');
  _log($self, $article, "$logdir/error");
}

=item log_enqueue ( OPTIONS )

Not implemented at this point.

=cut

sub log_enqueue { "Not implemented " }

### _log ( ARTICLE, FILENAME )
# Actually does the work of the above functions.  Should be fairly
# self-explanatory.
sub _log {
  my ($self, $article, $filename) = @_;
  $filename = News::Verimod->fixpath($filename);
  my $maintainer = $self->value('maintainer') || return 'no maintainer';
  my $date = scalar localtime;
  open (FILE, "+>>$filename") or return "couldn't open $filename: $!";
  print FILE "From $maintainer  $date\n"; 
  $article->write(\*FILE);
  print FILE "\n";
  close FILE;
  undef;
}

1;

=back

=head1 NOTES

=head1 REQUIREMENTS 

B<News::Verimod>, B<News::Gateway>

=head1 TODO

File locking on mbox files.

=head1 AUTHOR

Tim Skirvin <tskirvin@killfile.org>

=head1 HOMEPAGE

B<http://www.killfile.org/~tskirvin/software/verimod/>

=head1 LICENSE

This code may be redistributed under the same terms as Perl itself.

=head1 COPYRIGHT

Copyright 1996-2005, Tim Skirvin <tskirvin@killfile.org>

=cut

###############################################################################
### Version History ###########################################################
###############################################################################
# 0.50		Wed Feb 23 14:28:05 CST 2005 
### Written from scratch because it seems like mboxes are a good way to go.

