package ZimbraManager::Soap;

use Mojo::Base -base;

use XML::Compile::WSDL11;
use XML::Compile::SOAP11;
use XML::Compile::Transport::SOAPHTTP;

use 5.14.0;

has 'debug' => sub {
	return 0;
};

has 'mode' => sub {
	return 'full';
};

has 'wsdlPath' => sub {
	return "$FindBin::Bin/../etc/wsdl/";
};

has 'wsdlFile' => sub {
	my $self = shift;
	my $wsdlFile;
	given ($self->mode) {
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
		warn "wsdlFile=$wsdlFile";
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
			warn "XML Schema Import of file:", $xsd;
		}
		$wsdl->importDefinitions($xsd);
	}
	return $wsdl;
};

# has 'service' => sub {
# 	my $serviceName = 'zcsAdminService';
# 	return { 
# 		'serviceName' => $serviceName,
# 		'servicePort' => $serviceName.'Port',
# 	};
# };

has 'service' => sub {
	my $self = shift;
	my $wsdlXml = $self->wsdlXml;
	my $zimbraServices;
	my $wsdlServices = $wsdlXml->getElementsByTagName( 'wsdl:service' );
	for my $service (@$wsdlServices) {
		my $name        = $service->getAttribute( 'name' );
		my $port        = $service->getElementsByTagName( 'wsdl:port' )->[0];	
		my $address     = $port->getElementsByTagName( 'soap:address' )->[0];
		my $service_uri = $address->getAttribute( 'location' );
		   $service_uri =~ m/^(https|http):\/\/(.+?):(.+?)\//;
		my $uri_protocol = $1;
		my $uri_host     = $2;
		my $uri_port     = $3;
		
		$zimbraServices->{$name} = {
			host           => $uri_host,
			name           => $name,
			port           => $uri_port,
			protocol       => $uri_protocol,
			uri            => $service_uri,
		};
	}	
	if ($self->debug) {
		for my $servicename (keys %$zimbraServices) {
			for my $k (keys %$servicename) {
				warn "$k=", $servicename->{$k};
			}
		}
	}
	return $zimbraServices;
};

has 'adminService' => sub {
	return 'zcsAdminService';
};

has 'soapOps' => sub {
	my $self = shift;
	my $soapOps;

	my $adminService = $self->adminService;

	# redirect the endpoint as specified in the WSDL to our own server.
	my $transporter = XML::Compile::Transport::SOAPHTTP->new(
		address    => $self->service->{$adminService}->{uri},
		keep_alive => 1,
	);

	# enable cookies for zimbra Auth
	my $ua = $transporter->userAgent();
	$ua->cookie_jar({ file => "$ENV{HOME}/.cookies.txt" });

	my $send = $transporter->compileClient( port => $self->service->{$adminService}->{port} );

	# Compile all service methods
	for my $soapOp ( $self->wsdl->operations( port => $self->service->{$adminService}->{port} ) ) {
		if ($self->debug) {
			my $msg = sprintf "got soap operation %s", $soapOp->name;
			warn $msg;
		}
		$soapOps->{ $soapOp->name } =
		$self->wsdl->compileClient( 
			$soapOp->name,
			port      => $self->service->{$adminService}->{port},
			service   => $self->service->{$adminService}->{name},
			transport => $send, 
		);
	}
	return $soapOps;
};

sub call {
	my $self = shift;
	my $action = shift;
	my $args = shift;
	#my %argHash;
	#@argHash{ keys %$args }  = values %$args;    

	use Data::Dumper;
	warn Dumper $self->soapOps;

	my ( $response, $trace ) = $self->soapOps->{$action}->($args);
	#my ( $response, $trace ) = $self->soapOps->{$action}->(\%argHash);
	#warn Dumper ("call(): response=", $response);
	#warn Dumper ("call(): trace=", $trace);
	return $response->{parameters};
}

1;