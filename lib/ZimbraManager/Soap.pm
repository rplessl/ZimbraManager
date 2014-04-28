package ZimbraManager::Soap;

use Mojo::Base -base;

=head1 NAME

ZimbraManager::Soap - class to manage Zimbra with perl and SOAP

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

=head1 DESCRIPTION

Helper Class for Zimbra adminstration interface.

=cut

use Mojo::Util qw(dumper);
use Mojo::Log;

use IO::Socket::SSL qw( SSL_VERIFY_NONE SSL_VERIFY_PEER );

use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::SOAP::Trace;
use XML::Compile::Transport::SOAPHTTP;

use 5.14.0;

=head1 ATTRIBUTES

=head2 Logging and Debugging Attributes

=head3 log

The mojo log object

=cut

has 'log';

=head3 debug

Enabled debug output to $self->log

=cut

has 'debug' => sub {
	my $self = shift;
	return 0;
};

=head3 soapDebug

Enabled SOAP debug output to $self->log

=cut

has 'soapDebug' => sub {
	my $self = shift;
	return 0;
};

=head3 soapErrorsToConsumer

Returns soapErrors to the consumer in the return messages

=cut

has 'soapErrorsToConsumer' => sub {
	my $self = shift;
	return 0;
};

=head2 mode

The zimbra SOAP interface has three modes:

    admin: adminstration access and commands in admin context
    user:  user accesses and commands in user context
    full:  both admin and user

=cut

has 'mode' => sub {
	my $self = shift;
	return 'full';
};

=head2 zcsService

Internal WSDL name for selecting mode

=cut

has 'zcsService' => sub {
	my $self = shift;
	my $mode = $self->mode;
	if    ($mode eq 'admin') {
		return 'zcsAdminService';
	}
	elsif ($mode eq 'user') {
		return 'zcsService';
	}
	elsif ($mode eq 'full') {
		return 'zcsAdminService';
	}
	else {
		die "no valid mode ($self->mode) for attribute zcsService has been set";
	}
};

=head2 wsdlPath

Path to WSDL and XML Schema file(s)

=cut

has 'wsdlPath' => sub {
	my $self = shift;
	return "$FindBin::Bin/../etc/wsdl/";
};

=head2 wsdlFile

Select WSDL file according to mode

=cut

has 'wsdlFile' => sub {
	my $self = shift;
	my $wsdlFile;
	my $mode = $self->mode;
	if   ($mode eq 'admin') {
		$wsdlFile = $self->wsdlPath.'ZimbraAdminService.wsdl';
	}
	elsif ($mode eq 'user') {
		$wsdlFile = $self->wsdlPath.'ZimbraUserService.wsdl';
    }
	elsif ($mode eq 'full') {
		$wsdlFile = $self->wsdlPath.'ZimbraService.wsdl';
	}
	else {
		die "no valid mode ($self->mode) for attribute wsdlFile has been set";
	}
    $self->log->debug("wsdlFile=$wsdlFile");
	return $wsdlFile;
};

=head2 wsdlXml

parsed WSDL as XML

=cut

has 'wsdlXml' => sub { 
	my $self = shift;
	my $wsdlXml = XML::LibXML->new->parse_file($self->wsdlFile);
	return $wsdlXml;
};

=head2 wsdl

parsed WSDL as perl object with corresponding included XML Schema
and function stubs.

=cut

has 'wsdl' => sub {
	my $self = shift; 
	my $wsdlXml = $self->wsdlXml;
	my $wsdl = XML::Compile::WSDL11->new($wsdlXml);
	for my $xsd (glob $self->wsdlPath."*.xsd") {
        $self->log->debug("XML Schema Import of file:", $xsd);
		$wsdl->importDefinitions($xsd);
	}
	return $wsdl;
};

=head2 service

Processed SOAP service URI on the server

=cut

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

=head2 soapOps

All usable SOAP operations exported by the the SOAP interface and with the selected 
mode.

=cut

has 'soapOps' => sub {
	my $self = shift;
	my $soapOps;

	my $zcsService = $self->zcsService;
	my $uri  = $self->service->{$zcsService}->{uri};
	my $port = $self->service->{$zcsService}->{port_name};
	my $name = $self->service->{$zcsService}->{name};

    my $verifyHostname = $ENV{ERL_LWP_SSL_VERIFY_HOSTNAME} // 1;
    my $verifyMode     = $ENV{ERL_LWP_SSL_VERIFY_MODE}     // SSL_VERIFY_PEER;

	# redirect the endpoint as specified in the WSDL to our own server.
	my $transporter = XML::Compile::Transport::SOAPHTTP->new(
		address    => $uri,
		keep_alive => 1,
		# for SSL handling we need our own LWP Agent
		user_agent => LWP::UserAgent->new(
			ssl_opts => { # default is SSL verification on
				# NOTE: PERL_LWP_SSL_VERIFY_MODE is not an "official" env variable
				verify_hostname => $verifyHostname,
				SSL_verify_mode => $verifyMode,
			}
		),
	);
    $self->log->debug("LWP_SSL_VERIFY_HOSTNAME = $verifyHostname\n"
                    . "LWP_SSL_VERIFY_MODE     = $verifyMode");

	# enable cookies for zimbra Auth
	my $ua = $transporter->userAgent();
	$ua->cookie_jar({ file => "$ENV{HOME}/.cookies.txt" });

	my $send = $transporter->compileClient( port => $port );

	# Compile all service methods
	for my $soapOp ( $self->wsdl->operations( port => $port ) ) {
		$self->log->debug("Got soap operation " . $soapOp->name);
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

=head1 METHODS

All the methods of L<Mojo::Base> plus:

=head2 call

Calls Zimbra with the given argument and returns the SOAP response as perl hash.

=cut

sub call {
	my $self = shift;
	my $action = shift;
	my $args = shift;

	$self->log->debug(dumper { _function => 'ZimbraManager::Soap::call',
							   action => $action,
							   args => $args });

	my ( $response, $trace ) = $self->soapOps->{$action}->($args);
	if ($self->soapDebug) {
		$self->log->debug(dumper ("call(): response=", $response));
		$self->log->debug(dumper ("call(): trace=",    $trace));
	}
	my $err;
	if ( not defined $response ) {
		$err = 'SOAP ERROR from Zimbra: undefined response';
		if ($self->soapErrorsToConsumer) {
			my $trace    = 'trace:    ' . dumper($trace);
			$err .= "\n\n\n$response\n";
		}
	}
	elsif ( $response->{Fault} ) {
		$err = 'SOAP ERROR from Zimbra: '. $response->{Fault}->{faultstring};
		if ($self->soapErrorsToConsumer) {
			my $response = 'response: ' . dumper($response);
			my $trace    = 'trace:    ' . dumper($trace);
			$err .= "\n\n\nresponse\n\n$trace\n";
		}
	}
	return ($response->{parameters}, $err);
}

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

 2014-03-20 rp Initial Version
 2014-03-27 rp Improved Version (Errors, SSL)

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
