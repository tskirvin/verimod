package News::Verimod::DBI;

our $VERSION = "0.1";

use News::Verimod::DBI;
use Exporter;
use vars qw( @EXPORT @EXPORT_OK @ISA );
use strict;
use CGI;
push @ISA, qw( Exporter );

sub timestamp_print {
  my ($self, $timestamp) = @_;
  my @MONTHS = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my ($year, $month, $day, $hour, $minute, $second) = 
                $timestamp =~ m/^(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/;
  return "" unless $year;
  sprintf("%02d %03s %04d, %02d:%02d:%02d", $day, $MONTHS[$month - 1], 
                        $year, $hour, $minute, $second);

}
push @EXPORT_OK, qw( timestamp_print );

sub html_artsummary {
  my ($self, @info) = @_;
  my %entry;
  foreach ($self->fields('Article')) { $entry{$_} = shift @info }
  my @printhead;  
  push @printhead, 
	$entry{Author}  ? "From: @{[ _translate($entry{Author}) ]}"
		        : "From: <i>unknown</i>";
  push @printhead, 
	$entry{Subject} ? "Subject: @{[ _translate($entry{Subject}) ]}"
			: "Subject: <i>unknown</i>";
  push @printhead, 
	$entry{Newsgroups} ? "Newsgroups: @{[ _translate($entry{Newsgroups}) ]}"
			   : "Newsgroups: <i>unknown</i>";
  push @printhead, 
	$entry{MessageID}  ? "Message-ID: @{[ _translate($entry{MessageID}) ]}"
			   : "Message-ID: <i>unknown</i>";
  push @printhead, "Approved: @{[ _translate($entry{Approved}) ]}" 
							if ($entry{Approved});
  push @printhead, "Date: @{[ _translate($entry{Date}) ]}" if ($entry{Date});
  
  push @printhead, "Notes: @{[ _translate($entry{Notes}) ]}" if ($entry{Notes});
  my $status = $entry{Status} ? _translate($entry{Status}) : "<i>unknown</i>";

  my @return = <<EOL;
<div class="article">
 <div class="headers"> @{[ join("<br />\n", @printhead ) ]} </div>
 <div class="actions">
  <span style="text-align: center; font-size: large; font-weight: bold;">Article $entry{ID}</span> <br />
  Status: $status <br />
  <a href="battloid.cgi?action=approve&ID=$entry{ID}">Approve</a> |
  <a href="battloid.cgi?action=reject&ID=$entry{ID}">Reject</a> |
  <a href="article.cgi?ID=$entry{ID}">View</a>
 </div>
</div>
EOL
  
  return wantarray ? @return : join("\n", @return);
}
push @EXPORT_OK, qw( html_artsummary );

sub _translate {
  my $line = shift;
  $line =~ s%<%&lt;%g;  $line =~ s%>%&gt;%g;
  $line;
}


1;
