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

my %COUNT = ();

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

        foreach my $e (@events) {
            if ( $e =~ m/([a-zA-Z\-_]+)\((\d+)(?:,)*([^,]*)(?:,)*(.*)\)/ ) {
                my $timestamp = $2;
                my $time      = scalar( localtime($2) );
                my $event     = $1 || 'unknown';
                my $ip        = $3 || '-';
                my $tag       = $4 || '-';

                my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime($2);
                $year += 1900;
                $mon  += 1;

                if ( $event =~ m/^(.*chpasswd)$/ ) {
                    my $tag = $1;
                    my $date
                        = sprintf( "%04d-%02d-%02d", $year, $mon, $mday );

                    #if ($date ge "2011-07-06") {
                        print "$date = $tag ($uid)\n";
                    #}

                    if ( defined( $COUNT{$date} ) ) {
                        $COUNT{$date}++;
                    }
                    else {
                        $COUNT{$date} = 1;
                    }
                    last;
                }
            }
        }
    }

    ldap_disconnect($ldap);

    foreach ( sort keys(%COUNT) ) {
        printf( "%s = %4d\n", $_, $COUNT{$_} );
    }
}

main();
