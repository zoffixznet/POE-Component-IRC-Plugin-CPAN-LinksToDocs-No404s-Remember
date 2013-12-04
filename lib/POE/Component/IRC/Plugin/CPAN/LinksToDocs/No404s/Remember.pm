package POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember;

use warnings;
use strict;

our $VERSION = '0.001';

use base 'POE::Component::IRC::Plugin::BasePoCoWrap';
use POE::Component::CPAN::LinksToDocs::No404s::Remember;

sub _make_default_args {
    return (
        response_event   => 'irc_cpan_links_to_docs',
        trigger          => qr/^(?:ur[il]\s*(?:for)?|perldoc)\s+(?=\S+)/i,
        max_length       => 300,
        obj_args         => {},
    );
}

sub _make_poco {
    my $self = shift;
    return POE::Component::CPAN::LinksToDocs::No404s::Remember->spawn(
        debug  => $self->{debug},
        obj_args => $self->{obj_args},
    );
}

sub _make_response_message {
    my $self   = shift;
    my $in_ref = shift;
    my $response = '';
    my @links = @{ $in_ref->{response} };

    my $message_404
    = quotemeta( $self->{obj_args}{message_404} || 'Not found' );
    
    if ( @links > 1 and !$self->{no_filter} ) {
        @links = grep { !/^(?:Network error|$message_404)/ } @links;
    }
    while (
        $self->{max_length} > ( length($links[0]) + length $response )
    ) {
        $response .= ' ' . shift @links;

        defined $links[0]
            or last;
    }

    return [ substr $response, 1 ];
}

sub _make_response_event {
    my $self = shift;
    my $in_ref = shift;

    return {
        tags     => $in_ref->{tags},
        response => $in_ref->{response},

        map { $_ => $in_ref->{"_$_"} }
            qw( who channel  message  type ),
    }
}

sub _make_poco_call {
    my $self = shift;
    my $data_ref = shift;

    my %seen;
    my $tags = join q|,|,
                grep { not $seen{$_}++ }
                    split q|,|, delete $data_ref->{what};

    $self->{poco}->link_for( {
            event       => '_poco_done',
            tags        => $tags,
            map +( "_$_" => $data_ref->{$_} ),
                keys %$data_ref,
        }
    );
}

1;
__END__


=head1 NAME

POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember - link to http://search.cpan.org/ documentation from IRC (and check that all links lead to existing docs, remembering which ones work)

=head1 SYNOPSIS

    use strict;
    use warnings;

    use POE qw(Component::IRC  Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember);

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
            'DocLinks' =>
                POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember->new
        );

        $irc->yield( connect => {} );
    }

    sub irc_001 {
        $_[KERNEL]->post( $_[SENDER] => join => '#zofbot' );
    }

    <Zoffix> DocBot, perldoc map
    <DocBot> http://perldoc.perl.org/functions/map.html
    <Zoffix> DocBot, uri map,grep,File::Find,SomeWeirdModuleThatDoesn'tExist
    <DocBot> http://perldoc.perl.org/functions/map.html
             http://perldoc.perl.org/functions/grep.html
             http://search.cpan.org/perldoc?File::Find
             Not found

=head1 DESCRIPTION

This module is a L<POE::Component::IRC> plugin which uses
L<POE::Component::IRC::Plugin> for its base. It provides means to get
links to documentation on L<http://search.cpan.org/> by giving the plugin
predefined "tags" or names of modules on CPAN.
It accepts input from public channel events, C</notice> messages as well
as C</msg> (private messages); although that can be configured at will.
For predefined "tags"
see documentation for L<CPAN::LinksToDocs::No404s> module.

B<Note:> plugin filters out duplicate tags. In other words if the request
is C<map,map,map> you'll get only one link in return.

