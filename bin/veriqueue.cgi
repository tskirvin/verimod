#!/usr/local/bin/perl -Tw
use vars qw( $VERSION %OPTS @RCFILE @MODULES $CLASS $ROOTCLASS $DEBUG
	     $TESTING $NEWSGROUP $VERIMODRC %CONFIG %DEFAULT %GROUP
             %PGPMOOSE $HTML $HTMLHEAD $HTMLFOOT );
$VERSION = "0.10";	# Tue 06 Mar 13:34:51 CST 2007

###############################################################################
### Configuration + Private Data ##############################################
###############################################################################

## Modify and uncomment this to use user code instead of just system-wide
## modules.  Note that this path must be set up as a standard Perl tree;
## I'd personally recommend just installing things system-wide unless you're
## a developer.

# use lib '/FULL/PATH/TO/PERL';
use lib '/home/tskirvin/dev/news-archive';
use lib '/home/tskirvin/dev/news/news-verimod';
use lib '/home/tskirvin/dev/news/news-gateway';

BEGIN {
  use vars qw( $DEBUG $TITLE $HTMLHEAD $HTMLFOOT $HTMLBODY $STYLESHEET $GROUP );
  $CONFIG = "./veriqueue.conf";
  do "$CONFIG" or die "No config file $CONFIG: $!\n";
}

###############################################################################
### main() ####################################################################
###############################################################################

use CGI;
use News::Article;
use News::Verimod;
use News::Verimod::ModNotes;
use News::Verimod::Queue::HTML;
use IO::Capture::Stdout;
use strict;
use warnings;

$|++;		        # Make sure all messages are printed in order
delete $ENV{'PATH'};    # Make things happier for taintwatch
my $cgi = new CGI || die "Couldn't open CGI";


### main ( GROUP, QUEUE )
# Actually does the work of the module.  Most of the rest of this module
# can be fairly stable, but
sub main {
  my ($group, $queue, $params) = @_;
  my @return = choose_output(@_);
  wantarray ? @return : join("\n", @return, '');
}

sub choose_output {
  my ($group, $queue, $params) = @_;

  my $action = $$params{'action'} || 'listcss';
  my $msgid =  $$params{'msgid'}  || "";

  $msgid = join('', '<', $msgid, '>');
  $msgid =~ s/^<</</g;  $msgid =~ s/>>$/>/g;

  my $msgid_pretty = News::Web->html_clean($msgid);

  if (lc $action eq 'view') {
    Usage() unless $msgid;
    my $article = $queue->get_article('id' => $msgid)
                        or Error('ERROR', "Couldn't get article from queue");
    Error('ERROR', $article ) unless ref $article;       # got some text
    return News::Web->_html_article( $article );

  ## Approve the message in the queue.  STDOUT is captured so we can do 
  ## something useful with it.
  } elsif (lc $action eq 'approve') {

    my $capture = IO::Capture::Stdout->new();
    $capture->start();
    my $resp = $queue->approve_from_queue( 'id' => $msgid, 'verimod' => $group,
                         'testing' => $TESTING, 
                         ( $group->groupopts ),
                         'nouserconfirm' => $$params{'nouserconfirm'} ? 1 : 0 );
    $capture->stop();
    
    return $resp if $resp;

    my @return = "<h2> Approving Article $msgid_pretty </h2>";
    if ($resp) { 
      push @return, " <h4> Error: $resp </h4>";
    } else {
      push @return, "<div class='pre'>\n";
      while (my $l = $capture->read) { push @return, News::Web->html_clean($l) }
      push @return, "</div>\n";
    }

    return @return;

  ## Approve the message, but don't send a confirmation message to the 
  ## user.  
  } elsif (lc $action eq 'approvequiet') {
    $$params{'nouserconfirm'} = 1;   $$params{'action'} = 'approve';
    return choose_output($group, $queue, $params);

  ## Reject the message in the queue.  STDOUT is captured so we can do 
  ## something useful with it.
 
  ## Still need to get rejectreasons from multiple sources.
  } elsif (lc $action eq 'reject') {

    my $reject_reasons = $$params{'reject_reasons'} || "";
    my @reasons = News::Verimod::ModNotes->parse_modnotes(
                        split("\n", $reject_reasons));
    


    my $capture = IO::Capture::Stdout->new();
    $capture->start();
    my $resp = $queue->reject_from_queue( 'id' => $msgid, 'verimod' => $group,
                'testing' => $TESTING, 'reason' =>  [ @reasons ], 
                ( $group->groupopts ), 
                'nouserreject' => $$params{'nouserreject'} ? 1 : 0 );
    $capture->stop();

    my @return = "<h2> Rejecting Article $msgid_pretty </h2>";
    if ($resp) { 
      push @return, " <h4> Error: $resp </h4>";
    } else {
      push @return, "<div class='pre'>\n";
      while (my $l = $capture->read) { push @return, News::Web->html_clean($l) }
      push @return, "</div>\n";
    }

    return @return;

  ## Reject the message, but don't send a rejection notice to the user.  
  ## (Generally used for spam.)
  } elsif (lc $action eq 'rejectquiet') {
    $$params{'nouserreject'} = 1;   $$params{'action'} = 'reject';
    return choose_output($group, $queue, $params);

  ## Prints basic information on every entry in the queue.
  } elsif (lc $action eq 'listqueue') {
    my @return = "<h2>Queue - " . $group->value('groupname') . "</h2>";
    push @return, $queue->listqueue_html_table;
    return @return;

  ## Prints more detailed information on all 'queue' type items in the 
  ## queue, so that the moderator can manage the article properly.  
  } elsif (lc $action eq 'listcss') {
    my @return = "<h2>Messages in Queue - " . $group->value('groupname') . "</h2>";
    push @return, $queue->listqueue_html_css('gateway' => $group);
    return @return;

  } else { Usage() }

  0;
}


