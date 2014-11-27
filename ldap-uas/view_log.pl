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
use HTML::Template;

use lib "$Bin";
use ourTemplate;
use ourLDAP;

#use ourUtils;
my $GI;
eval "require Geo::IP";
if ($@) {
    require Geo::IP::PurePerl;
    $GI = Geo::IP::PurePerl->new("$Bin/GeoIP.dat");
}
else {
    require Geo::IP;
    $GI = Geo::IP->new( Geo::IP->GEOIP_STANDARD );
}

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'uid'} = defined( param('uid') ) ? param('uid') : '';
}

sub get_log_data {
    my @result = ();

    my $config = ldap_init_config( $_GET{'profile'} );
    my $ldap   = ldap_connect($config);

    my $users = ldap_get_user( $ldap, $config, $_GET{'uid'} );

    my $description
        = defined( $users->[0]->{'description'} )
        ? $users->[0]->{'description'}
        : '';

    ldap_disconnect($ldap);

    my @events = split( /;/, $description );

    foreach my $e ( reverse(@events) ) {
        if ( $e =~ m/([a-zA-Z\-_]+)\((\d+)(?:,)*([^,]*)(?:,)*(.*)\)/ ) {
            push(
                @result,
                {   'TIME'  => scalar( localtime($2) ),
                    'EVENT' => $1,
                    'IP'    => $3 || '-',
                    'TAG'   => $4 || '',
                    'FLAG'  => lc( $GI->country_code_by_addr($3) || 'fam' ),
                }
            );
        }
    }

    return \@result;
}

sub main {
    read_param();

    my $template
        = HTML::Template->new( filename => getTemplate("view_log.tmpl") );
    $template->param( UID         => _H( $_GET{'uid'} ) );
    $template->param( LOOP_EVENTS => get_log_data() );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
