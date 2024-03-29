use strict;
use warnings;

use lib '../lib';
use POE qw(Component::IRC
Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember);

my $irc = POE::Component::IRC->spawn(
    nick        => 'DocBot',
    server      => 'irc.freenode.net',
    port        => 6667,
    ircname     => 'Documentation Bot',
);

POE::Session->create(
    package_states => [
        main => [ qw(_start irc_001) ],
    ],
);

$poe_kernel->run;

sub _start {
    $irc->yield( register => 'all' );

    $irc->plugin_add(
        'Docs' =>
    POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember->new
    );

    $irc->yield( connect => {} );
}

sub irc_001 {
    $_[KERNEL]->post( $_[SENDER] => join => '#zofbot' );
}
