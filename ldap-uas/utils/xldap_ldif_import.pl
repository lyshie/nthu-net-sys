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
use Net::LDAP::LDIF;
use Net::LDAP::Util;
use FindBin qw($Bin);
use lib "$Bin";
use ourLDAP;

my %_VAR = (
    'PROFILE'  => $ARGV[0] || usage(),
    'FILENAME' => $ARGV[1] || usage(),
    'SUFFIX'   => $ARGV[2] || usage(),
    'IMPORT'   => $ARGV[3] || usage(),
);

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]      [FILENAME]   [SUFFIX]                   [IMPORT]
\t$0 deb-server-m98 /tmp/cc.ldif dc=cc,dc=nthu,dc=edu,dc=tw dc=import
EOF
        ;
    exit(1);
}

sub main {
    die("[ERROR] Not a file: $_VAR{'FILENAME'}!\n")
        if ( !-f $_VAR{'FILENAME'} );

    # lyshie_20100913: LDAP ignores white-space and case
    $_VAR{'SUFFIX'} =~ s/\s//g;
    $_VAR{'SUFFIX'} = lc( $_VAR{'SUFFIX'} );

    $_VAR{'IMPORT'} =~ s/\s//g;
    $_VAR{'IMPORT'} = lc( $_VAR{'IMPORT'} );

    my ( $total, $read, $not_read, $ok, $fail ) = ( 0, 0, 0, 0, 0 );

    my ( $config, $ldap, $mesg );
    $config = ldap_init_config( $_VAR{'PROFILE'} );
    $ldap   = ldap_connect($config);

    my $ldif
        = Net::LDAP::LDIF->new( $_VAR{'FILENAME'}, "r", onerror => 'undef' );
    while ( not $ldif->eof() ) {
        $total++;
        my $entry = $ldif->read_entry();

        if ( $ldif->error() ) {
            $not_read++;
            print "[ERROR] error message: ", $ldif->error(),       "\n";
            print "[ERROR] error line:\n",   $ldif->error_lines(), "\n";
        }
        else {
            $read++;
            my $dn = $entry->dn();

            # lyshie_20100913: LDAP ignores white-space and case
            $dn =~ s/\s//g;
            $dn = lc($dn);
            if ( $dn =~ m/,\Q$_VAR{'SUFFIX'}\E$/i ) {
                $dn =~ s/,\Q$_VAR{'SUFFIX'}\E$//;
            }

            $entry->dn("$dn,$_VAR{'IMPORT'},$config->{'basedn'}");

            $mesg = $ldap->add($entry);

            if ( !$mesg->code() ) {
                $ok++;
                printf( "OK: import %s\n", $entry->dn() );
            }
            else {
                $fail++;
                printf( "FAIL: cannot import %s (%s)\n",
                    $entry->dn(), $mesg->error() );
            }
        }
    }
    $ldif->done();

    ldap_disconnect($ldap);

    printf( "TOAL = %s (READ = %s, NOT READ = %s), (OK = %s, FAIL = %s)\n",
        $total, $read, $not_read, $ok, $fail );
}

main();
