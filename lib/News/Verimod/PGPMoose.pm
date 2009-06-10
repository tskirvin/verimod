$VERSION = "0.50";
package News::Verimod::PGPMoose;
our $VERSION = "0.50";

# -*- Perl -*-		Wed Feb 23 15:31:17 CST 2005 
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>
# Copyright 1996-2005, Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod::PGPMoose - parse pgpmooserc files

=head1 SYNOPSIS

  use News::Verimod::PGPMoose;
  my $file = "$ENV{'HOME'}/.verimod/pgpmooserc";
  my $pgphash = News::Verimod::PGPMoose->parse_pgpmoose( $file );

  my $group = "humanities.philosophy.objectivism";
  my ($phrase, $id) = @{$pgphash{$group}};

=head1 DESCRIPTION

News::Verimod::PGPMooserc is a stand-alone method of parsing a standard
pgpmooserc file, which contains passwords and key IDs for individual
newsgroups that need to have their posts signed.  It is separate from
News::Verimod primarily because it's likely that other packages will want
to use it as well, without loading the whole package.

=cut

###############################################################################
### main() ####################################################################
###############################################################################

use strict;

###############################################################################
### Subroutines ###############################################################
###############################################################################

=head1 USAGE

=over 4

=item parse_pgpmoosec ( FILENAME )

Opens a pgpmooserc filename from C<FILENAME>, parses it, and returns a
hash reference containing all information from the group.  The keys to
this hash are the group names, and the values are an array containing the
passphrase and the ID.

Each line of the pgpmooserc file looks like this:

  alt.test	0x99FCD27F	"What, do you think I'm an idiot?"
  alt.spleen	0x99924DF0	"These quotes will be removed"

Comments (indicated by '#') are dropped, and blank lines ignored.

=back

=cut

sub parse_pgpmooserc {
  my ($self, $rcfile) = @_;
  
  return {} unless ($rcfile && -r $rcfile);
  
  my $pgplist = {};

  open (FILE, $rcfile) or (warn "Couldn't open $rcfile: $!\n" && return {});
  while (my $line = <FILE>) { 
    chomp $line;
    next if $line =~ /^\s*\#.*$/;      # Skip comments
    $line =~ s/^\s*|\s*$//g;    # Kills trailing and leading whitespace
    next if $line =~ /^$/;      # Ignore if the line is now empty
    if ($line =~ /^\s*(\S+)\s+(\S+)\s+(.*)\s*$/) {
      my $group = $1;  my $id = $2;  my $phrase = $3;
      $id =~ s/^0x//;                   # Remove the 0x if it's there.
      $phrase =~ s/(^\"|\"$)//g;        # Remove the quotes on the phrase
      $pgplist->{$group} = [ $phrase, $id ];
    }
  }
  close FILE;

  $pgplist;
}

1;

=head1 NOTES

This package may be moved to newslib some day, but that hasn't happened
yet.  For now, it does its job, so I'm not complaining.

=head1 REQUIREMENTS

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
# 0.50		Wed Feb 23 15:43:33 CST 2005 
### It seems to work, anyway.
