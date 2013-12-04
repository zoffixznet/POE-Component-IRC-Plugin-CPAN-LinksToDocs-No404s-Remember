#!/usr/bin/env perl

use Test::More tests => 3;

BEGIN {
    use_ok('POE::Component::CPAN::LinksToDocs::No404s::Remember');
    use_ok('POE::Component::IRC::Plugin::BasePoCoWrap');
	use_ok( 'POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember' );
}

diag( "Testing POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember $POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember::VERSION, Perl $], $^X" );
