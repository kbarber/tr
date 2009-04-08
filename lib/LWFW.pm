package LWFW;
use strict;
use warnings;
use utf8;
use attributes;
use feature ":5.10"; 
use mro;  # 5.10...

use CGI();
use PPI();
# use PPI::Cache path => '/var/cache/ppi-cache';

# Schema validation support.
use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use LWFW::Exceptions;
use base qw/LWFW::Attributes LWFW::Plugins/;
__PACKAGE__->mk_ro_accessors(qw/request context stash/);
__PACKAGE__->mk_accessors(qw/debug/);

use Data::Dumper;

=head2 new

  Instantiate new object.  If no CGI or Apache::Request
  object passed, will try and load CGI object.

  Example:
    PACKAGE->new();
    PACKAGE->new($cgi_object);
    PACKAGE->new($apache_request_object);

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  # Either passed CGI object or Apache::Request
  my $request = shift;
  if (not defined $request) {
    $request = new CGI();
  }

  my $self = bless {
               stash   => {},
               request => $request,
             }, $class;

  eval {
    $self->_load_plugins();
    $self->_init();

    # Have different handlers per content-type?
    my ($content_type) = $self->request->content_type() || 'text/html';
    if ($content_type =~ m#([^/]+)/([^/]+)#) {
      my $content_package = join('::', __PACKAGE__, ucfirst($1), ucfirst($2));
      eval("use $content_package;
            \$self->{'context'} = new $content_package(\$self)");
      if ($@) {
        E::Invalid::ContentType->throw($@);
      }
    }
    else {
      E::Invalid::ContentType->throw("Don't know how to handle: " .
                                     $content_type);
    }
  };
  if ($@) {
    $self->_error_handler($@);
  }

  return $self;
}

=head2 handler

=cut
sub handler {
  my $self = shift;

  eval {
    $self->forward($self->request->url(-absolute => 1));
  };
  if ($@) {
    $self->_error_handler($@);
  }

  if ($self->context) {
    $self->context->view();
  }
}

=head2 forward

  Takes a path and works out whether to handle it or pass it off to another 
  module to handle.

=cut
sub forward {
  my $self = shift;

  my $path = shift;

  my $handlers_by_path = $self->_get_handler_paths;

  if (my $handler = $handlers_by_path->{$path}) {
    my $handler_module = $handler->{'package'};
     
    my $new_module = bless $self, $handler_module;
    $new_module->_init();
    $new_module->_run_method();
  }
  else {
    $self->_run_method();
  }
}

=head2 _run_method 

  Called to run a method on the current object.

  Checks that it is a public method.

  Maybe ACL/Audit hooks later.

=cut
sub _run_method {
  my $self   = shift;

  if (my $method = $self->context->method()) {
    if ($self->_is_public_method($method)) {
      if (my $schema = $self->_get_schema(package => ref($self),
                                          method  => $method)) {
        $self->validate_params(schema => $schema);
      }
      return $self->$method($self->context());
    }
    else {
      E::Invalid::Method->throw($method);
    }
  }

  E::Invalid::Method->throw('No method given');
}

=head2 validate_params
 
  Valids params with given schema.

=cut
sub validate_params {
  my ($self, %args) = @_;

  if ($args{'schema'}) {
    my $schema = decode_json($args{'schema'});
    my $params = $self->context->params();
    eval {
      validate($schema, $params);
    };
    if ($@) {
      E::Invalid::Params->throw($@);
    }
  }
}

=head2 doc

  Request:
    time curl -H 'Content-Type: application/json' -u test:test -X POST -d '
    {
      "jsonrpc":"2.0",
      "method":"doc",
      "params":{
        "show":"getDnByUid"
      }
    }
    ' 'http://tr.test.alfresco.com/t/ldap/user'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"doc":" ...documentation... "} 
    }

=cut
sub doc :Global { # TODO: in JSON RPC move to system.* namespace
=begin schema
  {
    "type": "map",
    "required": false,
    "mapping": {
      "show":   { "type": "str", "required": false }
    }
  }
=cut

  my $self = shift;

  # See if documentation for a specific method was wanted
  if ($self->context) {
    if (my $params = $self->context->params()) {
      if ($self->_is_public_method($params->{'show'})) {
        if (my $pod = $self->_get_pod(package => ref($self),
                                      method  => $params->{'show'})) {
          $self->stash->{'result'} = { doc => $pod };
          return;
        }
      }
    }
  }

  # Else display list of available methods
  my %result;
  my $handlers = $self->_get_handler_paths();
  foreach my $path (keys %{$handlers}) {
    my $methods = $handlers->{$path}{'methods'};
    my $package = $handlers->{$path}{'package'};
    if ($path eq '') {
      $path = 'GLOBAL';
    }
    foreach my $method (@{$methods}) {
      if (my $poddoc = $self->_get_pod(package => $package,
                                       method => $method)) {
        $result{$path}{$method} = $poddoc;
      }
    }
  }
  $self->stash->{'result'} = \%result;
}

