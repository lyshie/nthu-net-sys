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
use ourUtils;

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'uid'} = defined( param('uid') ) ? param('uid') : '';

    $_GET{'confirm'} = defined( param('confirm') ) ? param('confirm') : '';
}

# lyshie: the following codes should be moved to new function
sub do_action {
    my $result  = '';
    my $log_msg = '';

    if ( $_GET{'confirm'} eq '1' ) {
        my $config = ldap_init_config( $_GET{'profile'} );
        my $ldap   = ldap_connect($config);

        my $users = ldap_get_user_suspended( $ldap, $config, $_GET{'uid'} );
        my $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            . 'adm-restore('
            . time() . ','
            . getRemoteAddr() . ');'
            : '';
        my $mesg
            = $ldap->modify(
            'uid=' . $_GET{'uid'} . ',' . $config->{'suspended_user_dn'},
            replace => { 'description' => $description, } );

        $mesg = $ldap->moddn(
            'uid=' . $_GET{'uid'} . ',' . $config->{'suspended_user_dn'},
            newrdn      => 'uid=' . $_GET{'uid'},
            newsuperior => $config->{'user_dn'},
        );

        if ( !$mesg->code() ) {
            $log_msg = sprintf( "OK: Restore user [uid = %s]", $_GET{'uid'} );
            $result .= $log_msg . "\n";
        }
        else {
            $log_msg = sprintf( "FAIL: Restore user [uid = %s], [error = %s]",
                $_GET{'uid'}, $mesg->error() );
            $result .= $log_msg . "\n";
        }

        ldap_disconnect($ldap);

        _L( $0, $log_msg );    # syslog
    }

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template
        = HTML::Template->new( filename => getTemplate("restore_user.tmpl") );
    $template->param( PROFILE => $_GET{'profile'} );
    $template->param( UID     => _H( $_GET{'uid'} ) );
    $template->param( CONFIRM => $_GET{'confirm'} );
    $template->param( RESULT  => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
