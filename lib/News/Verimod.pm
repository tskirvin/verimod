$VERSION = "0.50";
package News::Verimod;
our $VERSION = "0.50";

# -*- Perl -*-		Thu Feb 17 10:39:29 CST 2005 
###############################################################################
# Written by Tim Skirvin <tskirvin@killfile.org>
# Copyright 1996-2007, Tim Skirvin.  Redistribution terms are below.
###############################################################################

=head1 NAME

News::Verimod - a news moderation framework

=head1 SYNOPSIS
 
  use News::Verimod;
  use vars qw( %GROUP %DEFAULT %CONFIG $GROUP );
  $GROUP = "humanities.philosophy.objectivism";

  # Populate %DEFAULT and %CONFIG
  do "$ENV{'HOME'}/.verimod/verimodrc";
  
  # Populate %GROUP
  do $CONFIG{$GROUP};
  
  my $verimod = new News::Verimod ( 'default' => \%DEFAULT, 
				    'group'   => \%GROUP );

=head1 DESCRIPTION

News::Verimod is a news moderation framework, designed to work with
News::Gateway and News::Article to read, modify, and post or reject articles as
appropriate for a given group.

More documentation will follow after an actual beta run is complete.

=cut

###############################################################################
### main() ####################################################################
###############################################################################

use strict;
use News::Article;
use Exporter;
use File::Basename;     # for 'basename'
use News::Gateway;
use Net::NNTP;
use Net::NNTP::Auth;
use News::Verimod::PGPMoose;
use News::Verimod::BoilerMIME;

use vars qw( @REQUIRED $MAINTAINER %GROUP );

@REQUIRED   = qw( maintainer submit contact groupname logdir modlist botname ); 
$MAINTAINER = "";
%GROUP      = ();

1;

###############################################################################
### Subroutines ###############################################################
###############################################################################

=head1 USAGE

There are several different categories of functions for News::Verimod -
constructors, internal data access, News::Article methods, News::Gateway
methods, NNTP functions, and miscellaneous.

=cut

###############################################################################
### Subroutines - Constructors ################################################
###############################################################################

=head2 Constructors

The following commands are used to create News::Verimod objects.

=over 4

=item new ( OPTIONS )

Creates a new News::Verimod object.  C<OPTIONS>, a hash of input options,
is used to pass in default values for this object, specifically two
hashrefs: the C<default> hashref, which contains generic options for all
groups (generally set in the verimodrc file), and the C<group> hashref
(set in a group-specific configuration file).

The News::Verimod object contains several types of information.  Standard
information is stored in the SCALAR hash, which is accessed with the
B<set()> and B<value()> functions; this hash contains information about
the newsgroup being moderated.  Default values, set out of the C<group>
and C<default> hashrefs ($group->{item} || $default->{item} || stated
default) unless otherwise noted:

  botname	Name of the moderation 'bot.  No default.
  cachedir	Location where we should cache posts that weren't 
	        able to be posted because the news server was down.  
	        This should be periodically checked to try to repost 
	        the articles later, but that is beyond the scope of 
		this document.  No default.
  contact	Contact address for the newsgroup.  No default.
  groupname	Name of the group we are moderating.  No default.
  logdir	Where to log articles after we've processed them.  
		No default.
  maintainer	Maintainer address for the newsgroup.  Default: 
		$News::Verimod::MAINTAINER
  modlist	The address to contact all of the moderators at.  
		No default.
  pgpmooserc	Location of the pgpmoose config file, used to sign 
		posts.  No default.
  nntpuser	NNTP server username, if necessary.  No default.
  nntppass	NNTP server password, if necessary.  No default.
  nntpserver	NNTP server to connect to.  
		Default: $ENV{'NNTPSERVER'}
  queuedir      Directory for the queued messages, managed by 
                News::Verimod::Queue.  No default, because not all groups
                use it.
  shortname	Short name of the group we are moderating - ie 'hpo' 
		instead of 'humanities.philosophy.objectivism'.  Set 
		from 'groupname', using shortname().
  signature	A filename containing a signature to append to
		auto-response messages, and potentially the end of 
		any posted messages.  No default.
  submit	Article submission address.  No default.
  version	The version of the moderation 'bot.

