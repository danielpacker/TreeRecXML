use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'TRParse',
    AUTHOR              => q{"Daniel Packer" <"dp@danielpacker.org">},
    VERSION_FROM        => 'lib/TRParse.pm',
    ABSTRACT_FROM       => 'lib/TRParse.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'TRParse-*' },
);
