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
use Mail::POP3Client;
use MIME::EncWords qw(:all);
use Encode qw(from_to);
use Encode::Guess qw/big5-eten utf8/;
use Mail::Header;

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourUtils;
use ourLDAP;
use ourError;

#
my %_POST       = ();
my %_QUOTA_INFO = ();

#
sub read_param {
    $_POST{'sid'} = param('sid') || '';
    $_POST{'sid'} =~ s/[^0-9a-f]//g;

    $_POST{'password'} = param('password') || '';
}

sub mimeDecodeText {
    my ($str) = @_;
    my $result = '';
    my @decoded = decode_mimewords( defined($str) ? $str : '' );
    foreach (@decoded) {
        my ( $data, $charset ) = ( $_->[0], $_->[1] );
        $data    = defined($data)    ? $data    : '';
        $charset = defined($charset) ? $charset : '';
        # lyshie_20120425: fix unknown encoding charset
		unless ($charset) {
            my $decoder = guess_encoding($data);
			if ($decoder) {
				$charset = $decoder->name();
			}
			else {
				$charset = 'big5';
			}
		}
        $charset =~ s/[^a-zA-Z0-9\-_]//g;
        # lyshie_20120425: fix unknown encoding charset
        if ( $charset =~ m/gb(18030|k|2312)/i ) {
            $charset = 'cp936';
        }
        from_to( $data, $charset, 'utf-8' );
        $result .= $data;
    }

    return $result;
}

sub get_quota_and_pop_info {
    my ($id) = @_;

    my $email    = '';
    my $q_info   = '';
    my @pop_info = ();
    my $pop_msg  = '';

    my ( $uid, $profile ) = split( /@/, $id );

    return ( $email, $q_info, \@pop_info, $pop_msg )
        if ( !defined($uid) || !defined($profile) );

    my $config = ldap_init_config($profile);

    $email = $uid . '@' . $config->{'realm'};

    my $line = getQuota( $config->{'getquota_host'},
        $config->{'getquota_port'}, $uid );

    while ( $line =~ m/;\s+([\.\w]+):\s+(\d*\w*)/gs ) {
        $_QUOTA_INFO{$1} = $2;
        $q_info .= "$1=$2\n";
    }

    my $usage = $_QUOTA_INFO{'DISK_USAGE'} || '0';
    my $quota = $_QUOTA_INFO{'DISK_QUOTA'} || '0';

    $usage =~ s/\D//g;
    $quota =~ s/\D//g;

    $_QUOTA_INFO{'DISK_PERCENT'} = sprintf( "%.2f", 100 * $usage / $quota )
        if ($quota);

    # pop3
    if ( $_POST{'password'} ne '' ) {
        my $pop = new Mail::POP3Client(
            HOST    => $config->{'pop_host'},
            PORT    => $config->{'pop_port'},
            TIMEOUT => 10,
        );

        $pop->User($uid);
        $pop->Pass( $_POST{'password'} );

        if ( $pop->Connect() && $pop->Login() ) {
            for ( my $i = 1; $i <= $pop->Count(); $i++ ) {
                my @all     = $pop->Head($i);
                my $head    = Mail::Header->new( \@all, Modify => 0 );
                my $from    = $head->get('from');
                my $subject = $head->get('subject');
                push(
                    @pop_info,
                    {   number  => $i,
                        from    => mimeDecodeText($from),
                        subject => mimeDecodeText($subject),
                    }
                );
            }
        }
        else {
            $pop_msg = $pop->Message();
        }

        $pop->Close();
    }

    return ( $email, $q_info . $line, \@pop_info, $pop_msg );
}

sub main {
    read_param();

    my ( $status, $sid, $h ) = sessionCheck( $_POST{'sid'} );

    if ( $status > 0 ) {
        my ( $role, $degree ) = getRole( $h->{'id'} );

        if ( ( $role eq 'staff' ) && ( $degree eq '' ) ) {
            print redirect( -uri => qq{switch-user.cgi?sid=$sid} );
            exit();
        }

        my $is_exist = isUserExist( $h->{'id'}, $degree, $role );
        my $is_suspended = isUserSuspended( $h->{'id'}, $degree, $role );

        if ($is_suspended) {
            print header( -charset => 'utf-8' );
            print show_user_error(-3);
            exit();
        }

        if ( !$is_exist ) {
            print header( -charset => 'utf-8' );
            print show_user_error(-2);
            exit();
        }

        my ( $email, $q_info, $pop_info, $pop_msg )
            = get_quota_and_pop_info( $h->{'id'} );

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/mailbox-check.tmpl"
        );

        $template->param( SID           => $sid );
        $template->param( LOOP_POP_INFO => $pop_info );
        $template->param( POP_MSG       => $pop_msg );
        $template->param( POP_COUNT     => scalar(@$pop_info) );
        $template->param( PASSWORD      => $_POST{'password'} );
        $template->param( EMAIL         => $email );
        foreach ( keys(%_QUOTA_INFO) ) {
            $template->param( $_ => $_QUOTA_INFO{$_} );
        }

        print header( -charset => 'utf-8', -expires => 'now' ); # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
