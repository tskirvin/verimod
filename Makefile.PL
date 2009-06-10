use ExtUtils::MakeMaker;

## Basic modules
my $modules = {};   my $manpage = {};
foreach my $module ( 
	qw( News::Verimod News::Verimod::Mbox News::Verimod::Sample 
	    News::Verimod::Boiler News::Verimod::Boiler::Approve 
	    News::Verimod::Boiler::Enqueue News::Verimod::Boiler::Reject )
		   ) {
    my $file = $module;
     $file =~ s/::/\//g;  
     $file =~ s/$/.pm/;
  my $libdir = join('/', '$(INST_LIBDIR)',  $file);
  my $man3   = join('/', '$(INST_MAN3DIR)', "$module.3");
  $$modules{$file} = $libdir; $$manpage{$file} = $man3;
}

WriteMakefile (
    NAME         => 'News::Verimod',
    DISTNAME     => 'News-Verimod',
    MAN3PODS     => $manpage, 
    PM           => $modules,
    EXE_FILES    => [ qw( scripts/battloid ) ],
    PREREQ_PM    => { 'News::Gateway' => 0.43 },
    VERSION_FROM => 'Version.pm',
    dist         => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    'AUTHOR'    => 'tskirvin@killfile.org (Tim Skirvin)',
    'ABSTRACT_FROM'  => 'News/Verimod.pm',

);
