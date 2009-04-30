package TR::Request;
use TR::Standard;
require CGI::Simple;

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw/req/);

# Abstract Request interfaces.

=head2 new 

  Stores the real request object is passed in - or creates a default 
  CGI::Simple and stores that.

=cut 
sub new {
  my ($proto, %args) = @_;
  my ($class) = ref $proto || $proto;

  # Either passed CGI object or Apache::Request
  my $request = $args{'request'};
  if (not $request) {
    $request = new CGI::Simple;
  }

  my $self = bless {
    req => $request
  }, $class;

  return $self;
}

=head2 content_type

  Returns content type of request

=cut
sub content_type {
  my $self = shift;

  my $content_type;
  if ($self->req->can('headers_in')) {
    $content_type = $self->req->headers_in->get('Content-Type') || 'text/html';
  }
  else {
    $content_type = $self->req->content_type() || 'text/html';
  }

  return $content_type;
}

=head2 request_method

  Returns whether it was a POST/GET

=cut
sub request_method {
  my $self = shift;

  my $request_type;
  if ($self->req->can('request_method')) {
    $request_type = $self->req->request_method();
  }
  elsif ($self->req->can('method')) {
    $request_type = $self->req->method();
  }

  return $request_type;
}

=head2 postdata

  Returns raw POST data.

=cut
sub postdata {
  my $self = shift;

  if (my $content = $self->req->param('POSTDATA')) {
    return $content;
  }
  elsif ($self->req->can('read')){  # Mod_perl
    $self->req->read($content, $self->req->headers_in->get('Content-length'));
    return $content;
  } 
}

=head2 params

  Returns hash array of params

=cut
sub params {
  my $self = shift;

  if ($self->req->can('Vars')) {
    if (my %params = $self->req->Vars()) {
      return %params;
    }
  }
  else {
    if (my @params = $self->req->param()) {
      my %data;
      foreach my $key (@params) {
        $data{$key} = $self->req->param($key);
      }
      return %data;
    }
  }

  return;
}

=head2 param

  Return a single param, simple accessor.

=cut
sub param {
  my $self = shift;
  return $self->req->param(@_);
}

=head2 uri

  Returns the URI

=cut
sub uri {
  my $self = shift;

  if ($self->req->can('url')) {
    return $self->req->url(-absolute => 1);
  }
  else {
    return $self->req->uri();
  }

  return;
}

1;


