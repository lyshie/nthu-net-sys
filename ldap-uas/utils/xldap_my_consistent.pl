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

my %_VAR  = ( 'PROFILE' => $ARGV[0] || usage(), );
my %USERS = ();
my %SN    = ();

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]
\t$0 my
EOF
        ;
    exit(1);
}

sub get_all_users {
    my ($profile) = @_;

    my ( $config, $ldap, $mesg );

    $config = ldap_init_config($profile);
    $ldap   = ldap_connect($config);

    # user_dn
    $mesg = $ldap->search(
        base   => $config->{'user_dn'},
        scope  => 'sub',
        filter => '(uid=*)',
        attrs  => [ 'uid', 'sn', 'cn' ]
    );

    if ( $profile =~ m/^(?:oz|m\d+)$/ ) {
        $profile = 'student';
    }

    if ( !$mesg->code() ) {
        foreach my $entry ( $mesg->entries ) {
            my $uid = $entry->get_value('uid') || '';
            $USERS{$profile}{$uid}{'uid'} = $uid if ( $uid ne '' );

            my $cn = $entry->get_value('cn') || '';
            $USERS{$profile}{$uid}{'cn'} = $cn if ( $cn ne '' );

            my $sn = $entry->get_value('sn') || '';
            $USERS{$profile}{$uid}{'sn'} = $sn if ( $sn ne '' );

            $SN{$profile}{$sn} = $uid;
        }
    }
    else {
        die( $mesg->error(), "\n" );
    }
    ####

    ldap_disconnect($ldap);
}

sub check_consistent {
    my $unit    = $USERS{'my'};
    my $staff   = $USERS{'mx'};
    my $student = $USERS{'student'};

    foreach my $u ( keys(%$unit) ) {
        my $uid;
        my $target;
        if ( $unit->{$u}{'sn'} !~ m/^\d+$/ ) {
            $uid    = $SN{'mx'}{ $unit->{$u}{'sn'} };
            $target = $staff;
        }
        else {
            $uid    = $SN{'student'}{ $unit->{$u}{'sn'} };
            $target = $student;
        }

        if ($uid) {
            my $mesg
                = ( $unit->{$u}{'cn'} ne $target->{$uid}{'cn'} )
                ? 'CN NOT EQ'
                : '';
            printf(
                "OK [%-16s, %-12s, %-16s]\n   [%-16s, %-12s, %-16s] %s\n",
                $unit->{$u}{'uid'},    $unit->{$u}{'cn'},
                $unit->{$u}{'sn'},     $target->{$uid}{'uid'},
                $target->{$uid}{'cn'}, $target->{$uid}{'sn'},
                $mesg,
            );
        }
        else {
            printf(
                "-- [%-16s, %-12s, %-16s]\n   NO MATCH\n",
                $unit->{$u}{'uid'},
                $unit->{$u}{'cn'},
                $unit->{$u}{'sn'},
            );
        }

        print "\n";
    }
}

sub main {
    get_all_users('my');
    get_all_users('mx');
    get_all_users('oz');
    get_all_users('m98');
    get_all_users('m99');
    get_all_users('m100');

    check_consistent();
}

main();