###############################################################################
### Command-Line Configuration and Initial Setup ##############################
###############################################################################

my $params = {};
foreach ($cgi->param) { $$params{$_} = $cgi->param($_); }

$TESTING = 1 if $$params{'testing'};    $DEBUG = 1 if $$params{'debug'};  

my $verimodrc = News::Verimod->fixpath($VERIMODRC);
if (-r $verimodrc) { do $verimodrc or Error('CONFIG', 
                                            "Couldn't load $verimodrc: $@\n") }
else               { Error('CONFIG', "Cannot read '$verimodrc'") }

my $newsgroup = $GROUP;
Error('CONFIG', "No newsgroup chosen") unless $newsgroup;

my $config = $CONFIG{$newsgroup};
   $config = News::Verimod->fixpath($config);

if (-r $config) { do $config or die "Couldn't load $config: $@\n"; }
else            { Error('CONFIG', "Cannot read '$config'") }

## If we don't have anything yet, give up
Error('CONFIG', "No/invalid configuration for $newsgroup") unless $CLASS;

## Create the News::Verimod::Queue object
my $queuedir = $CLASS->groupinfo->{'QUEUEDIR'} || "";
   $queuedir = News::Verimod->fixpath($queuedir);
Error('CONFIG', "No queue directory set for $CLASS") unless $queuedir;

my $queue = new News::Verimod::Queue::HTML('dir' => $queuedir, 'readonly' => 1)
        || Error("Couldn't make queue from $queuedir: $!");

## Create the News::Verimod object
my $group = new $CLASS ( 'default' => \%DEFAULT, 'group' => \%GROUP )
                or Error('CONFIG', "Couldn't create $CLASS object");
$group->set('testing', $TESTING);       $group->set('debug', $DEBUG);

## Configure the News::Gateway object
$group->config( [ $CLASS->fixes ],      [ $CLASS->commands ],
                [ $CLASS->score_list ], [ $CLASS->score_cmds ] )
        or Error('CONFIG', "Couldn't configure $CLASS object");

## Just a sample to ensure that the group has been configured as well.
my @missing = $group->configured;
Error('CONFIG', "Not configured: missing " . join(", ", @missing)) if @missing;

# html_stdout();
( print $cgi->header(), &$HTMLHEAD($TITLE,
                        -style => {-src=>$STYLESHEET}), "\n" ) && $HTML++;
print &$HTMLBODY( $group, $queue, $params );
print &$HTMLFOOT($DEBUG);

exit 0;

###############################################################################
### Subroutines ###############################################################
###############################################################################

BEGIN { use vars qw( %ERRORCODES );
	our %ERRORCODES = 	(
	'INFO'		=> 	0, 	'CONFIG'	=> 	1,
	'ERROR'		=>	1, 	'PROCESSED'	=>	0,
	'UNPROCESSED'	=> 	1,
				); }

