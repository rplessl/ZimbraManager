package ZimbraManager::Soap;

use Mojo::Base -base;
use Mojo::Util qw(dumper);
use Mojo::Log;

use IO::Socket::SSL qw( SSL_VERIFY_NONE SSL_VERIFY_PEER );

use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::SOAP::Trace;
use XML::Compile::Transport::SOAPHTTP;

use 5.14.0;

### DEBUG and LOGGING stuff ###
has 'log';
has 'debug' => sub {
	my $self = shift;
	return 0;
};
has 'soapdebug' => sub {
	my $self = shift;
	return 0;
};
has 'soapErrorsToConsumer' => sub {
	my $self = shift;
	return 0;
};

### Functionality ###
has 'mode' => sub {
	my $self = shift;
	return 'full';
};

has 'zcsService' => sub {
	my $self = shift;
	my $mode = $self->mode;
	for ($self->mode) {
		when ('admin') {
			return 'zcsAdminService';
		}
		when ('user') {
			return 'zcsService';
		}
		default {
			return 'zcsAdminService';
		}
	}
};

has 'wsdlPath' => sub {
	my $self = shift;
	return "$FindBin::Bin/../etc/wsdl/";
};

has 'wsdlFile' => sub {
	my $self = shift;
	my $wsdlFile;
	for ($self->mode) {
		when ('admin')  {
			$wsdlFile = $self->wsdlPath.'ZimbraAdminService.wsdl';
		}
		when ('user') {
			$wsdlFile = $self->wsdlPath.'ZimbraUserService.wsdl';
		}
		default {
			$wsdlFile = $self->wsdlPath.'ZimbraService.wsdl';
		}
	}
	if ($self->debug) {
		$self->log->debug("wsdlFile=$wsdlFile");
	}
	return $wsdlFile;
};

has 'wsdlXml' => sub { 
	my $self = shift;
	my $wsdlXml = XML::LibXML->new->parse_file($self->wsdlFile);
	return $wsdlXml;
};

has 'wsdl' => sub {
	my $self = shift; 
	my $wsdlXml = $self->wsdlXml;
	my $wsdl = XML::Compile::WSDL11->new($wsdlXml);
	for my $xsd (glob $self->wsdlPath."*.xsd") {
		if ($self->debug) {
			$self->log->debug("XML Schema Import of file:", $xsd);
		}
		$wsdl->importDefinitions($xsd);
	}
	return $wsdl;
};

has 'service' => sub {
	my $self = shift;
	my $wsdlXml = $self->wsdlXml;
	my $zimbraServices;
	my $wsdlServices = $wsdlXml->getElementsByTagName( 'wsdl:service' );
	for my $service (@$wsdlServices) {
		my $name         = $service->getAttribute( 'name' );
		my $port         = $service->getElementsByTagName( 'wsdl:port' )->[0];	
		my $port_name    = $port->getAttribute( 'name' );
		my $address      = $port->getElementsByTagName( 'soap:address' )->[0];
		my $uri          = $address->getAttribute( 'location' );
		   $uri          =~ m/^(https|http):\/\/(.+?):(.+?)\//;
		my $uri_protocol = $1;
		my $uri_host     = $2;
		my $uri_port     = $3;

		$zimbraServices->{$name} = {
			host           => $uri_host,
			name           => $name,
			port_name      => $port_name,
			uri            => $uri,
			uri_host       => $uri_host,
			uri_port       => $uri_port,
			uri_protocol   => $uri_protocol,
		};
	}
	if ($self->debug) {
		for my $servicename (keys %$zimbraServices) {
			for my $k (keys %{$zimbraServices->{$servicename}}) {
				$self->log->debug("$k=", $zimbraServices->{$servicename}->{$k});
			}
		}
	}
	return $zimbraServices;
};

has 'soapOps' => sub {
	my $self = shift;
	my $soapOps;

	my $zcsService = $self->zcsService;
	my $uri  = $self->service->{$zcsService}->{uri};
	my $port = $self->service->{$zcsService}->{port_name};
	my $name = $self->service->{$zcsService}->{name};

	if ($self->debug) {
		$self->log->debug('PERL_LWP_SSL_VERIFY_HOSTNAME=',$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'});
		$self->log->debug('PERL_LWP_SSL_VERIFY_MODE',$ENV{'PERL_LWP_SSL_VERIFY_MODE'});
	}

	# redirect the endpoint as specified in the WSDL to our own server.
	my $transporter = XML::Compile::Transport::SOAPHTTP->new(
		address    => $uri,
		keep_alive => 1,
		# for SSL handling we need our own LWP Agent
		user_agent => LWP::UserAgent->new(
			ssl_opts => { # default is SSL verification on
				# NOTE: PERL_LWP_SSL_VERIFY_MODE is not an "official" env variable
				verify_hostname => $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} // 1,
				SSL_verify_mode => $ENV{'PERL_LWP_SSL_VERIFY_MODE'}     // SSL_VERIFY_PEER,
			},			
		),
	);

	# enable cookies for zimbra Auth
	my $ua = $transporter->userAgent();
	require HTTP::CookieJar::LWP;
	$ua->cookie_jar(HTTP::CookieJar::LWP->new());
	#  $ua->cookie_jar({ file => "$ENV{HOME}/.cookies.txt" });


	my $send = $transporter->compileClient( port => $port );

	# Compile all service methods
	for my $soapOp ( $self->wsdl->operations( port => $port ) ) {
		if ($self->debug) {
			my $msg = sprintf "got soap operation %s", $soapOp->name;
			warn $msg;
		}
		$soapOps->{ $soapOp->name } =
		$self->wsdl->compileClient(
			$soapOp->name,
			port      => $port,
			service   => $name,
			transport => $send,
		);
	}
	return $soapOps;
};

sub call {
	my $self = shift;
	my $action = shift;
	my $args = shift;

	$self->log->debug(dumper { _function => 'ZimbraManager::Soap::call',
							   action => $action,
							   args => $args });

	my ( $response, $trace ) = $self->soapOps->{$action}->($args);
	if ($self->soapdebug) {
		$self->log->debug(dumper ("call(): response=", $response));
		$self->log->debug(dumper ("call(): trace=", $trace));
	}
	my $err;
	if ( $response->{Fault} ) {
		$err = 'SOAP ERROR from Zimbra: '. $response->{Fault}->{faultstring};
		if ($self->soapErrorsToConsumer) {
			my $msg1    = 'response: ' . sprintf "%s", dumper $response;
			my $msg2    = 'trace:    ' . sprintf "%s", dumper $trace;
			$err .= "\n\n\n$msg1\n$msg2\n";
		}
	}
	return ($response->{parameters}, $err);
}

1;

__END__

=head1 NAME

Zimbra Manager - ZimbraManager::Soap.pm - A class to manage Zimbra with SOAP

=head1 SYNOPSIS

    use ZimbraManager::Soap;

    has 'soap' => sub {
        my $self = shift;
        return ZimbraManager::Soap->new(
            log => $self->log,
            mode => 'full' # or 'admin' or 'user'
        );
    };

    my $ret = $self->soap->call(FUNCTION, %PARAMS));

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
 2014-03-27 rp Improved Version (Errors, SSL)

=cut