The following options are set without the C<group> or C<default> hashrefs:

  prog		Program name that we're running out of.  Set from $0
  progdir	Program directory.  Set from $0
  
=cut

sub new { my $self = {};  bless $self, shift;  $self->_init(@_) }

### _init ( OPTIONS )
# Actually performs the work of new() and clone().
sub _init {
  my ($self, %opts) = @_;
  my $default = $opts{'default'} || {};		# Verimodrc generic options
  my $group   = $opts{'group'}   || {};		# Group-specific options

  $$self{'SCALAR'}   = {};	# Scalar values, set with 'set' and 'value'
  $$self{'PGPMOOSE'} = {};	# PGPMoose information
  $$self{'GATEWAY'}  = undef;	# News::Gateway object
  $$self{'ARTICLE'}  = undef;	# News::Article object

  ## If invoked by 'clone', then copy the old information into a new object.
  if (my $old = $opts{'clone'}) { 
    # Clone the old object.  !!!!  (More to it than this...)
    foreach my $area ( qw( SCALAR PGPMOOSE ) ) {
      foreach (keys %{$$old{$area}}) { 
        $$self{$area}->{$_} = $$old{$area}->{$_};
      }
    }
    foreach my $object ( qw( GATEWAY ARTICLE RAWARTICLE) ) {
      $$self{$object} = $$old{$object}->clone if $$old{$object};
    }
    return $self;
  } 
  
  ## We must have a maintainer to make the News::Gateway
  my $maintainer = $$group{'MAINTAINER'} || $$default{'MAINTAINER'} 
		  			 || $MAINTAINER || "";
  $self->set('maintainer', $maintainer);

  unless ($maintainer) { 
    warn "Default maintainer address is not set!\n";
    return "";
  }
  my $gateway = new News::Gateway( 0, $maintainer );
  $$self{GATEWAY} = $gateway;
  
  ## Options to set out of %opts or just by figuring them out on our own.
  $self->set('progdir', $opts{'progdir'} || dirname($0) || "" );
  $self->set('prog',    $opts{'prog'}    || $0          || "" );

  ## Default options to set out of either %group or %default, or at least 
  ## set a nice default value.
  $self->set('pgpmooserc', $$group{'PGPMOOSERC'} || $$default{'PGPMOOSERC'} 
						 || "");
  $self->set('nntpserver', $$group{'NNTPSERVER'} || $$default{'NNTPSERVER'}
			   || $ENV{'NNTPSERVER'} || "");

  $self->set('submit',    $$group{'SUBMIT'}    || $$default{'SUBMIT'}    || "");
  $self->set('contact',   $$group{'CONTACT'}   || $$default{'CONTACT'}   || "");
  $self->set('groupname', $$group{'NEWSGROUP'} || $$default{'NEWSGROUP'} || "");
  $self->set('nntpuser',  $$group{'NNTPUSER'}  || $$default{'NNTPUSER'}  || "");
  $self->set('nntppass',  $$group{'NNTPPASS'}  || $$default{'NNTPPASS'}  || "");
  $self->set('botname',   $$group{'BOTNAME'}   || $$default{'BOTNAME'}   || "");
  $self->set('version',   $$group{'VERSION'}   || $$default{'VERSION'}   || "");
  $self->set('modlist',   $$group{'MODLIST'}   || $$default{'MODLIST'}   || "");
  $self->set('logdir',    $$group{'LOGDIR'}    || $$default{'LOGDIR'}    || "");
  $self->set('cachedir',  $$group{'CACHEDIR'}  || $$default{'CACHEDIR'}  || "");
  $self->set('queuedir',  $$group{'QUEUEDIR'}  || $$default{'QUEUEDIR'}  || "");

  $self->set('shortname', $self->shortname($self->value('groupname')) );
  
  $self->set('signature', $$group{'SIGNATURE'} || "");

  $self;
}

=item clone ()

