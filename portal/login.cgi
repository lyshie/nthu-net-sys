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
use ourSession;
use ourLanguage;
use ourUtils;
use ourError;
use ourTemplate;
use ourLDAP;

#
my %_GET = ();

#
sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'oz';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;
}

sub main {
    read_param();

    my ( $short, $long ) = getProfiles();
    my @data = ();
    for ( my $i = 0; $i < scalar(@$short); $i++ ) {
        my %hash = ();

        $hash{'PROFILE'} = $short->[$i];

        my $config = ldap_init_config( $short->[$i] );
        $hash{'PROFILE_LONG'} = $config->{'realm'};

        # oz first
        $hash{'SELECTED'} = 1 if ( $short->[$i] eq $_GET{'profile'} );

        next if ( $config->{'disabled'} );
        push( @data, \%hash );
    }

	sub toNumber {
		my ($str) = @_;
		$str =~ s/\D//g;

		return $str || 0;
	}

	@data = sort {toNumber($a->{'PROFILE'}) <=> toNumber($b->{'PROFILE'})} @data;

    my $template = HTML::Template::Pro->new(
        case_sensitive => 1,
        filename       => "$Bin/template/$G_LANG/login.tmpl"
    );

    $template->param( LOOP_PROFILE => \@data );

    print header( -charset => 'utf-8' );    # later output
    $template->output( print_to => \*STDOUT );
}

main();
