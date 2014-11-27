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

my %USERS = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]
\t$0 m98
EOF
        ;
    exit(1);
}

sub main {

    my $config = ldap_init_config( $_VAR{'PROFILE'} );
    my $ldap   = ldap_connect($config);

    my $users = ldap_get_users( $ldap, $config );

    my $total = scalar( @{$users} );

    my $i = 0;
    foreach my $u ( @{$users} ) {
        $i++;
        print setQuota(
            $config->{'setquota_host'}, $config->{'setquota_port'},
            $u->{'uid'},                $u->{'uidnumber'},
            $config->{'realm_short'},   $config->{'quota_size'},
            ),
            "\n";

        my $tmp = getQuota(
            $config->{'getquota_host'},
            $config->{'getquota_port'},
            $u->{'uid'}
        );

        if ( $tmp =~ /DISK_QUOTA:\s+(\d+?KB)/g ) {
            printf( "%4s/%4s) %16s = %16s\n", $i, $total, $u->{'uid'}, $1 );
        }
        else {
            printf( "%4s/%4s) %16s = %16s ######## FAIL\n",
                $i, $total, $u->{'uid'}, 'none' );
        }
    }

    ldap_disconnect($ldap);
}

main();