Creates and returns a new News::Verimod item, cloned from the original
item.  Otherwise, takes the same options as C<new()>.

=cut

sub clone { my $self = shift; (ref $self)->new( 'clone' => $self, @_ ); }

=item configured ()

Checks to see if the group is properly configured, ie if all of the
required variables are set, based on the variables listed in the array
@News::Verimod::REQUIRED.  Returns an array of values that are missing.

Default values of this array: 

  maintainer submit contact groupname logdir modlist botname 

=cut

sub configured {
  my ($self) = @_;
  my @missing = ();
  foreach (@REQUIRED) { push @missing, $_ unless $self->value($_) }
  @missing;
}

=back

=cut

###############################################################################
### Internal Data Access Subroutines ##########################################
###############################################################################

=head2 Internal Data Access

The following subroutines are used to create, modify, and access the
values of the data stored within the object.  

=over 4

=cut

=item set ( KEY, VALUE )

Sets the value of C<KEY> to C<VALUE> in the given object.  If multiple
C<VALUE> keys are offered, they are concatenated together with spaces.
Note that C<KEY> is case-insensitive.  Returns the new value if
successful, undef otherwise.

=cut

sub set {
  my ($self, $entry, @rest) = @_;
  map { $_ = defined($_) ? $_ : "" } @rest;
  my $value = join(' ', @rest); $value =~ s/\s+$//; 
  return undef if $value =~ /^\s*$/;
  $$self{SCALAR}->{lc $entry} = $value;
}

=item unset ( KEY ) 

Unsets the value of C<KEY>.  (This is necessary because B<set()> won't set
an 'undef' value.)

=cut

sub unset {
  my ($self, $key) = @_;
  delete $$self{SCALAR}->{lc $key} if defined $$self{SCALAR}->{lc $key};
}

=item value ( KEY )

Returns the value of C<KEY> in the object.  

=cut

sub value { shift->{SCALAR}->{lc shift}; }

=item keys ()

Returns an array listing all current C<KEY>s in the object.  

=cut

sub keys { keys %{shift->{SCALAR}}; }

=back

=cut

###############################################################################
### Article Subroutines #######################################################
###############################################################################

=head2 News::Article Methods

The following subroutines modify the saved article accessible through
$self->article().  

=over 4

=cut

=item read ( SOURCE )

Reads a News::Article object from C<SOURCE> using C<News::Article::new()>.
The article is saved internally in two versions: a "raw" format version
that is not meant to be edited, and a normal version which is loaded into
News::Gateway.  

=cut

sub read {
  my ($self, @rest) = @_;
  my $article = News::Article->new(@rest);
  $$self{ARTICLE} = $article;
  $$self{GATEWAY}->{Article} = $article;
  $$self{RAWARTICLE} = $article ? $article->clone() : new News::Article;
  $article || $$self{RAWARTICLE};
}

=item article ()

=item rawarticle ()

These functions return the saved News::Article objects mentioned above.  

=cut

sub article    { shift->{ARTICLE} }
sub rawarticle { shift->{RAWARTICLE} }

sub sign_pgpmoose {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $self->article or return 'no article';

  foreach my $group (split (/,/, $article->header ('newsgroups'))) {
    my $pgpinfo = $self->pgpinfo($group);
    if (scalar @$pgpinfo) { 
      my $error = $article->sign_pgpmoose(@$pgpinfo);
      return "PGP Signing Error: $error" if $error;
    } 
  }

  undef;
}

=back

=cut

###############################################################################
### Gateway Subroutines #######################################################
###############################################################################

=head2 News::Gateway 

The following subroutines work with the News::Gateway object accessible
through $self->gateway(), and potentially the News::Article object as well.  

=over 4

=cut

=item gateway ()

Returns the News::Gateway object created by B<new()>.  

=cut

sub gateway { shift->{GATEWAY} }

=item config ( FIXES, COMMANDS, SCORES, SCORECMDS )

=cut

