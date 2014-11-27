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
use CGI qw(:standard);
use HTML::Template::Pro;
use Encode qw(from_to encode decode);
use HTML::Entities;

use lib "$Bin";
use lib_crypt;
use ourSession;
use ourTemplate;
use ourLanguage;
use ourUtils;
use ourError;

my $data    = param('data')      || '';
my $session = param('ACIXSTORE') || '';

$data    =~ s/[^a-zA-Z0-9]//g;
$session =~ s/[^a-zA-Z0-9]//g;

#if ( !lib_crypt::checkAlive($session) ) {
#    print header( -charset => 'utf-8', -expires => 'now' );
#    print show_error( "SESSION(0)", "session died" );
#    exit();
#}

my ( $retval, $msg ) = lib_crypt::decrypt($data);

if ( $retval eq 0 ) {
    my %data = ();
    foreach ( split( /\n+/, $msg ) ) {
        my ( $key, $value ) = split( /\s*=\s*/, $_ );
        $data{ lc($key) } = $value;
    }

    if ( defined( $data{'charset'} ) ) {
        my $from_charset = $data{'charset'};
        my $to_charset   = 'utf-8';
        foreach ( keys(%data) ) {
            from_to( $data{$_}, $from_charset, $to_charset );
        }

    }

    # lyshie: strip all spaces in name field
    if ( $data{'name'} !~ m/^\w+$/g ) {
        $data{'name'} =~ s/\s//g;     # half-width space
        $data{'name'} =~ s/　//g;    # full-width space

        # lyshie_20100825: fix characters in html entitites
        $data{'name'} =~ s/(&#\d+;)/encode('utf-8', decode_entities($1))/ge;
    }

    $data{'acixstore'} = $session;

    my $sid = sessionNew(%data);

    my ( $role, $degree ) = getRole( $data{'id'} );

    if ( $degree eq '98' ) {
        print redirect(
            -uri           => "portal.cgi?sid=$sid",
            -cache_control => 'no-cache',
            -pragma        => 'no-cache',
            -expires       => 'now',
        );
    }
    else {
        print redirect(
            -uri           => "stop.cgi?sid=$sid",
            -cache_control => 'no-cache',
            -pragma        => 'no-cache',
            -expires       => 'now',
        );
    }
}
else {
    print header( -charset => 'utf-8', -expires => 'now' );
    print show_error( "DECRYPT($retval)", $msg, "empty.cgi",
        "回首頁 (Go Home)" );
}
