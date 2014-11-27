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
package ourMail;

BEGIN { $INC{'ourMail.pm'} ||= __FILE__ }

use strict;
use warnings;

use Exporter;
use FindBin qw($Bin);
use List::MoreUtils qw(uniq);
use lib "$Bin";
use ourLDAP;
use ourUtils;

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    read_email
    update_email
    delete_email
);

sub _update_email {
    my ( $config, $ldap, $users, $mail, $desc ) = @_;

    my $dn
        = defined( $users->[0]->{'uid'} )
        ? 'uid=' . $users->[0]->{'uid'} . ',' . $config->{'user_dn'}
        : '';

    my $mesg;

    if ($desc) {
        $mesg = $ldap->modify(
            $dn,
            replace => {
                'mail'        => $mail,
                'description' => $desc,
            }
        );
    }
    else {
        $mesg = $ldap->modify( $dn, replace => { 'mail' => $mail, } );
    }

    if ( !$mesg->code() ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub read_email {
    my ($users) = @_;

    my $email
        = defined( $users->[0]->{'mail'} )
        ? $users->[0]->{'mail'}
        : '';

    my @mails = grep { defined($_) && $_ ne '' } split( "\0", $email );

    return @mails;
}

sub update_email {
    my ( $config, $ldap, $users, $email, $desc ) = @_;

    my @mails = read_email($users);

    # using FIFO (queue)
    push( @mails, $email ) if ($email);
    @mails = grep { defined($_) && $_ ne '' } ( uniq(@mails) )[ -3 .. -1 ];

    my $mail = join( "\0", @mails );

    return _update_email( $config, $ldap, $users, $mail, $desc );
}

sub delete_email {
    my ( $config, $ldap, $users, $email, $desc ) = @_;

    my @tmp = read_email($users);

    my @mails = ();
    foreach my $m (@tmp) {
        if ( $m ne $email ) {
            push( @mails, $m );
        }
    }

    @mails = grep { defined($_) && $_ ne '' } ( uniq(@mails) )[ -3 .. -1 ];

    my $mail = join( "\0", @mails );

    return _update_email( $config, $ldap, $users, $mail, $desc );
}

1;