sub config {
  my ($self, $fixes, $commands, $scores, $scorecmds) = @_;
  my $gateway = $self->gateway || return undef;

  $gateway->modules( @$fixes )         	if ($fixes     && ref $fixes)
	or warn "Couldn't set fix modules\n" && return undef;
  $gateway->config_lines( @$commands ) 	if ($commands  && ref $commands)
	or warn "Couldn't set fix commands\n" && return undef;

  # So we don't have to list it explicitly
  if ($scores && ref $scores) { $gateway->modules( 'score' => [] ); }

  $gateway->score_modules( @$scores ) 	if ($scores    && ref $scores)
	or warn "Couldn't set score modules\n" && return undef;
  $gateway->score_config( @$scorecmds ) if ($scorecmds && ref $scorecmds)
	or warn "Couldn't set score commands\n" && return undef;

  $self->configured ? 0 : 1;
}

=item fix ( OPTIONS )

Re-implements B<News::Gateway>'s apply() so that multiple error messages
can be extracted as necessary.  Returns an array of error entries, each of
which is an arrayref containing the name of the module that had an error,
and the actual error message that was returned.  If there are no errors,
returns an empty array.

=cut

sub fix {
  my ($self, %options) = @_;
  my @modules = @{$self->gateway->{mesghooks}};
  my @global_errors;
  foreach my $module (@modules) { 
    my $code = join('', $module, '_mesg');
#    my $article = $self->article;
    my @errors = $self->gateway->$code();
    foreach my $error (@errors) { 
      next unless $error;
      push @global_errors, [ $module, $error ]; 
    }
  }
  return @global_errors if scalar @global_errors;
  return ();
}

=item score ( OPTIONS )

Not yet written.  Well, actually, it's in the auto-stuff.

=cut

=cut 

sub score       { 
  my ($self, %options) = @_;
  my @modules = @{$self->gateway->{scorehooks}};
  my @score;
  foreach my $module (@modules) { 
    my $code = join('', $module, '_score');
    my @resp = $self->gateway->$code();
    foreach my $resp (@resp) { 
      next unless ($resp && ref $resp);
      my ( $score, $text ) = @$resp;
      push @score, [ $module, $score, $text ]; 
    }
  }
  my $scorecount = 0;
  foreach (@score) { $scorecount += @$_[1]; }
  return ($scorecount, \@score);
}

sub scorereport { }

=cut 

=item fixes () 

=item commands ()

=item score_mods ()

=item score_config () 

Return an empty array.  Sub-classes of News::Verimod will override these
functions with code to return the list of fixes, fix configuration
commands, scores, and score configuration commands respectively.

=cut

sub fixes    { () }
sub commands { () }

sub score_mods   { () }
sub score_config { () }

=item approve ()

=item enqueue () 

=item process ()

=item reject ()

Article processing commands.  Sub-classes of News::Verimod will override
these functions with code to approve, enqueue, process, or reject a
message, respectively.

=cut

sub approve { "Not Implemented" }
sub enqueue { "Not Implemented" }
sub process { "Not Implemented" }
sub reject  { "Not Implemented" }

=back

=cut

###############################################################################
### NNTP Subroutines ##########################################################
###############################################################################

=head2 NNTP Functions

The following functions take care of the NNTP connections, article
posting, and other related funcitons.

=over 4

=item connect ( OPTIONS )

Connects to an NNTP server for posting.  Gets authentication information
from B<Net::NNTP::Auth>.  Valid options:

  nntpserver	NNTP server to connect to.  
		Default: $self->value('nntpserver')
  nntpuser	NNTP user to authenticate as.  
		Default: $self->value('nntpuser')
  nntppass	NNTP password to authenticate with.  
		Default: $self->value('nntppass')

Returns the NNTP connection on success, undef otherwise.  Note that the
NNTP connection is cached for future use as necessary.

If you want to override the 'nntpuser' and 'nntppass' functions so that
you do not try to authenticate them, set them to 'undef'.

=cut

