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

my %_VAR = ( 'PROFILE' => $ARGV[0] || usage(), );

my $GI;

eval "require Geo::IP";
if ($@) {
    require Geo::IP::PurePerl;
    $GI = Geo::IP::PurePerl->new("$Bin/GeoIP.dat");
}
else {
    require Geo::IP;
    $GI = Geo::IP->new( Geo::IP->GEOIP_STANDARD );
}

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
        my $description = $_->{'description'} || '';
        my $uid         = $_->{'uid'}         || '-';
        my @events = split( /;/, $description );

        foreach my $e ( reverse(@events) ) {
            if ( $e =~ m/([a-zA-Z\-_]+)\((\d+)(?:,)*([^,]*)(?:,)*(.*)\)/ ) {
                my $timestamp = $2;
                my $time      = scalar( localtime($2) );
                my $event     = $1 || 'unknown';
                my $ip        = $3 || '-';
                my $tag       = $4 || '-';

                printf( "%-12s [%-10s] [%-15s] [%-16s] [%s]\n",
                    $uid, $event, $ip, $tag, $GI->country_code_by_addr($ip) );
                last;
            }
        }
    }

    ldap_disconnect($ldap);
}

main();
