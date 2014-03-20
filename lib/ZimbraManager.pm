package ZimbraManager;

use Mojo::Base 'Mojolicious';
use Mojo::Util qw(dumper);
use Mojo::JSON qw(decode_json encode_json);

use ZimbraManager::Soap;

has 'soap' => sub {
	my $self = shift;
	return ZimbraManager::Soap->new(
		log => $self->log,
	);
};

sub startup {
	my $self = shift;

    # session is valid for 1 day
    $self->sessions->cookie_name('zimbra-manager');
    $self->sessions->default_expiration(1*24*3600);

	my $r = $self->routes;

	$r->get('/:call' => sub {
  		my $ctrl = shift;
  		my $call = $ctrl->param('call');
  		my $plain = $ctrl->param('plain');
  		my $ret;
  		my $err;
  		given ($call) {
  			when ('auth') { 
  				my $user = $ctrl->param('user');
  				my $password = $ctrl->param('password');
  				($ret, $err) = $self->soap->call(auth($user,$password));  				
  				$ret = 'Authentication sucessful!' if ($ret);  				
  			}
  			when ('getAccount') {
  				my $user = $ctrl->param('user');
  				($ret, $err) = $self->soap->call(getAccount($user));
  			}
  			when ('getAccountInfo') {
  				my $user = $ctrl->param('user');
  				($ret, $err) = $self->soap->call(getAccountInfo($user));
  			}
  			when ('getAllAccounts') {
  				my $name = $ctrl->param('name');
  				my $domain = $ctrl->param('domain');
  				($ret, $err) = $self->soap->call(getAllAccounts($name, $domain));	  				
  				$ret = processAllAccounts($ret) unless ($err);  				
 			}
  			default {
				my %params;
  				($ret, $err) = $self->soap->call($call, \%params);  				
  			}
  		}
  		$self->renderOutput($ctrl, $ret, $err, $plain);
  	});

	$r->post('/:call' => sub {
		my $ctrl  = shift;
		my $call  = $ctrl->param('call');
		my $plain = $ctrl->param('plain');
		my $json_args = $ctrl->param('json_args');
		my $ret;
		my $err;

		my $perl_args = decode_json($json_args);
		($ret, $err) = $self->soap->call($call, $perl_args);
		$self->renderOutput($ctrl, $ret, $err, $plain);
	});
}

sub renderOutput {
	my ($self, $ctrl, $ret, $err, $plain) = @_;
	if (ref $ret eq 'HASH'){
		$ret = dumper $ret;
	}
	my $text = $err ? $err : $ret;
	if ($err) {
        $ctrl->res->code(510);
	}

	if ($plain) {
		$ctrl->render(text => "<pre>$text</pre>") if ($plain);
	}
	else {
		$ctrl->render(json => $text);
	}
}

sub auth { 
 	my $user = shift;
 	my $password = shift;
 	return (
 	'authRequest', 
	{ persistAuthTokenCookie => 1, 
		   password => $password, 
			account =>  { 
				 by => 'name', 
				  _ => $user}}
	);
}

sub getAccountInfo {
	my $user = shift;	
	return (
		 'getAccountInfoRequest', 
		 { account => { 
					by => 'name', 
					_  => $user}}
	);	
}

sub getAccount {
	my $user = shift;	
	return (
		 'getAccountRequest', 
		 { account => { 
					by => 'name', 
					_  => $user}}
	);	
}


sub getAllAccounts {
	my $name = shift;
	my $domain = shift;
	return (	
		 'getAllAccountsRequest', 
		 { server => { 
				   by => 'name', 
					_ => $name }, 
		   domain => { 
				   by => 'name', 
					_ => $domain }}
	);
}

sub processAllAccounts {
	my $ret = shift;
	my $accounts;
	for my $za ( @{ $ret->{account} } ) {
		my $name = $za->{name};
		my $id = $za->{id};
		my %kv = map { $_->{'n'} => $_->{'_'} } @{$za->{a}};
		$accounts->{$name} = {
			'name' => $name,
			'id' => $id,
			'kv' => \%kv,
		};
	}
	return $accounts;
}

1;

__END__

=head1 NAME

Zimbra Manager - ZimbraManager - A class to manage Zimbra with SOAP

=head1 SYNOPSIS

    use ZimbraManager;

    # Start commands
    Mojolicious::Commands->start_app('ZimbraManager');

=head1 USAGE

Examples in Webbrowser:

    http://localhost:3000/auth?user=adminuser&password=MyAdminPassword


    http://localhost:3000/getAccountInfo?user=roman@zimbra.example.com&plain=yes

    http://localhost:3000/getAccountInfo?user=roman@zimbra.example.com


    http://localhost:3000/getAccount?user=roman@zimbra.example.com&plain=yes

    http://localhost:3000/getAccount?user=roman@zimbra.example.com


    http://localhost:3000/getAllAccounts?name=zimbra.example.com&domain=zimbra.example.com&plain=yes

    http://localhost:3000/getAllAccounts?name=zimbra.example.com&domain=zimbra.example.com

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

 2014-03-20 rp Initial Version

=cut