sub connect {
  my ($self, %options) = @_;
  if ( my $cache = $self->value('NNTP') ) { return $cache if $cache->connected }

  my $server = $options{'nntpserver'} || $self->value('nntpserver') 
		or (warn "No NNTP Server found!\n" && return undef);
  
  my $nntpuser = $self->value('nntpuser');
     $nntpuser = ( (Net::NNTP::Auth->nntpauth($server))[0] || "" ) 
			unless defined $nntpuser;
  my $nntppass = $self->value('nntppass');
     $nntppass = ( (Net::NNTP::Auth->nntpauth($server))[1] || "" ) 
			unless defined $nntppass;

  my $nntp = new Net::NNTP ($server)
		or (warn "Couldn't connect to $server: $!\n" && return undef);

  if ($nntpuser && defined $nntppass) {
    $nntp->authinfo($nntpuser, $nntppass)
	or (warn "Couldn't authenticate with $server: $!\n" && return undef);
  }
  
  $self->set('NNTP', $nntp);
  
  $nntp;
}

=item post ( OPTIONS )

Posts an article to an NNTP server using B<News::Article::post()>.  If
there are any errors, return those errors; returns 0 on success.  Valid
options:

  article	A News::Article object to post.  
		Default: $self->article
  nntp		A Net::NNTP connection to post to.  
		Default: $self->connect
  cachedir	A cache directory to write messages to if we 
		couldn't connect the first time.  
		Default: $self->value('cachedir')

=cut

sub post {
  my ($self, %options) = @_;
  my $article = $options{'article'} || $self->article or return 'no article';

  my $error;
  my $nntp = $options{'NNTP'} || $self->connect();
  unless ($nntp && ref $nntp) { $error = "Can't connect to server" }
  unless ($error) { return "can't post to server" unless $nntp->postok; }
  
  ## Actually try posting, unless we have an error message
  unless ($error) { 
    local $@; 
    eval { $article->post( $nntp ) }; 
    $error = $@ if $@; 
  }
  $error ||= "";
  
  $error =~ s/\s*$//s;      # Remove trailing whitespace
  if ($error =~ /can\'t\s+connect | couldn\'t\s+connect | server\s+unavailable |
	 	 unable\s+to\s+connect | \s+400 /isx ) { 
    if (my $cachedir = $options{'cachedir'} || $self->value('cachedir')) { 
      $cachedir = $self->fixpath($cachedir);
      warn "Couldn't connect; caching to $cachedir\n";
      return $article->write_unique_file($cachedir) ? undef : $error;
    } else { return $error; }
  } 

  my $id = $article->header('message-id') || "";
  print "Posted article $id\n" if $self->value('verbose');
  return $error || 0;
}

=item connected ( OPTIONS )

Returns 1 if we currently have a valid NNTP connection, 0 otherwise
(checks by asking for the current DATE).  Valid options:

  nntp	An NNTP connection.  Defaults to $self->value('nntp')

=cut

sub connected {
  my ($self, %options) = @_;
  my $nntp = $options{'NNTP'} || $self->value('nntp') || return 0; 
  $nntp->date;  
  defined(fileno($nntp)) ? 1 : 0;
}

=back

=cut

###############################################################################
### Miscellaneous Subroutines #################################################
###############################################################################

=head2 Miscellaneous Subroutines

The following subroutines don't fit into any of the above categories, but
are still necessary to for proper operation.

=over 4

=cut

=item shortname ( STRING )

Returns the short version of the given C<STRING>.  This is sortof like an
acronym, but not quite - it is meant to get a shorter name for a newsgroup
name, splitting on whitespace, .'s, and -'s.  For example:

  rec.games.mecha                 rgm
  news.admin.net-abuse.policy     nanap
  Hello there                     Ht

=cut

sub shortname {
  join '', ( map { s%^(.).*$%$1%; $_ } split /[-.\s]/, $_[1] || $_[0]);
}

=item pgpinfo ( GROUP )

Loads information for use with PGPMoose by parsing the pgpmooserc file, as
detailed in B<News::Verimod::PGPMoose>.  Returns an arrayref containing
three items for the given C<GROUP>: the group name, the passphrase, and
the key ID.  If there is no information regarding this group, returns an
empty arrayref.

=cut

