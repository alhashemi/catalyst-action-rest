#
# REST.pm
# Created by: Adam Jacob, Marchex, <adam@hjksolutions.com>
# Created on: 10/12/2006 03:00:32 PM PDT
#
# $Id$

package Catalyst::Action::REST;

use strict;
use warnings;

use base 'Catalyst::Action';
use Class::Inspector;
use Moose::Util qw(does_role);
use Catalyst;
use Catalyst::RequestRole::REST;
use Catalyst::Controller::REST;
use namespace::clean -except => 'meta';

BEGIN { require 5.008001; }

our $VERSION = '0.73';

=head1 NAME

Catalyst::Action::REST - Automated REST Method Dispatching

=head1 SYNOPSIS

    sub foo :Local :ActionClass('REST') {
      ... do setup for HTTP method specific handlers ...
    }

    sub foo_GET { 
      ... do something for GET requests ...
    }

    sub foo_PUT { 
      ... do somethign for PUT requests ...
    }

=head1 DESCRIPTION

This Action handles doing automatic method dispatching for REST requests.  It
takes a normal Catalyst action, and changes the dispatch to append an
underscore and method name. 

For example, in the synopsis above, calling GET on "/foo" would result in
the foo_GET method being dispatched.

If a method is requested that is not implemented, this action will 
return a status 405 (Method Not Found).  It will populate the "Allow" header 
with the list of implemented request methods.  You can override this behavior
by implementing a custom 405 handler like so:

   sub foo_not_implemented {
      ... handle not implemented methods ...
   }

If you do not provide an _OPTIONS subroutine, we will automatically respond
with a 200 OK.  The "Allow" header will be populated with the list of
implemented request methods.

It is likely that you really want to look at L<Catalyst::Controller::REST>,
which brings this class together with automatic Serialization of requests
and responses.

When you use this module, the request class will be changed to
L<Catalyst::Request::REST>.

=head1 METHODS

=over 4

=item dispatch

This method overrides the default dispatch mechanism to the re-dispatching
mechanism described above.

=cut

sub dispatch {
    my $self = shift;
    my $c    = shift;

    Catalyst::RequestRole::REST->meta->apply($c->request)
        unless does_role($c->request, 'Catalyst::RequestRole::REST');

    my $controller = $c->component( $self->class );
    my $method     = $self->name . "_" . uc( $c->request->method );

    if (my $code = $controller->can($method)) {
        $c->execute( $self->class, $self, @{ $c->req->args } ) if $code;
        local $self->{reverse} = $self->{reverse} . "_" . uc( $c->request->method );
        local $self->{code} = $code;

        return $c->execute( $self->class, $self, @{ $c->req->args } );
    }
    if ($c->request->method eq "OPTIONS") {
        local $self->{reverse} = $self->{reverse} . "_" . uc( $c->request->method );
        local $self->{code} = sub { $self->can('_return_options')->($self->name, @_) };
        return $c->execute( $self->class, $self, @{ $c->req->args } );
    }
    my $not_implemented_method = $self->name . "_not_implemented";
    local $self->{code} = $controller->can($not_implemented_method)
        || sub { $self->can('_return_not_implemented')->($self->name, @_); };

    local $self->{reverse} = $not_implemented_method;

    $c->execute( $self->class, $self, @{ $c->req->args } );
}

my $_get_allowed_methods = sub {
    my ( $controller, $c, $name ) = @_;
    my $class = ref($controller) ? ref($controller) : $controller;
    my $methods    = Class::Inspector->methods($class);
    my @allowed;
    foreach my $method ( @{$methods} ) {
        if ( $method =~ /^$name\_(.+)$/ ) {
            push( @allowed, $1 );
        }
    }
    return @allowed;
};

sub _return_options {
    my ( $method_name, $controller, $c) = @_;
    my @allowed = $controller->$_get_allowed_methods($c, $method_name);
    $c->response->content_type('text/plain');
    $c->response->status(200);
    $c->response->header( 'Allow' => \@allowed );
}

sub _return_not_implemented {
    my ( $method_name, $controller, $c ) = @_;

    my @allowed = $controller->$_get_allowed_methods($c, $method_name);
    $c->response->content_type('text/plain');
    $c->response->status(405);
    $c->response->header( 'Allow' => \@allowed );
    $c->response->body( "Method "
          . $c->request->method
          . " not implemented for "
          . $c->uri_for( $method_name ) );
}

1;

=back

=head1 SEE ALSO

You likely want to look at L<Catalyst::Controller::REST>, which implements
a sensible set of defaults for a controller doing REST.

L<Catalyst::Action::Serialize>, L<Catalyst::Action::Deserialize>

=head1 TROUBLESHOOTING

=over 4

=item Q: I'm getting a "415 Unsupported Media Type" error. What gives?!

A:  Most likely, you haven't set Content-type equal to "application/json", or one of the 
accepted return formats.  You can do this by setting it in your query string thusly:
?content-type=application%2Fjson (where %2F == / uri escaped). 

**NOTE** Apache will refuse %2F unless configured otherise.
Make sure AllowEncodedSlashes On is in your httpd.conf file in order for this to run smoothly.

=cut

=cut




=head1 MAINTAINER

J. Shirley <jshirley@gmail.com>

=head1 CONTRIBUTORS

Christopher Laco

Luke Saunders

John Goulah

Daisuke Maki <daisuke@endeworks.jp>

=head1 AUTHOR

Adam Jacob <adam@stalecoffee.org>, with lots of help from mst and jrockway

Marchex, Inc. paid me while I developed this module.  (http://www.marchex.com)

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

