#!/usr/bin/perl -w

#
#    Copyright (C) 2011~2014 SHIE, Li-Yi (lyshie) <lyshie@mx.nthu.edu.tw>
#
#    https://github.com/lyshie
#	
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation,  either version 3 of the License,  or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful, 
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not,  see <http://www.gnu.org/licenses/>.
#
use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin";
use ourLDAP;
use ourUtils;

my %_VAR = (
    'PROFILE' => $ARGV[0] || usage(),
    'HOURS'   => $ARGV[1] || 24,
);

my %USERS = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE] [HOURS]
\t$0 oz        24
EOF
        ;
    exit(1);
}

sub last_created {
    my ( $config, $ldap, $mesg, $result );

    my $last_time = time() - $_VAR{'HOURS'} * 60 * 60;

    $config = ldap_init_config( $_VAR{'PROFILE'} );

    $result = '';

    $ldap = Net::LDAP->new(
        $config->{'host'}->[0],
        async   => 1,
        timeout => $config->{'timeout'},
    );

    $ldap->bind( $config->{'binddn'}, password => $config->{'bindpw'} );

    print sprintf(
        "Filter: (&%s(createTimestamp>=%s))",
        $config->{'user_filter'},
        unix_to_ldap_time($last_time)
        ),
        "\n" x 2;

    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => sprintf(
            "(&%s(createTimestamp>=%s))",
            $config->{'user_filter'},
            unix_to_ldap_time($last_time)
        ),
        attrs => [ 'uid', 'cn', 'sn', 'createTimestamp' ],
    );

    foreach my $entry ( $mesg->entries() ) {
        my $created_time
            = defined( $entry->get_value('createTimestamp') )
            ? $entry->get_value('createTimestamp')
            : '';
        $created_time = ldap_to_unix_time($created_time);

        my $uid
            = defined( $entry->get_value('uid') )
            ? $entry->get_value('uid')
            : '';

        my $cn
            = defined( $entry->get_value('cn') )
            ? $entry->get_value('cn')
            : '';

        my $sn
            = defined( $entry->get_value('sn') )
            ? $entry->get_value('sn')
            : '';

        $result .= sprintf(
            "%-18s [%s] [sn=%s] [cn=%s]\n",
            $uid, scalar( localtime($created_time) ),
            $sn, $cn
        );
    }

    if ( !$mesg->code() ) {
        $result .= sprintf( "\nTotal: %s\n", $mesg->count() );
    }
    else {
        $result .= sprintf( "\n%s\n", $mesg->error() );
    }

    ldap_disconnect($ldap);
    $ldap = undef;

    return $result;
}

sub do_action {
    my $result = '';

    $result = last_created();

    return $result;
}

sub main {
    my $result = do_action();

    print $result, "\n";
}

main();
