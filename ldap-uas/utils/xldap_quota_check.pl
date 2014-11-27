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

my %_VAR = ( 'PROFILE' => $ARGV[0] || usage(), );

my %USERS       = ();
my $USERS_COUNT = 0;

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE] [USERS]
\t$0 m98 "s9800001 s9800002 ..."
EOF
        ;
    exit(1);
}

sub get_users_from_argv {
    if ( defined( $ARGV[1] ) ) {
        %USERS = map { $_ => 1 } split( /[\t\s,:]+/, $ARGV[1] );
    }

    $USERS_COUNT = scalar( keys(%USERS) );
}

sub main {
    get_users_from_argv();

    my $config = ldap_init_config( $_VAR{'PROFILE'} );
    my $ldap   = ldap_connect($config);

    my $users = ldap_get_users( $ldap, $config );

    my $total = scalar( @{$users} );

    my $i = 0;
    foreach my $u ( @{$users} ) {
        next if ( %USERS && !exists( $USERS{ $u->{'uid'} } ) );

        $i++;
        my $tmp = getQuota(
            $config->{'getquota_host'},
            $config->{'getquota_port'},
            $u->{'uid'}
        );

        if ( $tmp =~ /DISK_QUOTA:\s+(\d+?KB)/g ) {
            if (%USERS) {
                printf( "%4s/%4s) %16s = %16s\n",
                    $i, $USERS_COUNT, $u->{'uid'}, $1 );
            }
            else {
                printf( "%4s/%4s) %16s = %16s\n",
                    $i, $total, $u->{'uid'}, $1 );
            }
        }
        else {
            if (%USERS) {
                printf( "%4s/%4s) %16s = %16s ######## FAIL\n",
                    $i, $USERS_COUNT, $u->{'uid'}, 'none' );
            }
            else {
                printf( "%4s/%4s) %16s = %16s ######## FAIL\n",
                    $i, $total, $u->{'uid'}, 'none' );
            }

            print setQuota(
                $config->{'setquota_host'}, $config->{'setquota_port'},
                $u->{'uid'},                $u->{'uidnumber'},
                $config->{'realm_short'},   $config->{'quota_size'},
                ),
                "\n";
        }
    }

    ldap_disconnect($ldap);
}

main();
