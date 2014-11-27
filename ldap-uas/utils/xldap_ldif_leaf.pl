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
    'FILENAME' => $ARGV[0] || usage(),
    'PATH'     => $ARGV[1] || usage(),
);

sub usage {
    print <<EOF
Usage:
\t$0 [FILENAME]   [PATH]
\t$0 /tmp/cc.ldif /tmp
EOF
        ;
    exit(1);
}

sub main {
    die("[ERROR] Not a file: $_VAR{'FILENAME'}!\n")
        if ( !-f $_VAR{'FILENAME'} );
    die("[ERROR] Not a path: $_VAR{'PATH'}!\n") if ( !-d $_VAR{'PATH'} );

    my ( $total, $read, $not_read ) = ( 0, 0, 0 );

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

            my $ldif_leaf
                = Net::LDAP::LDIF->new( "$_VAR{'PATH'}/$dn.ldif", "w",
                onerror => 'warn' );
            $ldif_leaf->write_entry($entry);
            $ldif_leaf->done();
        }
    }
    $ldif->done();

    printf( "TOTAL = %8s (READ = %8s, NOT_READ = %8s)\n",
        $total, $read, $not_read );
}

main();
