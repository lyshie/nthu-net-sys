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
use Authen::Passphrase;
use String::Random qw(random_regex);
use JSON;

use lib "$Bin";
use lib_crypt;
use ourSession;
use ourLanguage;
use ourLDAP;
use ourUtils;
use ourError;
use ourTemplate;
use ValidateCheck;

#
my %_GET       = ();
my $MAGIC_PATH = "$Bin/magic";

#
sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : '';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'uid'}      = defined( param('uid') )      ? param('uid')      : '';
    $_GET{'password'} = defined( param('password') ) ? param('password') : '';

    $_GET{'validate'} = defined( param('validate') ) ? param('validate') : '';
    $_GET{'host'}     = defined( param('host') )     ? param('host')     : '';
}

sub generate_magic {
    my $magic = random_regex('[a-z0-9]{48}');

    open( FH, ">$MAGIC_PATH/$magic" );
    close(FH);

    return $magic;
}

sub main {
    read_param();

    if (   ( checkRemoteValidate( $_GET{'validate'}, $_GET{'host'} ) == 0 )
        || ( $_GET{'profile'} eq '' )
        || ( $_GET{'uid'} eq '' ) )
    {
        print header( -charset => 'utf-8', -type => 'text/plain' );
        print "Authentication error! Please try again!\n";
        _L( $0, "Authentication error (" . encode_json( \%_GET ) . ")" );
    }
    else {
        my $config = ldap_init_config( $_GET{'profile'} );
        my $ldap   = ldap_connect($config);
        my $users  = ldap_get_user( $ldap, $config, $_GET{'uid'} );

        if ( scalar(@$users) > 0 ) {
            my $password = $users->[0]->{'userpassword'};
            my $ppr;

            # lyshie_20110331: avoid {_STOP|SUSPEND_} password scheme error
            eval { $ppr = Authen::Passphrase->from_rfc2307($password); };
            if ( $ppr && $ppr->match( $_GET{'password'} ) ) {
                my $name = $users->[0]->{'cn'} || '';

                #my $id   = $users->[0]->{'sn'} || '';
                my $ip        = $ENV{'REMOTE_ADDR'} || '';
                my $timestamp = time();
                my $data      = <<EOF
charset = utf-8
name = $name
id = $_GET{'uid'}\@$_GET{'profile'}
ip = $ip
timestamp = $timestamp
EOF
                    ;
                my $magic = generate_magic();
                print redirect(
                    -uri => "index.cgi?magic=$magic&amp;ACIXSTORE=&amp;data="
                        . lib_crypt::encrypt($data) );
            }
            else {
                print header( -charset => 'utf-8', -type => 'text/plain' );
                print "Password not match! Please try again!\n";
                _L( $0,
                    "Password not match (" . encode_json( \%_GET ) . ")" );
            }
        }
        else {
            print header( -charset => 'utf-8', -type => 'text/plain' );
            print "User not exist OR password not match! Please try again!\n";
            _L( $0,
                      "User not exist OR password not match ("
                    . encode_json( \%_GET )
                    . ")" );
        }
    }
}

main();
