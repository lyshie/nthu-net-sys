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
package ourTemplate;

BEGIN { $INC{'ourTemplate.pm'} ||= __FILE__ }

use strict;
use warnings;

use CGI::Carp qw(fatalsToBrowser set_message);
use Exporter;
use FindBin qw($Bin);
use HTML::Entities;
use Unix::Syslog qw(:subs :macros);
use CGI qw(:standard);
use URI::Escape;
use lib "$Bin";
use ourLanguage;

BEGIN {

    # lyshie_20110331: properly deal with error messages
    sub handle_errors {
        my $msg = shift;

        my $bug_id = join( '', map( int( rand(10) ), 1 .. 4 ) );
        my $now = time();

        my $error_log = "$Bin/bugs/error_log." . $now . "." . $bug_id;
        open( ERR_LOG, ">$error_log" );

        # time
        print ERR_LOG "=" x 20, " INFO ", "=" x 20, "\n";
        print ERR_LOG scalar( localtime($now) ), "\n";

        # env
        print ERR_LOG "\n", "=" x 20, " ENV VARS ", "=" x 20, "\n";
        foreach ( sort ( keys(%ENV) ) ) {
            print ERR_LOG "$_ = $ENV{$_}\n";
        }

        # error msg
        print ERR_LOG "\n", "=" x 20, " ERROR MSG ", "=" x 20, "\n";
        print ERR_LOG $msg;

        close(ERR_LOG);

        print
            "<h1 style=\"color: white; background: gray; display: block;\">Software Error</h1>\n";
        print "<pre>\n";
        print "Bug report ID: $bug_id\n\n";
        print
            "Please click <a href=\"mailto:lyshie\@mx.nthu.edu.tw?subject=Bug%20report%20ID:%20$bug_id%20(Network%20Systems%20Portal)\">this link</a> to report bug.\n\n";
        print "Network Systems Division\n";
        print "</pre>\n";
    }
    set_message( \&handle_errors );
}

our @ISA    = qw(Exporter);
our @EXPORT = qw(
    $G_TEMPLATE_PATH
    getTemplate
    encodeEntities
    _H
    _L
);

our $G_TEMPLATE_PATH = "$Bin/template/$G_LANG";

sub getTemplate {
    my ($filename) = @_;

    if ( -f "$G_TEMPLATE_PATH/$filename" ) {
        return "$G_TEMPLATE_PATH/$filename";
    }
    else {
        return "$Bin/template/$G_DEFAULT_LANG/$filename";
    }

}

sub encodeEntities {
    my ($str) = @_;
    return encode_entities( $str, q{<>&'"} );
}

sub _H {
    my ($str) = @_;
    return encodeEntities($str);
}

sub _L {    # lyshie_20110524: only for ldap-uas
    my ( $sub_name, $msg ) = @_;

    $sub_name = defined($sub_name) ? $sub_name : '';
    $msg      = defined($msg)      ? $msg      : '';

    # get last token (filename)
    $sub_name =~ s/^.*\///g;

    # replace \n \r with ; and tailing space
    $msg =~ s/[\n\r]/; /g;

    openlog( qq{ldap-uas($sub_name)}, LOG_PID, LOG_LOCAL7 );
    syslog( LOG_INFO, $msg );
    closelog();
}

1;
