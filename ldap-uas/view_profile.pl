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

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;
}

sub get_profile_data {
    my @result = ();

    my $config = ldap_init_config( $_GET{'profile'} );

    foreach my $k ( sort( keys(%$config) ) ) {
        next if ( $k =~ m/bindpw/ );
        push(
            @result,
            {   'KEY'   => $k,
                'VALUE' => ( ref( $config->{$k} ) eq 'ARRAY' )
                ? join( ', ', @{ $config->{$k} } )
                : $config->{$k},
            }
        );
    }

    return \@result;
}

sub main {
    read_param();

    my $template
        = HTML::Template->new( filename => getTemplate("view_profile.tmpl") );
    $template->param( PROFILE      => _H( $_GET{'profile'} ) );
    $template->param( LOOP_CONFIGS => get_profile_data() );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
