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
    'BASEDN'  => $ARGV[1] || 0,
);

my %USERS = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE] [BASEDN]
\t$0 oz        0/1
EOF
        ;
    exit(1);
}

sub llegal_user {
    my ( $config, $ldap, $mesg, $result );

    $config = ldap_init_config( $_VAR{'PROFILE'} );

    $result = '';

    $ldap = Net::LDAP->new(
        $config->{'host'}->[0],
        async   => 1,
        timeout => $config->{'timeout'},
    );

    $ldap->bind( $config->{'binddn'}, password => $config->{'bindpw'} );

    $mesg = $ldap->search(
        base => $_VAR{'BASEDN'} ? $config->{'basedn'} : $config->{'user_dn'},
        scope  => 'sub',
        filter => $config->{'user_filter'},
        attrs  => [ 'uid', 'cn', 'sn', 'userpassword' ],
    );

    foreach my $entry ( $mesg->entries() ) {
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

        my $userpassword
            = defined( $entry->get_value('userpassword') )
            ? $entry->get_value('userpassword')
            : '';

        if ( $userpassword !~ m/^{CRYPT}/ ) {
            $result .= sprintf( "%-18s [sn=%s] [cn=%s] [userpassword=%s]\n",
                $uid, $sn, $cn, $userpassword );

            if ( $_VAR{'BASEDN'} ) {
                $result .= sprintf(
                    " " x 19 . "[dn=%s]\n",
                    $entry->dn() ? $entry->dn() : ''
                );
            }
        }
    }

    if ( !$mesg->code() ) {
        $result .= sprintf( "\nTotal Query: %s\n", $mesg->count() );
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

    $result = llegal_user();

    return $result;
}

sub main {
    my $result = do_action();

    print $result, "\n";
}

main();
