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
use String::Random qw(random_regex);
use Net::OpenID::Consumer;
use CGI::Cookie;
use File::Cache;
use LWPx::ParanoidAgent;

use lib "$Bin";
use lib_crypt;
use ourSession;
use ourLanguage;
use ourLDAP;
use ourUtils;
use ourError;

#
my %_GET            = ();
my %_ENV            = ( 'HTTP_HOST' => "https://$ENV{'HTTP_HOST'}/" );
my $SCRIPT_NAME     = $_ENV{'HTTP_HOST'} . "portal/login_openid_dispatch.cgi";
my $CONSUMER_SECRET = "";

#
sub read_param {
    $_GET{'openid_identifier'}
        = defined( param('openid_identifier') )
        ? param('openid_identifier')
        : '';

    $_GET{'openid'} = $_GET{'openid_identifier'};
    $_GET{'openid'} =~ s@(^http://|^(?!https))@https://@
        if $_GET{'openid'} =~ /myopenid/;
}

sub init_consumer {
    my $cgi = CGI->new();
    my $csr = Net::OpenID::Consumer->new(
        ua              => LWPx::ParanoidAgent->new(),
        cache           => File::Cache->new(),
        args            => $cgi,
        consumer_secret => $CONSUMER_SECRET,
        required_root   => $_ENV{'HTTP_HOST'}
    );
}

sub check_url {
    my ($claimed) = @_;
    my $check_url = $claimed->check_url(
        delayed_return => 1,
        return_to      => $SCRIPT_NAME . "?ret=true",
        trust_root     => $_ENV{'HTTP_HOST'},
    );

    print redirect( -uri => $check_url );

    #    print header(), qq{<a href="$check_url">here</a>};
    #    exit(0);
}

sub main {
    read_param();

    if ( param() ) {
        if ( $_GET{'openid'} ) {
            my $csr     = init_consumer();
            my $claimed = $csr->claimed_identity( $_GET{'openid'} );
            if ( defined($claimed) ) {
                check_url($claimed);
            }
            else {
                print header( -charset => 'utf-8', -type => 'text/plain' );
                print $csr->err(), "\n";
            }
        }
        else {
            print header( -charset => 'utf-8', -type => 'text/plain' );
            print "No OpenID parammeter.\n";
        }
    }
    else {
        print redirect( -uri => "login_openid.cgi" );
    }
}

main();

