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

use Time::HiRes qw(gettimeofday tv_interval);
use CGI qw(:standard);
use FindBin qw($Bin);
use lib "$Bin";
use ourLDAP;

my %_VAR = ( 'PROFILE' => $ARGV[0] || usage(), );

my %ENTRY_COUNT = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]
\t$0 deb-server-m98
EOF
        ;
    exit(1);
}

sub count_check {
    my ( $config, $ldap, $mesg, $result );

    $config = ldap_init_config( $_VAR{'PROFILE'} );

    $result = '';

    my ( $t0, $t1, $t2, $t3, $t4 );
    foreach my $host ( @{ $config->{'host'} }, @{ $config->{'cache_host'} } )
    {
        $t0 = [gettimeofday];

        $ldap = Net::LDAP->new(
            $host,
            async   => 1,
            timeout => $config->{'timeout'},
        ) or next;

        $t1 = [gettimeofday];

        $ldap->bind( $config->{'binddn'}, password => $config->{'bindpw'} );

        $t2 = [gettimeofday];

        $mesg = $ldap->search(
            base   => $config->{'basedn'},
            scope  => 'sub',
            filter => '(objectclass=*)',
            attrs  => ['1.1'],
        );

        $t3 = [gettimeofday];

        foreach my $entry ( $mesg->entries() ) {
            my $dn = $entry->dn();
            $ENTRY_COUNT{$dn} = 0 if ( !defined( $ENTRY_COUNT{$dn} ) );
            $ENTRY_COUNT{$dn}++;
        }

        if ( !$mesg->code() ) {
            $result .= sprintf( "%-8s [%s]\n", $mesg->count(), $host );
        }
        else {
            $result .= sprintf( "%-8s [%s]\n", $mesg->error(), $host );
        }

        ldap_disconnect($ldap);
        $ldap = undef;

        $t4 = [gettimeofday];

        $result .= sprintf(
            "\tconnect = %.3f, bind = %.3f, search = %.3f, enum = %.3f, total = %.3f\n",
            tv_interval( $t0, $t1 ),
            tv_interval( $t1, $t2 ),
            tv_interval( $t2, $t3 ),
            tv_interval( $t3, $t4 ),
            tv_interval( $t0, $t4 )
        );
    }

    my $right_value = scalar( @{ $config->{'host'} } )
        + scalar( @{ $config->{'cache_host'} } );

    foreach my $k ( sort( keys(%ENTRY_COUNT) ) ) {
        if ( $ENTRY_COUNT{$k} != $right_value ) {
            print "[$ENTRY_COUNT{$k}] $k\n";
        }
    }

    return $result;
}

sub do_action {
    my $result = '';

    $result = count_check();

    return $result;
}

sub main {
    my $result = do_action();

    print $result, "\n";
}

main();
