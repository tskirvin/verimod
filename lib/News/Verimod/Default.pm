# Is this even used?  I don't think so.  DROP IT!  WHOO!
package News::Verimod::Default;

use strict;
use Exporter;
use News::Gateway;
use vars qw( @MODULES @CMDS $NEWSGROUP $SUBMIT $CONTACT @MODERATORS
	     $BOTNAME $VERSION @EXPORT @ISA );

@EXPORT  = qw( botname version );
@MODULES = ( 'mailpath', 'xtrace' );
@ISA     = qw( News::Gateway );

$BOTNAME = "";
$VERSION = "";

## Enable additional operations and configuration options in News::Gateway
$News::Gateway::HOOKS{'linelength'} = [ 'linelength' ];
$News::Gateway::HOOKS{'xtrace'} = [];
$News::Gateway::HOOKS{'clean'}  = [ 'clean', 'maxrefs', 'hostname', 
				    'mid_prefix' ];
$News::Gateway::HOOKS{'modbot'} = [ 'botname' ];

sub modules  { @MODULES }
sub commands { 
  return @CMDS if scalar @CMDS;
  @CMDS = <DATA>;
  chomp @CMDS;
  @CMDS;
}

sub botname { $BOTNAME }
sub version { $VERSION }
sub submit  { $SUBMIT }
sub contact { $CONTACT }
sub moderators { @MODERATORS }

sub fix {
  my ($group, $article) = @_;

  my @problems;

  # Make sure we have this newsgroup in the newsgroups header

  ## Rename headers that we got from the users, but we can't just propagate to 
  ## the new article verbatim.

  foreach my $head ( qw( NNTP-Posting-Host NNTP-Posting-User NNTP-Posting-Date 
			 Injector-Info Sender Path To Cc Date Approved ) ) {
    if (defined $article->header($head) ) { 
      $article->rename_header($head, "X-Original-$head")
	or push @problems, "Couldn't renamed $head to X-Original-$head";
    }

  }

  foreach my $head ( qw( Complaints-To Trace ) ) {
    if (defined $article->header("X-$head") ) { 
      $article->rename_header("X-$head", "X-Poster-$head")
	or push @problems, "Couldn't renamed X-$head to X-Poster-$head";
    }
  }

  $article->add_message_id( $group->value('shortname') || "",
			    $group->value('domain')  || "" );
  $article->add_date();

  $article;
}

1;

__DATA__

# header empty   message-id &cleanhead(message-id)
# header empty   Processed-By "&invoker"
# header empty   X-ModBot "$$BOTNAME <$$CONTACT>"

# header empty X-No-Confirm "yes (automatic)" if &no_confirm 
# header empty X-No-Reject  "yes (automatic)" if &no_reject

