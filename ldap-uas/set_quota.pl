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
use Net::Telnet;

use lib "$Bin";
use ourTemplate;
use ourLDAP;
use ourUtils;

my %_GET = ();

sub read_param {
    $_GET{'profile'} = defined( param('profile') ) ? param('profile') : 'm99';
    $_GET{'profile'} =~ s/[^0-9a-zA-Z\-_]//g;

    $_GET{'uid'} = defined( param('uid') ) ? param('uid') : '';

    $_GET{'uidnumber'}
        = defined( param('uidnumber') ) ? param('uidnumber') : '';
    $_GET{'uidnumber'} =~ s/\D//g;

    my $config = ldap_init_config( $_GET{'profile'} );

    $_GET{'quota'}
        = defined( param('quota') )
        ? param('quota')
        : $config->{'quota_size'};

    $_GET{'confirm'} = defined( param('confirm') ) ? param('confirm') : '';
}

sub getQuotas {
    my @result = ();

    my @quotas = qw(
        1M
        5M
        10M
        100M
        200M
        500M
        1G
        1500M
        2G
        2500M
        3G
        5G
        10G
        none
    );

    for my $s (@quotas) {
        my %hash = ();
        $hash{'quota'} = _H($s);
        push( @result, \%hash );
    }

    return \@result;
}

sub do_action {
    my $result  = '';
    my $log_msg = '';

    if ( $_GET{'confirm'} eq '1' ) {
        my $config = ldap_init_config( $_GET{'profile'} );
        $log_msg .= setQuota(
            $config->{'setquota_host'}, $config->{'setquota_port'},
            $_GET{'uid'},               $_GET{'uidnumber'},
            $config->{'realm_short'},   $_GET{'quota'}
            )
            . getQuota(
            $config->{'getquota_host'},
            $config->{'getquota_port'},
            $_GET{'uid'}
            );

        $result .= $log_msg . "\n";

        _L( $0, $log_msg );    # syslog
    }

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template
        = HTML::Template->new( filename => getTemplate("set_quota.tmpl") );
    $template->param( PROFILE    => $_GET{'profile'} );
    $template->param( UID        => _H( $_GET{'uid'} ) );
    $template->param( UIDNUMBER  => _H( $_GET{'uidnumber'} ) );
    $template->param( CONFIRM    => $_GET{'confirm'} );
    $template->param( QUOTA      => _H( $_GET{'quota'} ) );
    $template->param( LOOP_QUOTA => getQuotas() );
    $template->param( RESULT     => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
