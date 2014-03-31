#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;  
use lib "$FindBin::Bin/../thirdparty/lib/perl5";
use lib "$FindBin::Bin/../lib";

use ZimbraManager;

our $VERSION = "0.1";

# Start commands
Mojolicious::Commands->start_app('ZimbraManager');

__END__

=head1 NAME

zimbra-manager.pl - A Zimbra managing tool written in perl / soap

=head1 SYNOPSIS

B<zimbra-manager.pl> [I<options>...]

=head1 DESCRIPTION


Usage
----- 

    $ ./bin/zimbra-manager.pl prefork

or 

    $ ./bin/zimbra-manager.pl daemon


=head1 LICENSE

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see L<http://www.gnu.org/licenses/>.

=head1 AUTHOR

S<Roman Plessl E<lt>roman.plessl@oetiker.chE<gt>>

=head1 HISTORY

 2014-03-19 rp Initial Version

=cut
