$VERSION = "1.00";
package News::Verimod::Boiler::Reject;
our $VERSION = "1.00";

1;

=head1 NAME

News::Verimod::Boiler::Reject - boilerplate for rejection notices

=head1 SYNOPSIS

See News::Verimod::Boiler

=head1 DESCRIPTION

This module creates the boilerplate for rejection messages sent in News::Verimod
when an article has been enqueued.  It follows the X-No-Reject standard.

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
# 1.00          Wed Feb 23 15:44:16 CST 2005 
### The first default boilerplate is written.
# 1.01          Thu 24 Jan 19:44:10 PST 2008    tskirvin
### Updated subject line slightly

#Subject: [$shortname] $message-id - post rejected
__DATA__
To: $poster-noreject
Cc: $modlist
From: $modbot
Reply-to: $contact
Subject: [$shortname] reject: $message-id

Your article has been rejected for the following reasons:

@REPORT

If you feel that your post was rejected in error, do not hesitate to
contact the moderators on the matter by replying to this post.  If the
problems were minor, feel free to fix them up and resubmit your article.  

Thank you for your post, regardless.  Your post is appended for future
reference.

		- $modbot
@SIGNATURE


@ARTICLE