=head2 schema

  Request:
    time curl -H 'Content-Type: application/json' -u test:test -X POST -d '
    {
      "jsonrpc":"2.0",
      "method":"schema",
      "params":{
        "show":"doc"
      }
    }
    ' 'http://tr.test.alfresco.com/t/'

  Response:
    {
      "jsonrpc":"2.0",
      "result": {"schema": " ...Kwalify schema... "} 
    }

=cut
sub schema :Global {  # TODO: in JSON RPC move to system.* namespace
=begin schema
  {
    "type": "map",
    "required": true,
    "mapping": {
      "show":   { "type": "str", "required": true }
    }
  }
=cut

  my $self = shift;

  if ($self->context) {
    if (my $params = $self->context->params()) {
      if ($self->_is_public_method($params->{'show'})) {
        if (my $pod = $self->_get_schema(package => ref($self),
                                         method  => $params->{'show'})) {
          $self->stash->{'result'} = { schema => $pod };
          return;
        }
      }
    }
  }

  return;
}


=head2 _get_pod
 
  Grabs pod documentation for a given package/method.
  Need to standardise on format so that it can be passed back
  to a caller,
  and that caller be able to present it any way it wants.

  ie maybe pod like this:

  head2 asub

    Description:
      blah

    Example:
      blah

  cut

  Could be returned as:

  {
    method      => asub,
    params      => [a, b, c,],  # (From params attribute)
    description => 'blah',
    example     => 'blah',
  }

=cut
sub _get_pod {
  my ($self, %args) = @_;

  return unless $args{'package'};
  return unless $args{'method'};

  my $module_dir = $self->_get_path_to_module($args{'package'});

  if ($args{'package'} =~ /([^:]+)$/) {
    my $document = PPI::Document->new($module_dir . $1 . '.pm') or die $!;
    if (my $results = $document->find(sub {
                                   $_[1]->isa('PPI::Token::Pod')
                                   and ($_[1]->content =~ /=head2 $args{'method'}/) 
                                 })) {
      my $content = @$results[0]->content();
      $content =~ s/=head2 $args{'method'}//m;
      $content =~ s/=cut//m;
      $content =~ s/\s{2}/ /gm;
      return $content;
    }
  }

  return;
}

=head2 _get_schema
 
  Grab the schema for a method, lots of overlap with get_pod.
  TODO: cleanup.

=cut
sub _get_schema {
  my ($self, %args) = @_;

  return unless $args{'package'};
  return unless $args{'method'};

  my $module_dir = $self->_get_path_to_module($args{'package'});

  if ($args{'package'} =~ /([^:]+)$/) {
    my $document = PPI::Document->new($module_dir . $1 . '.pm') or return;

    if (my $results = $document->find(sub {
                               $_[1]->isa('PPI::Statement::Sub')
                               and ($_[1]->content =~ /sub $args{'method'}/) 
                             })) {
      my $method = @$results[0];
      if (my $children = $method->find(sub {
                                  $_[1]->isa('PPI::Token::Pod')
                                  and ($_[1]->content =~ /=begin schema/) 
                                  })) {
        my ($schema) = @$children[0]->content() =~ /=begin schema(.+)=cut/ms;
        return $schema;
      }
    }
  }

  return;
}

=head2 _error_handler

  Handle errors in module.

=cut
sub _error_handler {
  my ($self, $exception) = @_;

  if (ref($exception)) {
    $self->stash->{'error'} = $exception->description() . ': ' .
                                     $exception->error;

    if ($self->debug()) {
      warn $exception->time . ' :DEBUG INFO: ' . $exception->trace->as_string;
                                 
    }
  }
  else {
    $self->stash->{'error'} = "Unknown error: $exception";
  }
}

=head2 _init

  Override in modules.

=cut
sub _init {
  my $self = shift;
  $self->maybe::next::method(@_);
}

1;
