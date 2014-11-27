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
use HTML::Template::Pro;

use lib "$Bin";
use ourLanguage;
use ourTemplate;
use ourUtils;
use ourLDAP;

my %_GET = ();

sub main {

    # lyshie: log profiles and descriptions
    my ( $short, $long ) = getProfiles();
    my @data = ();
    for ( my $i = 0; $i < scalar(@$short); $i++ ) {
        my %hash = ();

        $hash{'PROFILE'} = _H( $short->[$i] );

        my $config = ldap_init_config( $short->[$i] );
        $hash{'PROFILE_LONG'} = _H( $config->{'name'} );

        push( @data, \%hash );
    }

    # lyshie_20111026: sort profile name by number
    sub toNumber {
        my ($str) = @_;
        $str =~ s/\D//g;

        return $str || 0;
    }

    @data
        = sort { toNumber( $a->{'PROFILE'} ) <=> toNumber( $b->{'PROFILE'} ) }
        @data;

    # end of sort

    my $template
        = HTML::Template::Pro->new( filename => getTemplate("index.tmpl") );

    $template->param( LOOP_PROFILE => \@data );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