sub pgpinfo {
  my ($self, $group) = @_;
  return [ ] unless $group;
  
  ## Cache this infromation.  
  unless (scalar CORE::keys %{$$self{'PGPMOOSE'}}) {
    my $rcfile = fixpath($self, $self->value('pgpmooserc'));
    return [] unless $rcfile;
    my $pgp = News::Verimod::PGPMoose->parse_pgpmooserc($rcfile);
    $$self{'PGPMOOSE'} = $pgp ? $pgp : {};
  }

  my $pgpmoose = $$self{'PGPMOOSE'};
  my $groupinfo = $$pgpmoose{$group} || return [];
  ref $groupinfo ? return [ $group, @{$groupinfo} ] : return []
}

=item fixpath ( FILE )

Fixes a path name to untaint it and properly decode '~' characters.
Returns the new pathname for C<FILE>, or undef if the data was too
dangerous to use.

=cut

sub fixpath { 
  my ($package, $file) = @_;
  return "" unless $file;
  $file =~ s%^~([^/]*)/% join('', $1 ? (getpwnam($1))[7]
                                       : $ENV{'HOME'}, '/' ) %egx;
  $file=~ /^([-\@\w\/.]+)$/ ? $file = $1
                            : (warn "Bad data in path $file\n" && return "");
  $file;
}	

=item groupinfo ()

Returns an empty hashref.  Sub-classes of News::Verimod will override this
function with code to return the 

=cut

sub groupinfo  { {} }

=back

=cut

=head1 NEWSGROUP DESIGN

=head2 ARTICLE FIXES

=head2 ARTICLE SCORING

score note

=head2 USER INTERFACE

=head1 NOTES

This version represents the first real attempt to standardize everything I have
done with news moderation code since I started worrying about it in 1996.  As
such, it is defintiely worth discussing the history of this package.

The core of this code is based around the 'gateway' package, written by Russ
Allbery; I modified his code to work as a robot moderator for the newsgroup
humanities.philosophy.objectivism, which I began moderating in June 1996.  Over
the next several years I added several more groups to my moderation duties,
including much of news.admin.net-abuse.*; at that point, I decided that I wanted
to re-write large portions of the code, make it more general purpose, and
release it for public use.  I at least finished the first two of those things.

The code has *worked* for years.  It does its job, and most of the time it does
it pretty well - but given how little I understood of software engineering when
I began the project, it has hardly been maintainable or usable by anybody but 
myself.  

This version, though, may change everything.  By basing most of the post
rewrites on News::Gateway, I hope to keep them more useful and maintainable than
by doing them entirely on my own.  Unnecessary portions of code - features that
I never turned out to use very much - have been dropped unceremoniously.  And
the proper documentation has actually been written so I can understand
everything again some day in the future.

We'll see how it works.  For now, here's a beta release that I'm actually proud
enough to put in a public place.

=head1 REQUIREMENTS

B<News::Article>, B<News::Gateway>, newslib

=head1 SEE ALSO

B<News::Verimod::BoilerMIME>, B<News::Verimod::PGPMoose>

=head1 TODO

Update the documentation a bit more.  Get this released (finally!).

Create required directories if necessary.

=head1 AUTHOR

Tim Skirvin <tskirvin@killfile.org>

=head1 HOMEPAGE

B<http://www.killfile.org/~tskirvin/software/verimod/>

=head1 LICENSE

This code may be redistributed under the same terms as Perl itself.

=head1 COPYRIGHT

Copyright 1996-2007, Tim Skirvin <tskirvin@killfile.org>

=cut

1;

package News::Gateway;

sub modules {
  my $self = shift;
  my $module;
  while (defined ($module = shift)) {
    if (ref $_[0]) {
      my $method = $module . '_init';
      $self->$method (@{+shift});
    }
    push (@{$$self{mesghooks}}, $module);
  }
}

###############################################################################
### Version History ###########################################################
###############################################################################
# 0.50		Wed Feb 23 15:55:07 CST 2005 
### Actually reasonably documented and working version, now relying very 
### heavily on News::Gateway.
