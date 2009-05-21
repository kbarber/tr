package TR;
use TR::Standard;
use Module::Pluggable search_path => 'TR::Context',
                      sub_name    => 'context_handlers',
                      instantiate => 'new';

use Module::Pluggable search_path => 'TR::Plugins',
                      sub_name    => 'plugins',
                      instantiate => 'new';

use Module::Pluggable search_path => 'TR::C',
                      sub_name    => 'controllers',
                      instantiate => 'new';

# TODO Move error handling to context.

use attributes;

use Log::Log4perl;

use TR::Pod;
use TR::Config;
use TR::Exceptions;
use TR::Request;

use base 'TR::Attributes';
__PACKAGE__->mk_ro_accessors(qw/request
                                config/);

__PACKAGE__->mk_accessors(qw/debug
                             context
                             version
                             log/);

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

  my $request = new TR::Request(%args);

  my $self = bless {
               version => $VERSION,
             }, $class;

  if ($args{'config'}) {
    if (-f $args{'config'}) {
      $self->{'config'} = new TR::Config($args{'config'});
    }
    else {
      E::Invalid::Config->throw("Couldn't find config file: $args{'config'}");
    }

    # Try and see if logging is configured.
    if (my $log_config = $self->config->{'log'}) {
      Log::Log4perl->init_once($log_config->{'conf'});
      if (my $logger = Log::Log4perl->get_logger()) {
        $self->log($logger);
      }
    }
  }

  # Default logging setup.
  if (not $self->log) {
    Log::Log4perl->init(\q{
      log4perl.rootLogger=ERROR, LOGFILE   

      log4perl.appender.LOGFILE=Log::Log4perl::Appender::ScreenColoredLevels
      log4perl.appender.LOGFILE.mode=append
    
      log4perl.appender.LOGFILE.layout=PatternLayout
      log4perl.appender.LOGFILE.layout.ConversionPattern=[%d] %m%n
    });
    if (my $logger = Log::Log4perl->get_logger()) {
      $self->log($logger);
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
    $self->_error_handler($@);
  }

  # This preloads the controllers so we know what paths are handled
  $self->_get_controller(type => 'Whoknows');

  return $self;
}

=head2 handler

=cut
sub handler {
  my $self = shift;
  
  eval {
    $self->forward($self->context->request->rpc_path());
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

  if (my $handler = $handlers_by_path->{$path}) {
    $self->_run_method($args{'method'},
                       'package' => $handler->{'package'},
                       context   => $self->context);
  }
  else {
    $self->_run_method($args{'method'},
                       'package' => 'TR::C::System',
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

  warn $exception;
  if (ref($exception)) {
    my %error;
    $error{'message'} = $exception->description() .
                        ': ' .
                        $exception->error;

    $self->log->error($error{'message'});

    $self->log->debug($exception->description() .
                      ' : ' .
                      $exception->error() .
                      ' : ' .
                      $exception->trace->as_string);


    $error{'err_code'} = $exception->err_code();
    $self->context->result({error => \%error});
  }
  else {
    $self->context->result({error => "Unknown error"});
    $self->log->error("Unknown error: $exception");
  }
}

1;
