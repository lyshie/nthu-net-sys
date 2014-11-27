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

use threads;

#use Smart::Comments;
use FindBin qw($Bin);
use Authen::Passphrase;
use MIME::Base64;
use lib "$Bin";
use ourLDAP;

my $PASSWORD_LIST_FILE = "$Bin/password.lst";
my @WORDS              = ();

my %_VAR = (
    'PROFILE'   => $ARGV[0] || usage(),
    'PLAINTEXT' => $ARGV[1] || 0,
    'FILTER'    => $ARGV[2] || undef,
);

sub usage {
    print <<EOF
Usage:
\t$0 [PROFILE]      [PLAINTEXT] [FILTER]
\t$0 deb-server-m98 0/1          "(uid=xxx)"
EOF
        ;
    exit(1);
}

sub load_password {
    open( FH, $PASSWORD_LIST_FILE )
        or die("Can't open file $PASSWORD_LIST_FILE\n");
    while (<FH>) {
        chomp;
        next if ( $_ =~ m/^#/ );
        push( @WORDS, $_ );
    }
    close(FH);
}

sub crack {
    my ( $uid, $password ) = @_;
    my $ppr = Authen::Passphrase->from_rfc2307($password);

    printf( "Guessing password for %s...\n", $uid );
    foreach my $p (@WORDS) {    ### Working===[%]     done
        if ( $ppr->match($p) ) {
            if ( $_VAR{'PLAINTEXT'} ) {
                return sprintf( "\n[%s] Password hit! [%s]\n", $uid, $p );
            }
            else {
                return sprintf( "\n[%s] Password hit! [%s]\n",
                    $uid, encode_base64($p) );
            }
        }
    }

    return sprintf( "\n[%s] Password OK!\n", $uid );
}

sub main {
    load_password();

    my $config = ldap_init_config( $_VAR{'PROFILE'} );
    my $ldap   = ldap_connect($config);

    my $users = ldap_get_users( $ldap, $config, undef, $_VAR{'FILTER'} );

    my @thrs = ();
    foreach ( @{$users} ) {
        my $uid      = $_->{'uid'}          || '';
        my $password = $_->{'userpassword'} || '';

        my $thr = threads->new( \&crack, $uid, $password );
        push( @thrs, $thr );
    }

    foreach (@thrs) {
        my $ret = $_->join() || '';
        print $ret ;
    }

    ldap_disconnect($ldap);

    printf( "=" x 80 . "\n" );
    printf( "Total read: %d\n", scalar( @{$users} ) );
}

main();
