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
use JSON;

# lyshie_20110610: compatible for German/Finnish alphabet
#                  Kurt Gödel => Kurt Gödel
use Text::Unaccent::PurePerl qw(unac_string);

use lib "$Bin";
use lib_crypt;
use ourSession;
use ourTemplate;
use ourLanguage;
use ourUtils;
use ourError;
use ourLDAP;

my $data      = param('data')      || '';
my $acixstore = param('ACIXSTORE') || '';
my $magic     = param('magic')     || '';
my $debug     = param('debug')     || '';

$data      =~ s/[^a-zA-Z0-9]//g;
$acixstore =~ s/[^a-zA-Z0-9]//g;
$magic     =~ s/[^a-zA-Z0-9]//g;
$debug     =~ s/[^a-zA-Z0-9]//g;

if ( !param() ) {
    print redirect( -uri => "login.cgi" );
    exit();
}

if ( !lib_crypt::checkAlive( $acixstore, $magic, $debug ) ) {
    print header( -charset => 'utf-8', -expires => 'now' );
    print show_error( "SESSION(0)", "session died", "empty.cgi",
        "回首頁 (Go Home)" );
    exit();
}

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

    $data{'id'} = lc( $data{'id'} );

    # lyshie: strip all spaces in name field
    if ( $data{'name'} !~ m/^[\s\w,\-\.]+$/g ) {
        $data{'name'} =~ s/\s//g;     # half-width space
        $data{'name'} =~ s/　//g;    # full-width space

        # lyshie_20100825: fix characters in html entitites
        $data{'name'} =~ s/(&#\d+;)/encode('utf-8', decode_entities($1))/ge;
    }

    if ( defined( $data{'name_en'} ) ) {

        # lyshie_20100825: fix characters in html entitites
        $data{'name_en'}
            =~ s/(&#\d+;)/encode('utf-8', decode_entities($1))/ge;

        # lyshie_20110610: compatible for German/Finnish alphabet
        #                  Kurt Gödel => Kurt Gödel
        $data{'name_en'} = unac_string( "utf-8", $data{'name_en'} );
    }

    $data{'acixstore'} = $acixstore;

    # lyshie_20110309: if user came from CCXP and had ACIXSTORE
    if ( $data{'acixstore'} ) {
        $data{'persistent_id'} = lc( $data{'id'} );
    }

    # lyshie_20110613: condition process
    $data{'condition'}
        = defined( $data{'condition'} ) ? $data{'condition'} : '';
    $data{'condition_bool'} = getConditionBool( $data{'condition'} );

    # lyshie_20110712: d-day => limit the beginning time
    my ( $role, $degree ) = getRole( $data{'id'} );

    if ( $role eq 'student' ) {
        my $config = ldap_init_config("m$degree");
        if ( defined( $config->{'d_day'} ) ) {
            if ( time() < ldap_to_unix_time( $config->{'d_day'} ) ) {
                print redirect(
                    -uri => "http://net.nthu.edu.tw/2009/portal:countdown",
                    -cache_control => 'no-cache',
                    -pragma        => 'no-cache',
                    -expires       => 'now',
                );
                exit();
            }
        }
    }

    # end d-day

    # lyshie_20111201: unknown role and degree
    if ( $role eq '' ) {
        print header( -charset => 'utf-8', -expires => 'now' );
        print show_error( "ROLE(0)", "unknown id", "empty.cgi",
            "回首頁 (Go Home)" );
        exit();
    }

    my $sid = sessionNew(%data);
    _L( $0, "Login portal ($sid), (" . encode_json( \%data ) . ")" );
    print redirect(
        -uri           => "portal.cgi?sid=$sid",
        -cache_control => 'no-cache',
        -pragma        => 'no-cache',
        -expires       => 'now',
    );
}
else {
    print header( -charset => 'utf-8', -expires => 'now' );
    print show_error( "DECRYPT($retval)", $msg, "empty.cgi",
        "回首頁 (Go Home)" );
}
