#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'TRParse' ) || print "Bail out!\n";
}

diag( "Testing TRParse $TRParse::VERSION, Perl $], $^X" );
