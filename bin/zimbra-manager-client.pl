#!/usr/bin/env perl
use strict;  
use warnings;

use 5.010;

use FindBin;
use lib "$FindBin::Bin/../thirdparty/lib/perl5";

use Getopt::Long qw(:config posix_default no_ignore_case);
use Pod::Usage;

use Mojo::UserAgent;
use Mojo::URL;
use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;
$Data::Dumper::Indent = 1;

my %opt = (); # parse options
my $ua;       # Mojo User Agent

my $defaultEmailDomain = 'example.com';
my $defaultCOS         = 'example.com';
my $defaultCOSId;

# main loop
sub main {
	GetOptions(\%opt, 'help|h', 'man', 'noaction|no-action|n',
		'verbose|v','debug', 'zmurl=s', 'zmauthuser=s', 'zmauthpassword=s',
		'uid=s', 'sn=s', 'gn:s', 'password=s', 'lang:s', 'c=s', 'email:s' 
	) or exit(1);
	if ($opt{help})    { pod2usage(1);}
	if ($opt{man})     { pod2usage(-exitstatus => 0, -verbose => 2); }
	if ($opt{noaction}){ die "ERROR: don't know how to \"no-action\".\n";  }
	if (not @ARGV){
		pod2usage(1);
	}

	my $uid; 
	my $ms; 
	my $command; 
	my $param;


	init();
	($command, $param) = parseCommandsAndArgs($ARGV[0]);
	runZimbraCommand($command, $param);
	
	exit 1;
}

sub init {	
	$ua = Mojo::UserAgent->new;
	authZimbraManager();
	$defaultCOSId = getDefaultCOSId($defaultCOS);
	return;
}

#### Zimbra Manager Communication ###

sub getJSONZimbraManager {
	my $function = shift;
	my $params   = shift;
	my $zmurl    = $opt{zmurl} || 'http://zimbra.example.com';
	my $url = Mojo::URL->new($zmurl);
	   $url->path($function);
	   $url->query($params);
	my $req = $ua->get($url);
	return processJSONAnswer($req);
}

sub postJSONZimbraManager {
	my $function = shift;
	my $params   = shift;
	my $zmurl    = $opt{zmurl} || 'http://zimbra.example.com';
	my $url = Mojo::URL->new($zmurl);
	   $url->path($function);
	my $req = $ua->post( $url => json => $params );    	
	return processJSONAnswer($req);
}

sub processJSONAnswer {
	my $req = shift;
	unless ($req->success) {
		my ($err, $code) = $req->error;
		if ($req->res->content->asset) {
			$err = $req->res->content->asset->slurp; 
			$err =~ tr/"//d;
		}
		# use code errors in own namespace (>1000)
		fail(1000 + $code, $err);
	}
	return $req->res->json;
}

sub authZimbraManager {
	my $json = getJSONZimbraManager( 'auth' ,
		{ user     => $opt{zmauthuser}     || 'admin',
		  password => $opt{zmauthpassword} || 'secret' }
	);
	return $json;
}

### Command Line Argument Parsing ###

sub checkParameter {
	my $cmd = shift;
	my $param =  { 
		uid   => $opt{uid},
		sn    => $opt{sn},
		up    => $opt{up},
		gn    => 'optional:' . ( $opt{gn} || '' ),
		lang  => 'optional:' . ( $opt{lang} || '' ), 
		c     => $opt{c}, 
		email => 'optional:' . ( $opt{email} || ''), 
	};					
	checkCommandLineArgs($cmd,$param);
	return $param;
}

sub checkCommandLineArgs {
	my $cmd = shift;
	my $param = shift; 	
	my $caller = (caller(1))[3]; 	
	for my $k (keys %{$param}){
		my $v = $param->{$k} || '';				
		if (defined($v) and ($v eq '')) { 
			fail(1, "Wrong arguments (Function $cmd, Parameter $k missing) ### Perl Function $caller ###");
		}  	
		$v =~ s/^optional://;	
		$param->{$k} = $v;
	}
	return $param;
}

### Zimbra Commands ###

sub runZimbraCommand {
	my $command = shift;
	my $params  = shift;

	for ($command) {
		when (/^create/) {
			my $json = postJSONZimbraManager(
				'createAccountRequest',
				{
					name => $params->{uid} . '@' . $defaultEmailDomain,
					password => $params->{up},
					a => [
						{
							n => 'givenName',
							_ => $params->{gn},
						},
						{
							n => 'sn',
							_ => $params->{sn},
						},
						{
							n => 'c',
							_ => $params->{c},
						},
						{
							n => 'displayName',
							_ => "$params->{sn} $params->{gn}",
						},
						{
							n => 'zimbraPrefLocale',
							_ => $params->{lang},
						},
						{
							n => 'zimbraPasswordMustChange',
							_ => 'FALSE',
						},
						{
							n => 'zimbraCOSid',
							_ => $defaultCOSId,
						},
					],
				}
			);			
		}		
		when (/^change_email/) {			
			my $uid = $params->{uid};
			my $zimbraId = getUserZimbraID($uid.'@'.$defaultEmailDomain);
			my $json = postJSONZimbraManager(
				'addAccountAliasRequest',
				{
					id => $zimbraId,
					alias => $params->{email}
				},
			);			
		}
		when (/^enable_email/) {
			my $uid = $params->{uid};
			my $zimbraId = getUserZimbraID($uid.'@'.$defaultEmailDomain);
			my $json = postJSONZimbraManager(
				'modifyAccountRequest',
				{
					id => $zimbraId,					
					a => [{
							n => 'zimbraMailStatus',
							_ => 'enabled',
						 }],
				},
			);
		}
		when (/^disable_email/) {
			my $uid = $params->{uid};
			my $zimbraId = getUserZimbraID($uid.'@'.$defaultEmailDomain);
			my $json = postJSONZimbraManager(
				'modifyAccountRequest',
				{
					id => $zimbraId,					
					a => [{
							n => 'zimbraMailStatus',
							_ => 'disabled',
						 }],
				},
			);
		}
		when (/^delete/) {
			my $uid = $params->{uid};
			my $zimbraId = getUserZimbraID($uid.'@'.$defaultEmailDomain);
			my $json = postJSONZimbraManager(
				'deleteAccountRequest',
				{
					id => $zimbraId,					
				},
			);			
		}
		default {
			fail(1999,"Unknown command $command");
			exit 0;
		}
	}
}

sub getUserZimbraID {
	my $username = shift;	
	my $json = postJSONZimbraManager( 'getAccountInfoRequest' ,
		{ account => { 
			by => 'name', 
			_  => $username } } 		
	);		
	my %kv = map { $_->{'n'} => $_->{'_'} } @{$json->{a}};	
	return $kv{zimbraId};
}

sub getDefaultCOSId {	
	my $json = postJSONZimbraManager( 'getCosRequest' ,
		{ cos => { 
			by => 'name', 
			_  => $defaultCOS } } 		
	);	
	return $json->{cos}->{id};	
}

### Error Handling ###

sub fail {
  my $code = shift;
  my $msg = shift;

  print STDERR "$msg\n";
  # printlog
  print STDERR "Finished with errors\n";
  exit $code;
}

main;

__END__

=head1 NAME

zimbra-manager-client.pl - a ZimbraManager Client written with Mojo::UserAgent

=head1 SYNOPSIS

B<zimbra-manager-client.pl> [I<options>] [B<command>]

     --man           show man-page and exit
 -h, --help          display this help and exit
     --version       output version information and exit
     --debug         prints debug messages
     --noaction      noaction mode

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

 2014-03-31 rp Initial Version
 
=cut
