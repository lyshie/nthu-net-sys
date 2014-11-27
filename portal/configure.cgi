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
use URI;
use MIME::Lite;
use MIME::Words qw(:all);
use File::Basename;

use lib "$Bin";
use ourSession;
use ourLanguage;
use ourTemplate;
use ourUtils;
use ourLDAP;
use ourError;
use ourTicket;

#
my %_POST = ();

#
sub read_param {
    $_POST{'sid'} = param('sid') || '';
    $_POST{'sid'} =~ s/[^0-9a-f]//g;

    $_POST{'openid'} = param('openid') || '';
    $_POST{'email2'} = param('email2') || '';
}

sub sendMail {
    my ( $data, $subject, $body ) = @_;
    my $msg = MIME::Lite->new(
        From     => $data->{"from"},
        To       => $data->{"email"},
        Subject  => encode_mimeword( $subject, "B", "UTF-8" ),
        Encoding => 'base64',
        Type     => 'TEXT',
        Data     => $body,
    );

    $msg->attr( 'content-type.charset' => 'UTF-8' );
    $msg->replace( 'x-uuid'   => $data->{"ticket_number"} );
    $msg->replace( 'x-mailer' => basename($0) );

    $msg->send();
}

sub getTicketMessage {
    my ($hash) = @_;

    my $template = HTML::Template::Pro->new(
        case_sensitive => 1,
        filename       => "$Bin/template/$G_LANG/ticket_msg.tmpl",
    );

    $template->param( HTTP_HOST => $ENV{'HTTP_HOST'} );
    foreach my $k ( keys(%$hash) ) {
        $template->param( uc($k) => $hash->{$k} );
    }

    return $template->output();
}

