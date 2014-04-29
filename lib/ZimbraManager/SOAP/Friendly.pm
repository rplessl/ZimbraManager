package ZimbraManager::SOAP::Friendly;

use Mojo::Base 'ZimbraManager::SOAP';

=head1 NAME

ZimbraManager::Soap::Friendly - class to manage Zimbra with perl and SOAP

=head1 SYNOPSIS

    use ZimbraManager::Soap::Friendly;

    my %params = {
        username => 'USERNAME',
        password => 'PASSWORD',
    }

    my $ret = $self->soap->callFriendly(functionname, %params, $authtoken));

=head1 USAGE

Examples in Webbrowser:

    http://localhost:3000/auth?user=adminuser&password=MyAdminPassword

    http://localhost:3000/getAccountInfo?user=roman@zimbra.example.com&plain=yes

    http://localhost:3000/getAccountInfo?user=roman@zimbra.example.com


    http://localhost:3000/getAccount?user=roman@zimbra.example.com&plain=yes

    http://localhost:3000/getAccount?user=roman@zimbra.example.com


    http://localhost:3000/getAllAccounts?name=zimbra.example.com&domain=zimbra.example.com&plain=yes

    http://localhost:3000/getAllAccounts?name=zimbra.example.com&domain=zimbra.example.com


=head1 DESCRIPTION

Helper class for Zimbra adminstration with a user friendly interface

=cut

=head1 ATTRIBUTES

=cut

=head1 METHODS

All the methods of L<Mojo::Base> plus:

=head2 callFriendly

Calls Zimbra with the given argument and returns the SOAP response as perl hash.

=cut


my $map = {

    functionA => {
        args => [ qw(password accountName)],
        out => sub {
            my ($arg1,$arg2,$arg3) = @_;
            return {
                password => $args1,
                account => {
                        by => 'name',
                        _ => $args2
                }
            }
        } 
    }
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

 2014-04-29 rp Initial Version
 
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
