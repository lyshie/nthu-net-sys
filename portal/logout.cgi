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

#
use CGI qw(:standard);
use FindBin qw($Bin);
use HTTP::Headers;
use LWP::UserAgent;

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourError;
use ourTemplate;

#
my %_GET = ();

#
sub read_param {
    $_GET{'sid'} = param('sid') || '';
    $_GET{'sid'} =~ s/[^0-9a-f]//g;
}

#
sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_GET{'sid'} );

    if ( $status > 0 ) {
        my $url = 'empty.cgi';

        # lyshie_20110704: logout CCXP
        if ( defined( $h->{'acixstore'} ) && ( $h->{'acixstore'} ne '' ) ) {
            my $acix_logout_url
                = "https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/logout.php";
            my $acix_referer_url
                = "https://www.ccxp.nthu.edu.tw/ccxp/INQUIRE/";

            my $header = HTTP::Headers->new();
            $header->referer($acix_referer_url);

            my $ua = LWP::UserAgent->new( default_headers => $header );
            $ua->timeout(10);

            my $response = $ua->get(
                "$acix_logout_url?ACIXSTORE=" . $h->{'acixstore'} );
        }

        # domain login
        if ( $h->{'id'} =~ m/@/ ) {
            $url = 'login.cgi';
        }

        # openid login
        if ( $h->{'openid'} ) {
            $url = 'login_openid.cgi';
        }

        sessionDelete( $_GET{'sid'} );
		_L($0, "Logout portal ($_GET{'sid'})");
        print redirect(
            -uri           => $url,
            -cache_control => 'no-cache',
            -pragma        => 'no-cache',
            -expires       => 'now',
        );
    }
    else {

        #        print header( -charset => 'utf-8' );
        #        print show_session_error($status);
        my $url = 'login.cgi';
        print redirect(
            -uri           => $url,
            -cache_control => 'no-cache',
            -pragma        => 'no-cache',
            -expires       => 'now',
        );
    }
}

main();
