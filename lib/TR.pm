package TR;
use TR::Global;
use Module::Pluggable search_path => 'TR::Context',
                      sub_name    => 'context_handlers',
                      instantiate => 'new';

use Module::Pluggable search_path => 'TR::Plugins',
                      sub_name    => 'plugins',
                      instantiate => 'new';

use Module::Pluggable search_path => 'TR::C',
                      sub_name    => 'controllers',
                      instantiate => 'new';

# TODO Split this into handler and default control object.
#      Move error handling to context.

use attributes;
use Want;

use CGI::Simple;

use TR::Pod;
use TR::Config;
use TR::Exceptions;
use base 'TR::Attributes';
__PACKAGE__->mk_ro_accessors(qw/request
                                config/);

__PACKAGE__->mk_accessors(qw/debug
                             context
                             version/);

my $VERSION = '0.03';

=head2 new

  Instantiate new object.  If no CGI or Apache::Request
  object passed, will try and load CGI object.

  Example:
    PACKAGE->new();
    PACKAGE->new(request => $cgi_object);
    PACKAGE->new(request => $apache_request_object);

=cut
sub new {
  my ($proto, %args) = @_;
  my ($class) = ref $proto || $proto;

  # Either passed CGI object or Apache::Request
  my $request = $args{'request'};
  if (not defined $request) {
    $request = new CGI::Simple;
  }

  my $self = bless {
               version => $VERSION,
             }, $class;

  if ($args{'config'}) {
    if (-f $args{'config'}) {
      $self->{'config'} = new TR::Config($args{'config'});
    }
    else {
      die "Couldn't find config file: $args{'config'}";
    }
  }

  eval {
    foreach my $context ($self->context_handlers()) {
      next unless $context->can('handles');
      if ($context->handles(request => $request)) {
        $self->context($context);
        last;
      };
    }

    if (not $self->context()) {
      E::Invalid::ContentType->throw("Don't know how to handle: " .
                                     $request->content_type());
    }
  };
  if ($@) {
    warn "$@\n";
    $self->_error_handler($@);
  }

  return $self;
}

=head2 handler

=cut
sub handler {
  my $self = shift;
  
  eval {
    $self->forward($self->context->request->url(-absolute => 1));
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
  my ($self, $path, %args) = @_;

  my $handlers_by_path = $self->_get_handler_paths;

  # This preloads the controllers so we know what paths are handled
  # plus gives us our default controller.
  my $default = $self->_get_controller(type => 'TR::C::System');

  if (my $handler = $handlers_by_path->{$path}) {
    $self->_run_method($args{'method'},
                       'package' => $handler->{'package'},
                       context   => $self->context);
  }
  else {
    $self->_run_method($args{'method'},
                       'package' => ref($default),
                       context   => $self->context);
  }

  return;
}

=head2
  
  Returns a controller matching given type

=cut
sub _get_controller {
  my ($self, %args) = @_;

  return if not $args{'type'};

  my @controllers = $self->controllers(context => $self->context,
                                       config  => $self->config);

  foreach my $controller (@controllers) {
    if (ref($controller) eq $args{'type'}) {
      return $controller;
    }
  }

  return;
}

=head2 _run_method 

  Called to run a method on the current object.

  Checks that it is a public method.

=cut
sub _run_method {
  my ($self, $method, %args) = @_;

  if (not $method) {
    $method = $args{'context'}->method();
  }

  if ($method) {
    $method =~ s/\./_/;

    my $control; 
    
    if (not $control = $self->_get_controller(type => $args{'package'})) {
      $control = $self; # For now
    }

    if ($control->_is_public_method($method)) {
      # Hook to allow a plugins to run before a method has been called.
      foreach my $plugin ($self->plugins) {
        next unless $plugin->can('pre_method_hook');
        $plugin->pre_method_hook(control => $control,
                                 method  => $method);
      }

      # Run the method
      eval {
        $control->$method();
      };

      # Not sure about this way of redirecting between controllers...
      # Seems wrong to raise an error to cause a redirect,
      # but it was a quick fix till a nice way is done.. 
      # maybe via attributes? sub createUser :Alias(/ldap/user)
      my $e;
      if ($e = Exception::Class->caught('E::Redirect')) {
        my $method = $e->method || $self->context->method();
        $self->forward($e->newpath, method => $method);
      }
      elsif ($e = Exception::Class->caught())  {
        ref $e ? $e->rethrow : die $e;
      }


      # Hook to allow a plugins to run after a method has been called.
      foreach my $plugin ($self->plugins) {
        next unless $plugin->can('post_method_hook');
        $plugin->post_method_hook(control => $control,
                                  method  => $method);
      }
      return;
    }
    else {
      E::Invalid::Method->throw(error    => $method,
                                err_code => '-32601' );
    }
  }

  E::Invalid::Method->throw(error    => 'No method given',
                            err_code => '-32601' );
}

=head2 _error_handler

  Handle errors in module.

=cut
sub _error_handler {
  my ($self, $exception) = @_;

  if (ref($exception)) {
    $self->log(level   => 'error',
               message => $exception->time .
                          ' :DEBUG INFO: ' .
                          $exception->trace->as_string);

    my %error;
    $error{'message'} = $exception->description() .
                        ': ' .
                        $exception->error .
                        ': ' .
                        $exception->trace->as_string;

    $error{'err_code'} = $exception->err_code();
    $self->context->result({error => \%error});
  }
  else {
    $self->context->result({error => "Unknown error: $exception"});
    $self->log(level   => 'error',
               message => "Unknown error: $exception");
  }
}

=head2 log

  Handles logging

=cut
sub log {
  my ($self, %args) = @_;
}

1;