sub change_openid_email2 {
    my ( $id, $degree, $openid, $email2, $name, $role ) = @_;

    my ( $config, $ldap, $mesg, $result, $users );
    $result = '';

    my ( $username, $dn, $description, $cn, $url, $mail );

    # lyshie_20101103: normalized the url
    my $uri = URI->new($openid);
    $openid = $uri->canonical()->as_string();

    if ( $degree =~ m/^\d+$/ ) {    # student
        $username = "$id";
        $config   = ldap_init_config("m$degree");
        $ldap     = ldap_connect($config);
        $users    = ldap_get_user( $ldap, $config, $username );

        $dn
            = defined( $users->[0]->{'uid'} )
            ? 'uid=' . $users->[0]->{'uid'} . ',' . $config->{'user_dn'}
            : '';
        $url
            = defined( $users->[0]->{'labeleduri'} )
            ? $users->[0]->{'labeleduri'}
            : '';
        $mail
            = defined( $users->[0]->{'mail'} )
            ? $users->[0]->{'mail'}
            : '';
        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';

        # write OPENID field
        if ( $openid ne $url ) {
            $description
                .= 'chopenid('
                . time() . ','
                . getRemoteAddr() . ','
                . $url . ');';

            if ( defined($openid) && $openid ne '' ) {
                $mesg = $ldap->modify(
                    $dn,
                    replace => {
                        'labeleduri'  => $openid,
                        'description' => $description,
                    }
                );
            }
            else {    # clear OpenID field
                $mesg = $ldap->modify(
                    $dn,
                    replace => {
                        'labeleduri'  => [],
                        'description' => $description,
                    }
                );
            }

            if ( !$mesg->code() ) {
                $result
                    .= "完成變更使用者 $username ($openid) 的 OpenID\n";
                $result .= "Changed OpenID: $username ($openid)\n";
                $result .= "\n";
            }
            else {
                $result
                    .= "無法變更使用者 $username ($openid) 的 OpenID ("
                    . $mesg->error() . ")\n";
                $result .= "Failed to change OpenID: $username ($openid) ("
                    . $mesg->error() . ")\n";
                $result .= "\n";
            }
        }

        # write MAIL field
        if ( ( $email2 ne '' ) and ( $email2 ne $mail ) ) {
            my $data = {
                timestamp   => time(),
                ttl         => 86400,
                remote_addr => getRemoteAddr(),
                action      => 'update_email',
                id          => $id,
                dn          => $dn,
                email       => $email2,
                role        => $role,
                degree      => $degree,
                from        => getEmailName( $id, $degree, $role ),
            };

            my $ticket_number = createTicket($data);

            if ($ticket_number) {
                $data->{'ticket_number'} = $ticket_number;
                my $msg = getTicketMessage($data);

                $result .= "確認信已寄到 $email2\n";
                $result .= "Confirmation mail has been sent to $email2\n";
                $result .= "\n";

                sendMail( $data,
                    "帳號聯絡用確認信 (Confirmation mail)", $msg );
            }
        }
    }
    else {    # non-student
        $username = $id;
        $username =~ s/@.*$//g;
        $config = ldap_init_config("$role");
        $ldap   = ldap_connect($config);

        if ( $role eq 'staff' ) {
            $users = ldap_get_users_by_sn( $ldap, $config, $id );
            my @tmp = ();
            foreach (@$users) {
                if ( $_->{'profile'} eq 'mx' ) {
                    push( @tmp, $_ );
                    last;
                }
            }
            $users = \@tmp;
        }
        else {
            $users = ldap_get_user( $ldap, $config, $username );
        }

        $dn
            = defined( $users->[0]->{'uid'} )
            ? 'uid=' . $users->[0]->{'uid'} . ',' . $config->{'user_dn'}
            : '';
        $url
            = defined( $users->[0]->{'labeleduri'} )
            ? $users->[0]->{'labeleduri'}
            : '';
        $mail
            = defined( $users->[0]->{'mail'} )
            ? $users->[0]->{'mail'}
            : '';
        $description
            = defined( $users->[0]->{'description'} )
            ? $users->[0]->{'description'}
            : '';

        # lyshie_20100818: change name (cn field)
        if ( $openid ne $url ) {
            $description
                .= 'chopenid('
                . time() . ','
                . getRemoteAddr() . ','
                . $url . ');';

            if ( defined($openid) && $openid ne '' ) {
                $mesg = $ldap->modify(
                    $dn,
                    replace => {
                        'labeleduri'  => $openid,
                        'description' => $description,
                    }
                );
            }
            else {    # clear OpenID field
                $mesg = $ldap->modify(
                    $dn,
                    replace => {
                        'labeleduri'  => [],
                        'description' => $description,
                    }
                );
            }

            if ( !$mesg->code() ) {
                $result
                    .= "完成變更使用者 $username ($openid) 的 OpenID\n";
                $result .= "Changed OpenID: $username ($openid)\n";
                $result .= "\n";
            }
            else {
                $result
                    .= "無法變更使用者 $username ($openid) 的 OpenID ("
                    . $mesg->error() . ")\n";
                $result .= "Failed to change OpenID: $username ($openid) ("
                    . $mesg->error() . ")\n";
                $result .= "\n";
            }
        }

        # write MAIL field
        if ( ( $email2 ne '' ) and ( $email2 ne $mail ) ) {
            my $data = {
                timestamp   => time(),
                ttl         => 86400,
                remote_addr => getRemoteAddr(),
                action      => 'update_email',
                id          => $id,
                dn          => $dn,
                email       => $email2,
                role        => $role,
                degree      => $degree,
                from        => getEmailName( $id, $degree, $role ),
            };

            my $ticket_number = createTicket($data);

            if ($ticket_number) {
                $data->{'ticket_number'} = $ticket_number;
                my $msg = getTicketMessage($data);

                $result .= "確認信已寄到 $email2\n";
                $result .= "Confirmation mail has been sent to $email2\n";
                $result .= "\n";

                sendMail( $data,
                    "帳號聯絡用確認信 (Confirmation mail)", $msg );
            }
        }
    }

    ldap_disconnect($ldap);

    if ( $result eq '' ) {
        $result .= "沒有變更\n";
        $result .= "Nothing changed.\n";
    }

    return $result;
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

        my $result
            = change_openid_email2( $h->{'id'}, $degree, $_POST{'openid'},
            $_POST{'email2'}, $h->{'name'}, $role );

        my $template = HTML::Template::Pro->new(
            case_sensitive => 1,
            filename       => "$Bin/template/$G_LANG/configure.tmpl"
        );

        $template->param( SID    => $sid );
        $template->param( RESULT => $result );

        print header( -charset => 'utf-8', -expires => 'now' ); # later output
        $template->output( print_to => \*STDOUT );
    }
    else {
        print header( -charset => 'utf-8' );
        print show_session_error($status);
    }
}

main();
