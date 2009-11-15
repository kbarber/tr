package TR::Request;
use TR::Standard;
require CGI::Simple;

use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

TR::Request - TR::Request object.

=head1 VERSION

See $VERSION

=head1 SYNOPSIS

  my $request = new TR::Request(request => $cgi);
  my $request = new TR::Request(request => $req);
  my $request = new TR::Request(); # CGI::Simple used
  my $params = $request->params;
  my $content_type = $request->content_type()

=head1 DESCRIPTION 

Wraps different request objects up to provide
one consistent interface to them.

=head1 SUBROUTINES/METHODS

=over 4

=cut

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw/req/);

# Abstract Request interfaces.

=item new()

Stores the real request object is passed in - or creates a default 
CGI::Simple and stores that.

=cut 

sub new {
    my ( $proto, %args ) = @_;
    my ($class) = ref $proto || $proto;

    # Either passed CGI object or Apache::Request
    my $request = $args{'request'};
    if ( not $request ) {
        $request = new CGI::Simple;
    }

    my $self = bless { req => $request }, $class;

    return $self;
}

=item content_type()

Returns content type of request

=cut

sub content_type {
    my $self = shift;

    my $content_type;
    if ( $self->req->can('headers_in') ) {
        $content_type = $self->req->headers_in->get('Content-Type')
            || 'text/html';
    }
    else {
        $content_type = $self->req->content_type() || 'text/html';
    }

    return $content_type;
}

=item request_method()

Returns whether it was a POST/GET

=cut

sub request_method {
    my $self = shift;

    my $request_type;
    if ( $self->req->can('request_method') ) {
        $request_type = $self->req->request_method();
    }
    elsif ( $self->req->can('method') ) {
        $request_type = $self->req->method();
    }

    return $request_type;
}

=item request_time()

Returns the request_time if possible.

=cut

sub request_time {
    my $self = shift;

    my $request_time;
    if ( $self->req->can('request_time') ) {
        $request_time = $self->req->request_time();    # mod_perl
    }
    else {

        # TODO: Work out if we can get request time from CGI::Simple etc.
        $request_time = time;
    }

    return $request_time;
}

=item postdata()

Returns raw POST data.

=cut

sub postdata {
    my $self = shift;

    if ( my $content = $self->req->param('POSTDATA') ) {
        return $content;
    }
    elsif ( $self->req->can('read') ) {    # mod_perl
        $self->req->read( $content,
            $self->req->headers_in->get('Content-length') );
        return $content;
    }
}

=item params()

Returns hash array of params

=cut

sub params {
    my $self = shift;

    if ( $self->req->can('Vars') ) {
        if ( my %params = $self->req->Vars() ) {
            return %params;
        }
    }
    else {
        if ( my @params = $self->req->param() ) {
            my %data;
            foreach my $key (@params) {
                $data{$key} = $self->req->param($key);
            }
            return %data;
        }
    }

    return;
}

=item param(@args)

Return a single param, simple accessor.

=cut

sub param {
    my ( $self, @args ) = @_;

    return $self->req->param(@args);
}

=item rpc_path()

Returns the part of the URI minus location. For example:

http://server/t/foo/bar

will return

/foo/bar

=cut

sub rpc_path {
    my $self = shift;

    my $uri      = $self->uri();
    my $location = $self->location();

    $uri =~ s/$location//x;

    return $uri;
}

=item location()

Returns the base location.

=cut

sub location {
    my $self = shift;

    if ( $self->req->can('location') ) {
        return $self->req->location();
    }
    elsif ( $self->uri =~ m#/t#x ) {    # TODO Hacky..
        return '/t';                    # Get from config?
    }

    return q{};
}

=item uri()

Returns the URI

=cut

sub uri {
    my $self = shift;

    if ( $self->req->can('url') ) {
        return $self->req->url( -absolute => 1 );
    }
    else {
        return $self->req->uri();
    }

    return;
}

=item server_name()

Returns the servername

=cut

sub server_name {
    my $self = shift;

    if ( $self->req->can('get_server_name') ) {
        return $self->req->get_server_name();
    }
    else {
        return $self->req->server_name();
    }

    return;
}

=item server_port()

Returns the server port

=cut

sub server_port {
    my $self = shift;

    if ( $self->req->can('get_server_port') ) {
        return $self->req->get_server_port();
    }
    else {
        return $self->req->server_port();
    }

    return;
}

=item protocol()

Returns http or https

=cut

sub protocol {
    my $self = shift;

    if ( $ENV{'HTTPS'} ) {
        return 'https';
    }
    else {
        return 'http';
    }

    return;
}

=back

=head1 AUTHOR

Craig Knox

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

  This file is part of TR.
    
  TR is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
    
  TR is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with TR.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;

