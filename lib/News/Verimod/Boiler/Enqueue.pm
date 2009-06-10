$VERSION = "1.01";
package News::Verimod::Boiler::Enqueue;
our $VERSION = "1.01";

1;

=head1 NAME

News::Verimod::Boiler::Enqueue - boilerplate for enqueuing

=head1 SYNOPSIS

See News::Verimod::Boiler

=head1 DESCRIPTION

This module creates the boilerplate for confirmation messages sent in
News::Verimod when an article has been enqueued.  It follows the X-No-Confirm
standard.

=head1 NOTES

=head1 REQUIREMENTS

B<News::Verimod::Boiler>

=head1 TODO

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
# 1.00		Wed Feb 23 15:44:16 CST 2005 
### The first default boilerplate is written.
# 1.01          Wed 07 Mar 14:25:14 CST 2007
### Now uses NEWARTICLE instead of ARTICLE

__DATA__
To: $poster-noconfirm
From: $modbot
Reply-to: $contact
Subject: [$shortname] $message-id - post confirmation

Your article has been received, and has been forwarded to the moderators
of $groupname for further processing.

If you do not wish to receive these notices in the future, include the
line "X-No-Confirm: yes" in the headers or the first line of your posts.  
It may also be possible to turn off these confirmations permanently,
consult the newsgroup's FAQ for details.

Thank you for your post, and we hope you can look forward to seeing it on
your server soon.  

		- $modbot
@SIGNATURE


@NEWARTICLE
