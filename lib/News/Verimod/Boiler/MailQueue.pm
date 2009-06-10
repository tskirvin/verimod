$VERSION = "1.00";
package News::Verimod::Boiler::MailQueue;
our $VERSION = "1.00";

1;

=head1 NAME

News::Verimod::Boiler::MailQueue - boilerplate for enqueuing

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

Copyright 1996-2007, Tim Skirvin <tskirvin@killfile.org>

=cut

###############################################################################
### Version History ###########################################################
###############################################################################
# 1.00		Wed 07 Mar 14:25:03 CST 2007 
### The first default boilerplate is written.

__DATA__
To: $moderators
From: $modbot
Reply-to: $contact
Subject: [$shortname] $message-id needs approval

The following article has been received by the moderation 'bot for 
$groupname.  

		- $modbot
@SIGNATURE


@NEWARTICLE