### Error
# Errors the program with the proper error message
sub Error {
  my ($code, @reason) = @_;
  print CGI->header(), &$HTMLHEAD("Error in '$0'",
                -style => {-src=>$STYLESHEET}) unless $HTML;

  print "This script failed for the following reasons: <p>\n<ul>\n";
  foreach (@reason) { next unless $_; print "<li>", canon($_), "<br />\n"; }
  print "</ul>\n";

  print &$HTMLFOOT($DEBUG);
  exit $ERRORCODES{'ERROR'} || 0;
}

## canon ( ITEM )
# Returns a printable version of whatever it's passed.  Used by Error().

sub canon {
  my $item = shift;
  if    ( ref($item) eq "ARRAY" )   { join(' ', @$item) }
  elsif ( ref($item) eq "HASH" )    { join(' ', %$item) }
  elsif ( ref($item) eq "" )        { $item }
  else                              { $item }
}



## html_head ( TITLE [, OPTIONS] )
# Prints off a basic HTML header, with debugging information.  Extra
# options are passed through to start_html.

sub html_head {
  my $title = shift || $TITLE || "";
  use CGI;   my $cgi = new CGI;
  $cgi->start_html( -title => $title, @_ );
}


## html_body ( DB, PARAMS [, OPTIONS] )
# Prints off the HTML body.
sub html_body { }

## html_foot ( DEBUG [, OPTIONS] )
# Prints off a basic HTML footer, with debugging information.

sub html_foot {
  my $debug = shift || $DEBUG;
  use CGI;   my $cgi = new CGI;
  my @return = debuginfo($debug);
  push @return, $cgi->end_html(@_);
  join("\n", @return, "");
}

sub debuginfo {
  my $debug = shift || 0;

  my @return;
  if ($debug) {
    push @return, "<hr />", "<h2> Debugging Information </h2>";

    if ($debug & 1) {
      push @return,  "Parameters: <p>\n<ul>\n";
      foreach ($cgi->param) { push @return,  " <li>$_: ", $cgi->param($_); }
      push @return,  "</ul>";
    }

    if ($debug & 2) {
      push @return,  "Environment Variables: <p>\n<ul>";
      foreach (sort keys %ENV) { push @return, " <li>$_: $ENV{$_}"; }
      push @return,  "</ul>";
    }
    push @return, "<hr />";
  }

  wantarray ? @return : join("\n", @return);
}

sub html_stdout {
  my $pid;
  return if ($pid = open(STDOUT, "|-"));
  die "cannot fork: $!" unless defined $pid;
  my @return;
  while (<STDIN>) { print News::Web->html_clean($_), "<br />" }
  exit;
  wantarray ? @return : join("<br />\n", @return);
}

###############################################################################
### Documentation #############################################################
###############################################################################

=head1 NAME

veriqueue - News::Verimod queue manipulation script

=head1 SYNOPSIS

veriqueue [-hvtd] [-c configfile] [-r rcfile] [-g newsgroup] msgid

=head1 DESCRIPTION

veriscript is used to manipulate an existing News::Verimod queue to
approve or reject posts, list the messages in the queue, and so forth.
It is a part of the News::Verimod package.

	-h		Prints a short help message and exits.
	-v		Prints the version number and exits.
	-t		'Testing' mode - just print what we would have done.
        -d              'Debug' mode - print extra status messages
	-g news.group	Use B<newsgroup> rather than the default
	-r verimodrc	Use F<verimodrc> rather than the default
	-c configfile	Use F<configfile> rather than the default

        -a type         The type of action that we want to take on the queue.
                        Possible actions: [list later]
                        approve, reject, rejectquiet, list, view,

Returns 0 on success, and 1 on failure.

=head1 REQUIREMENTS

News::Verimod and its associated packages.

=head1 SEE ALSO

B<News::Verimod>

=head1 AUTHOR

Tim Skirvin <tskirvin@killfile.org>

=head1 HOMEPAGE

B<http://www.killfile.org/~tskirvin/software/verimod/>

=head1 LICENSE

This code may be used and/or distributed under the same terms as Perl
itself.

=head1 COPYRIGHT

Copyright 1996-2007, Tim Skirvin <tskirvin@killfile.org>.  All rights
reserved.

=cut

###############################################################################
### Version History ###########################################################
###############################################################################
# 0.10          Fri 09 Mar 13:33:17 CST 2007    tskirvin
### Need to find a nice way to print these things first.  Based off of the
### old battloid code.
