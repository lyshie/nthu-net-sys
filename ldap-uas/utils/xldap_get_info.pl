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

use LWP::UserAgent;
use CGI qw(:standard);
use URI::Escape qw(uri_escape);
use HTML::Tree;
use Encode qw(encode_utf8);

#use CGI::Carp qw(fatalsToBrowser set_die_handler);
use FindBin qw($Bin);
use lib "$Bin";

BEGIN {

    sub handle_errors {
        print "FAIL: internal server error\n";
        exit(1);
    }

    #set_die_handler( \&handle_errors );
}

my %_GET
    = ( 'URL' => 'http://ccc-nthudss.vm.nthu.edu.tw/nthusearch/search.php' );

sub read_param {
    $_GET{'q'}    = defined( param('q') )    ? param('q')    : '';
    $_GET{'type'} = defined( param('type') ) ? param('type') : '1';
    $_GET{'type'} =~ s/[^0-9]//g;
}

sub get_info {
    my $content = '';

    my $ua = LWP::UserAgent->new();
    $ua->timeout(10);

    my $resp = $ua->get(
        sprintf( "%s?q=%s&type=%s",
            $_GET{'URL'},
            uri_escape( $_GET{'q'} ),
            uri_escape( $_GET{'type'} ) )
    );

    if ( $resp->is_success() ) {
        $content = $resp->decoded_content();
    }
    else {
        die( $resp->status_line() );
    }

    my $tree = HTML::TreeBuilder->new();
    $tree->parse($content);
    $tree->eof();

    my @trs = $tree->look_down(
        '_tag'    => 'tr',
        'bgcolor' => qr/(?:#EEEEEE|#cc6600)/
    );

    foreach my $tr (@trs) {
        my @tds = $tr->look_down( '_tag' => 'td' );
        my $line = '';
        foreach (@tds) {
            $line .= encode_utf8( $_->as_text() || "-" ) . "\t";
        }
        print "$line\n";
    }

    $tree->delete();
}

sub safe_check {
    my $addr = $ENV{'REMOTE_ADDR'} || '';

    if ( ( $addr eq '' )
        || $addr !~ m/^(?:140\.114\.64\.|127\.0\.0\.)/ )
    {
        print "FAIL: remote address not allow\n";
        exit(1);
    }
}

sub main {
    read_param();

    print header( -charset => 'utf-8', -type => 'text/plain' );

    safe_check();

    get_info();
}

main();

