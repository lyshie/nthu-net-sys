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
use FindBin qw($Bin);
use lib "$Bin";
use ourLDAP;

my %_VAR = ( 'PROFILE' => $ARGV[0] || usage(), );

my %NO_UID     = ();
my %NO_SN      = ();
my %SAME_SN    = ();
my %MULTI_SN   = ();
my %CASE_SN    = ();
my %ILLEGAL_SN = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]
\t$0 oz
EOF
        ;
    exit(1);
}

sub sn_check {
    my ( $config, $ldap, $mesg, $result );

    $config = ldap_init_config( $_VAR{'PROFILE'} );

    $result = '';

    my ( $t0, $elapsed );

    $t0 = [gettimeofday];

    $ldap = Net::LDAP->new(
        $config->{'host'}->[0],
        async   => 1,
        timeout => $config->{'timeout'},
    );

    $ldap->bind( $config->{'binddn'}, password => $config->{'bindpw'} );

    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => $config->{'user_filter'},
        attrs  => [ 'uid', 'sn' ],
    );

    foreach my $entry ( $mesg->entries() ) {
        my $dn = $entry->dn();
        my $uid
            = defined( $entry->get_value('uid') )
            ? $entry->get_value('uid')
            : '';
        my $sn
            = defined( $entry->get_value('sn') )
            ? $entry->get_value('sn')
            : '';

        $NO_SN{$dn}  = 1 unless ($sn);
        $NO_UID{$dn} = 1 unless ($uid);

        if ( ( $sn ne '' ) && ( $uid ne '' ) && ( lc($sn) eq lc($uid) ) ) {
            $SAME_SN{$dn} = 1;
        }

        if ( $sn ne '' ) {
            $MULTI_SN{ lc($sn) } = 0 unless defined( $MULTI_SN{ lc($sn) } );
            $MULTI_SN{ lc($sn) }++;

            if ( lc($sn) ne $sn ) {
                $CASE_SN{ lc($sn) } = 1;
            }

            if ( lc($sn) !~ m/^(?:\d{6,8}|[a-z]\d{5,5})$/ ) {
                $ILLEGAL_SN{ lc($sn) } = 1;
            }
        }
    }

    if ( !$mesg->code() ) {
        $result .= sprintf( "\n%-8s\n", $mesg->count() );
    }
    else {
        $result .= sprintf( "\n%-8s\n", $mesg->error() );
    }

    ldap_disconnect($ldap);
    $ldap = undef;

    $elapsed = tv_interval($t0);

    $result .= sprintf( "\t\t\t\t\telapsed = %s\n", $elapsed );

    print "=" x 30, "NO_UID", "=" x 30, "\n";
    foreach ( keys(%NO_UID) ) {
        print "$_\n";
    }

    print "=" x 30, "NO_SN", "=" x 30, "\n";
    foreach ( keys(%NO_SN) ) {
        print "$_\n";
    }

    print "=" x 30, "SAME_SN", "=" x 30, "\n";
    foreach ( keys(%SAME_SN) ) {
        print "$_\n";
    }

    print "=" x 30, "MULTI_SN", "=" x 30, "\n";
    foreach ( sort( keys(%MULTI_SN) ) ) {
        print "$_\n" if ( $MULTI_SN{$_} > 1 );
    }

    print "=" x 30, "CASE_SN", "=" x 30, "\n";
    foreach ( sort( keys(%CASE_SN) ) ) {
        print "$_\n";
    }

    print "=" x 30, "ILLEGAL_SN", "=" x 30, "\n";
    foreach ( sort( keys(%ILLEGAL_SN) ) ) {
        print "$_\n";
    }

    return $result;
}

sub do_action {
    my $result = '';

    $result = sn_check();

    return $result;
}

sub main {
    my $result = do_action();

    print $result, "\n";
}

main();
