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

use CGI qw(:standard);
use FindBin qw($Bin);
use lib "$Bin";
use ourLDAP;

my %_VAR = ( 'PROFILE' => $ARGV[0] || usage(), );
my %USERS = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]
\t$0 deb-server-m98
EOF
        ;
    exit(1);
}

sub get_all_users {
    my ( $config, $ldap, $mesg );

    $config = ldap_init_config( $_VAR{'PROFILE'} );
    $ldap   = ldap_connect($config);

    # user_dn
    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => '(uid=*)',
        attrs  => ['uid']
    );

    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $uid = $entry->get_value('uid') || '';
            $USERS{$uid} = 1 if ( $uid ne '' );
        }
    }
    else {
        die( $mesg->error(), "\n" );
    }
    ####

    # suspended_user_dn
    $mesg = $ldap->search(
        base   => $config->{'suspended_user_dn'},
        scope  => 'sub',
        filter => '(uid=*)',
        attrs  => ['uid']
    );

    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $uid = $entry->get_value('uid') || '';
            $USERS{$uid} = 1 if ( $uid ne '' );
        }
    }
    else {
        die( $mesg->error(), "\n" );
    }
    ####

    ldap_disconnect($ldap);
}

sub main {
    get_all_users();

    foreach ( keys(%USERS) ) {
        print $_, "\n";
    }
}

main();