B<Note 2:> plugin stores links to modules (which weren't 404ed) in an
SQLite file, you can change the name of that file via C<obj_args> argument.

=head1 CONSTRUCTOR

=head2 new

    # plain and simple
    $irc->plugin_add(
        'DocLinks' => POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember->new
    );

    # juicy flavor
    $irc->plugin_add(
        'DocLinks' =>
            POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember->new(
                auto             => 1,
                response_event   => 'irc_cpan_links_to_docs',
                banned           => [ qr/aol\.com$/i ],
                addressed        => 1,
                trigger          => qr/^docs\s+(?=\S)/i,
                listen_for_input => [ qw(public notice privmsg) ],
                obj_args         => {
                    tags    => { foos => 'bars' },
                    db_file => 'working_links.db',
                },
                no_filter        => 1,
                max_length       => 300,
                eat              => 1,
                debug            => 0,
            )
    );

The C<new()> method constructs and returns a new
C<POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember> object
suitable to be
fed to L<POE::Component::IRC>'s C<plugin_add> method. The constructor
takes a few arguments, but I<all of them are optional>. The possible
arguments/values are as follows:

=head3 auto

    ->new( auto => 0 );

B<Optional>. Takes either true or false values, specifies whether or not
the plugin should auto respond to requests. When the C<auto>
argument is set to a true value plugin will respond to the requesting
person with the results automatically. When the C<auto> argument
is set to a false value plugin will not respond and you will have to
listen to the events emited by the plugin to retrieve the results (see
EMITED EVENTS section and C<response_event> argument for details).
B<Defaults to:> C<1>.

=head3 response_event

    ->new( response_event => 'event_name_to_recieve_results' );

B<Optional>. Takes a scalar string specifying the name of the event
to emit when the results of the request are ready. See EMITED EVENTS
section for more information. B<Defaults to:> C<irc_cpan_links_to_docs>

=head3 banned

    ->new( banned => [ qr/aol\.com$/i ] );

B<Optional>. Takes an arrayref of regexes as a value. If the usermask
of the person (or thing) making the request matches any of
the regexes listed in the C<banned> arrayref, plugin will ignore the
request. B<Defaults to:> C<[]> (no bans are set).

=head3 trigger

    ->new( trigger => qr/^docs\s+(?=\S)/i );

B<Optional>. Takes a regex as an argument. Messages matching this
regex will be considered as requests. See also
B<addressed> option below which is enabled by default. B<Note:> the
trigger will be B<removed> from the message, therefore make sure your
trigger doesn't match the actual data that needs to be processed.
B<Defaults to:> C<qr/^(?:ur[il]\s*(?:for)?|perldoc)\s+(?=\S+)/i>

=head3 addressed

    ->new( addressed => 1 );

B<Optional>. Takes either true or false values. When set to a true value
all the public messages must be I<addressed to the bot>. In other words,
if your bot's nickname is C<Nick> and your trigger is
C<qr/^trig\s+/>
you would make the request by saying C<Nick, trig Some::Module>.
When addressed mode is turned on, the bot's nickname, including any
whitespace and common punctuation character will be removed before
matching the C<trigger> (see above). When C<addressed> argument it set
to a false value, public messages will only have to match C<trigger> regex
in order to make a request. Note: this argument has no effect on
C</notice> and C</msg> requests. B<Defaults to:> C<1>

=head3 listen_for_input

    ->new( listen_for_input => [ qw(public  notice  privmsg) ] );

B<Optional>. Takes an arrayref as a value which can contain any of the
three elements, namely C<public>, C<notice> and C<privmsg> which indicate
which kind of input plugin should respond to. When the arrayref contains
C<public> element, plugin will respond to requests sent from messages
in public channels (see C<addressed> argument above for specifics). When
the arrayref contains C<notice> element plugin will respond to
requests sent to it via C</notice> messages. When the arrayref contains
C<privmsg> element, the plugin will respond to requests sent
to it via C</msg> (private messages). You can specify any of these. In
other words, setting C<( listen_for_input => [ qr(notice privmsg) ] )>
will enable functionality only via C</notice> and C</msg> messages.
B<Defaults to:> C<[ qw(public  notice  privmsg) ]>

=head3 obj_args

    ->new( obj_args => {
                tags    => { foos => 'bars' },
                db_file => 'working_links.db',
            },
    )

B<Optional>. The C<obj_args> argument takes a
hashref as a value which will be dereferenced into
L<POE::Component::CPAN::LinksToDocs::No404s::Remember> constructor
(in case you want to add custom tags, change the name of the db file
, etc.). See documentation for L<CPAN::LinksToDocs::No404s::Remember>
for possible arguments.
B<Defaults to:> C<{}> (default constructor)

=head3 no_filter

    ->new( no_filter => 1 );

B<Optional>. By default plugin will filter the IRC message from all
the network errors and 404s. If you want to prevent that and see
a bunch of "Not found" or "Network error: blah" messages set
C<no_filter> argument to a true value. B<Note:> the C<response_event>
will still get full, non-filtered results even no matter of what
the C<no_filter> argument is set to. B<Defaults to:> not set (filter all
404s and network errors)

=head3 max_length

    ->new( max_length => 300 );

B<Optional>. Specifies the maximum length of output sent to IRC (when
C<auto> argument is turned on). B<Note:> only the link(s) whose total length
(including spaces that separate them) is less than C<max_length>
argument's value
(see constructor)
will be spoken in IRC, B<but all> of them will be returned in the response
event. B<Defaults to:> C<300>

=head3 eat

    ->new( eat => 0 );

B<Optional>. If set to a false value plugin will return a
C<PCI_EAT_NONE> after
responding. If eat is set to a true value, plugin will return a
C<PCI_EAT_ALL> after responding. See L<POE::Component::IRC::Plugin>
documentation for more information if you are interested. B<Defaults to>:
C<1>

=head3 debug

    ->new( debug => 1 );

B<Optional>. Takes either a true or false value. When C<debug> argument
is set to a true value some debugging information will be printed out.
When C<debug> argument is set to a false value no debug info will be
printed. B<Defaults to:> C<0>.

=head1 EMITED EVENTS

=head2 response_event

    $VAR1 = {
          'who' => 'Zoffix!n=Zoffix@unaffiliated/zoffix',
          'response' => [
                          'http://perldoc.perl.org/functions/map.html',
                          'http://search.cpan.org/perldoc?Acme::BabyEater',
                          'http://search.cpan.org/perldoc?perlboot',
                          'http://search.cpan.org/perldoc?perltoot',
                          'http://search.cpan.org/perldoc?perltooc',
                          'http://search.cpan.org/perldoc?perlbot'
                        ],
          'type' => 'public',
          'channel' => '#zofbot',
          'message' => 'DocBot, uri map,Acme::BabyEater,OOP',
          'tags' => 'map,Acme::BabyEater,OOP'
        };

The event handler set up to handle the event, name of which you've
specified in the C<response_event> argument to the constructor
(it defaults to C<irc_cpan_links_to_docs>) will recieve input
every time request is completed. The input will come in C<$_[ARG0]> in
a form of a hashref.
The keys/values of that hashref are as follows:

=head2 who

    { 'who' => 'Zoffix!n=Zoffix@unaffiliated/zoffix' }

The usermask of the person who made the request.

=head2 tags

    { 'tags' => 'map,Acme::BabyEater,OOP' }

The user's message after stripping the trigger.

=head2 type

    { 'type' => 'public' }

The type of the request. This will be either C<public>, C<notice> or
C<privmsg>

=head2 channel

    { 'channel' => '#zofbot' }

The channel where the message came from (this will only make sense when the request came from a public channel as opposed to /notice or /msg)

=head2 message

    { 'message' => 'DocBot, uri map,Acme::BabyEater,OOP' }

The full message that the user has sent.

=head2 response

    {
          'response' => [
                          'http://perldoc.perl.org/functions/map.html',
                          'http://search.cpan.org/perldoc?Acme::BabyEater',
                          'http://search.cpan.org/perldoc?perlboot',
                          'http://search.cpan.org/perldoc?perltoot',
                          'http://search.cpan.org/perldoc?perltooc',
                          'http://search.cpan.org/perldoc?perlbot'
          ],
    }

The result of the request. B<Note:> only the link(s) whose total length
(including spaces that separate them) is less than C<max_length>
argument's value
(see constructor)
will be spoken in IRC, B<but all> of them will be returned in the response
event.

=head1 AUTHOR

Zoffix Znet, C<< <zoffix at cpan.org> >>
(L<http://zoffix.com>, L<http://haslayout.net>)

=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-component-irc-plugin-cpan-linkstodocs-no404s-remember at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-IRC-Plugin-CPAN-LinksToDocs-No404s-Remember>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::IRC::Plugin::CPAN::LinksToDocs::No404s::Remember

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-IRC-Plugin-CPAN-LinksToDocs-No404s-Remember>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-IRC-Plugin-CPAN-LinksToDocs-No404s-Remember>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-IRC-Plugin-CPAN-LinksToDocs-No404s-Remember>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-IRC-Plugin-CPAN-LinksToDocs-No404s-Remember>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Zoffix Znet, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

