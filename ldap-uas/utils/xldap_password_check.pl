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
use Authen::Passphrase;
use lib "$Bin";
use ourLDAP;

my %_VAR = ( 'PROFILE' => $ARGV[0] || usage(), );

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]
\t$0 deb-server-m98
EOF
        ;
    exit(1);
}

sub main {
    my $config = ldap_init_config( $_VAR{'PROFILE'} );
    my $ldap   = ldap_connect($config);

    my $users = ldap_get_users( $ldap, $config );

    foreach ( @{$users} ) {
        my $uid         = $_->{'uid'}          || '';
        my $password    = $_->{'userpassword'} || '';
        my $description = $_->{'description'}  || '';

        next if ( $password =~ m/^\{_(?:STOP|SUSPEND)_\}/ );

        my $ppr = Authen::Passphrase->from_rfc2307($password);
        if ( $ppr->match($uid) ) {
            printf( "Username:%16s [SAME AS UID]\n", $uid );
        }

        if ( $description !~ m/chpasswd/ ) {
            printf( "Username:%16s [PASSWORD NOT CHANGE]\n", $uid );
        }
    }

    ldap_disconnect($ldap);

    printf( "=" x 80 . "\n" );
    printf( "Total read: %d\n", scalar( @{$users} ) );
}

main();
