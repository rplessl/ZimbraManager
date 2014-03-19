package ZimbraManager;

use Mojo::Base 'Mojolicious';
use ZimbraManager::Soap;

has 'soap' => sub {
	ZimbraManager::Soap->new();
};

sub startup {
	my $self = shift;
	$self->soap->call;

	my $r = $self->routes;
	$r->get('/:call' => sub {
  		my $ctrl = shift;
  		my $call = $ctrl->param('call');
  		my %params;
  		my $ret = $self->soap->call($call, \%params);
	  	$self->render(json => $ret);  
  	})
}

1;

__END__

=head1 NAME

ZimbraManager.pm - 

=head1 DESCRIPTION


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