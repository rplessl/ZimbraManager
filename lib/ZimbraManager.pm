package ZimbraManager;

use Mojo::Base 'Mojolicious';

=head1 NAME

ZimbraManager - A Mojolicious application to manage Zimbra with SOAP

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

=cut

use Mojo::Util qw(dumper);
use Mojo::JSON qw(decode_json encode_json);

use ZimbraManager::Soap;

use 5.14.0;

=head1 ATTRIBUTES

=head2 soap

The ZimbraManager SOAP object

=cut

has 'soap' => sub {
    my $self = shift;
    return ZimbraManager::Soap->new(
        log => $self->log,
        mode => 'full',
        soapDebug => '1',
    );
};

=head1 METHODS

All the methods of L<Mojo::Base> plus:

=head2 startup

Calls Zimbra with the given argument and returns the SOAP response as perl hash.

=cut

sub startup {
    my $self = shift;

    $self->secrets(['bb732c382ded15e58eb02bb0fe0e112e']);
    # session is valid for 1 day
    $self->sessions->default_expiration(1*24*3600);
    $self->sessions->cookie_name('zimbra-manager');

    my $r = $self->routes;

    # Default routing is done with POST requests
    $r->post('/:call' => sub {
        my $ctrl  = shift;
        my $call  = $ctrl->param('call');
        my $plain = $ctrl->param('plain');
        my $ret;
        my $err;
        my $perl_args = decode_json($ctrl->req->body);
        ($ret, $err) = $self->soap->call($call, $perl_args);
        $self->renderOutput($ctrl, $ret, $err, $plain);
    });

    # Special routing for with GET requests
    # especially auth is used for session handling
    $r->get('/:call' => sub {
        my $ctrl  = shift;
        my $call  = $ctrl->param('call');
        my $plain = $ctrl->param('plain');
        my $ret;
        my $err;
        if ($call eq 'auth') {
            my $user     = $ctrl->param('user');
            my $password = $ctrl->param('password');
            if ($self->sessions('ZM_ADMIN_AUTH_TOKEN')) {
                $ret = 'true';
            } 
            else {
                ($ret, $err) = $self->soap->call( buildAuth($user,$password) );
            }
            $ret = { auth => 'Authentication sucessful!' } if ($ret);
        }
        # START: Proof-Of-Example and Debug Code
        elsif ($call eq 'getAccount') {
            my $user = $ctrl->param('user');
            ($ret, $err) = $self->soap->call( buildGetAccount($user) );
        }
        elsif ($call eq 'getAccountInfo') {
            my $user = $ctrl->param('user');
            ($ret, $err) = $self->soap->call( buildGetAccountInfo($user) );
        }
        elsif ($call eq 'getAllAccounts') {
            my $name = $ctrl->param('name');
            my $domain = $ctrl->param('domain');
            ($ret, $err) = $self->soap->call( buildGetAllAccounts($name, $domain) );
            $ret = helperHashingAllAccounts($ret) unless ($err);
        }
        # END: Proof-Of-Example and Debug Code
        else {
            my %params;
            ($ret, $err) = $self->soap->call($call, \%params);
        }
        $self->renderOutput($ctrl, $ret, $err, $plain);
    });    
}

=head2 renderOutput

Renders the Output in JSON or readable plain text

=cut

sub renderOutput {
    my ($self, $ctrl, $ret, $err, $plain) = @_;
    my $text = $err ? $err : $ret;
    if ($err) {
        $ctrl->res->code(510);
    }
    if ($plain) {
        if (ref $text eq 'HASH') {
            $text = dumper $text;
        }
        $ctrl->render(text => "<pre>$text</pre>") if ($plain);
    }
    else {
        $ctrl->render(json => $text);        
    }
}

=head2 buildAuth

Builds auth call for SOAP

=cut

sub buildAuth { 
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

=head2 Proof-Of-Example GET SOAP Call wrappers

=head3 buildGetAccountInfo

Builds getAccountInfo call for SOAP

=cut

sub buildGetAccountInfo {
    my $user = shift;    
    return (
         'getAccountInfoRequest', 
         { account => { 
                    by => 'name', 
                    _  => $user}}
    );    
}

=head3 buildGetAccount

Builds getAccount call for SOAP

=cut

sub buildGetAccount {
    my $user = shift;    
    return (
         'getAccountRequest', 
         { account => { 
                    by => 'name', 
                    _  => $user}}
    );    
}

=head3 buildGetAllAccount

Builds getAllAccount call for SOAP

=cut

sub buildGetAllAccounts {
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

=head3 helperHashingAllAccounts

Helper function for processing AllAccounts SOAP call

=cut

sub helperHashingAllAccounts {
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

=cut
