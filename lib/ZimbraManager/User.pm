package ZimbraManager::User;

use Mojo::Base -base;

=head1 NAME

ZimbraManager::User - User session handling for ZimbraManager

=head1 SYNOPSIS

This User session handling module gets instantiated by L<ZimbraManager> 
and provides session handling functionality for ZimbraManager.

    use ZimbraManager::User;

=head1 DESCRIPTION

Helper class for user session handling.

=cut

use Mojo::Util qw(dumper);
use Mojo::Log;

use HTTP::CookieJar::LWP;

use 5.14.0;

has cookiejar => sub {
    my $self = shift;
    my $cookiejar = $self->controller->session('cookieJarContent');
	if (not $cookiejar) {
		$cookiejar = HTTP::CookieJar::LWP->new();
	}
	return $cookiejar;
};
    
1;

__END__

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

=head1 COPYRIGHT

Copyright (c) 2014 by Roman Plessl. All rights reserved.

=head1 AUTHOR

S<Roman Plessl E<lt>roman.plessl@oetiker.chE<gt>>

=head1 HISTORY

 2014-04-28 rp Initial Version
 
=cut

# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et
