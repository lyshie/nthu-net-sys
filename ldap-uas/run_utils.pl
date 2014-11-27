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

my $COMMAND_PATH = "$Bin/utils";
my %_GET         = ();

sub read_param {
    $_GET{'command'} = defined( param('command') ) ? param('command') : '';
    $_GET{'command'} =~ s/[^0-9a-zA-Z_\-]//g;

    $_GET{'argv'} = defined( param('argv') ) ? param('argv') : '';

    $_GET{'confirm'} = defined( param('confirm') ) ? param('confirm') : '';
}

sub getCommands {
    my @result = ();

    my @cmds = ();
    my @tmp  = ();

    opendir( DH, $COMMAND_PATH );
    @tmp = grep { m/^xldap_.*\.pl$/ && -x "$COMMAND_PATH/$_" } readdir(DH);
    close(DH);

    if ( $_GET{'command'} ne '' ) {
        foreach (@tmp) {
            push( @cmds, $_ ) if ( $_ eq "$_GET{'command'}.pl" );
        }
    }
    else {
        @cmds = @tmp;
    }

    foreach ( sort @cmds ) {
        $_ =~ s/\.pl$//g;
        my %h = ( 'command' => $_ );
        push( @result, \%h );
    }

    return \@result;
}

sub runCommand {
    my ( $cmd, $argv ) = @_;
    my $result = '';

    if ( -f "$COMMAND_PATH/$cmd.pl" ) {
        $result = `$COMMAND_PATH/$cmd.pl $argv`;
    }

    return $result;
}

sub do_action {
    my $result = '';

    if ( $_GET{'confirm'} eq '1' ) {
        if ( $_GET{'command'} ne '' ) {
            $result .= runCommand( $_GET{'command'}, $_GET{'argv'} ) . "\n";

            _L( $0,
                "OK: Run command [command=$_GET{'command'}], [argv=$_GET{'argv'}]"
            );    # syslog
        }
    }

    return $result;
}

sub main {
    read_param();

    my $result = do_action();

    my $template
        = HTML::Template->new( filename => getTemplate("run_utils.tmpl") );
    $template->param( LOOP_COMMAND => getCommands() );
    $template->param( ARGV         => _H( $_GET{'argv'} ) );
    $template->param( CONFIRM      => _H( $_GET{'confirm'} ) );
    $template->param( RESULT       => _H($result) );

    print header( -charset => 'utf-8' );    # later output
    print $template->output();
}

main();
