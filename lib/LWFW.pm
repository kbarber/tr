package LWFW;
use strict;
use warnings;
use attributes;
use feature ":5.10";
use mro;

use CGI();
use PPI();

use base qw/LWFW::Attributes LWFW::Plugins/;
__PACKAGE__->mk_ro_accessors(qw/request context/);

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
               request => $request,
             }, $class;

  $self->_load_plugins();
  $self->_init();

  # Have different handlers per content-type?
  my $content_type = $self->request->content_type();
  if ($content_type =~ m#([^/]+)/([^/]+)#) {
    my $content_package = join('::', __PACKAGE__, ucfirst($1), ucfirst($2));
    eval("use $content_package;
          \$self->{'context'} = new $content_package(\$self)");
    if ($@) {
      warn "Don't know how to handle $content_type: $@\n";
    }
  }
  else {
      warn "Unknown content_type $content_type\n";
  }

  return $self;
}

=head2 dispatch

  Takes a path and works out whether to handle it or pass it off to another 
  module to handle.

=cut
sub dispatch {
    my $self = shift;

    my $path = shift || $self->request->url(-absolute => 1);
    
    my $handlers_by_path = $self->_get_handler_paths;

    if (my $handler = $handlers_by_path->{$path}) {
      my $handler_module = $handler->{'package'};
     
      my $new_module = bless $self, $handler_module;
      $new_module->_init();
      return $new_module->_run_method();

    }
    elsif(not $self->_run_method()) {
      return $self->doc();
    }

    return 1;
}

=head2 _run_method 

  Called to run a method on the current object.

  Checks that it is a public method.

  Maybe ACL/Audit hooks later.

=cut
sub _run_method {
  my $self   = shift;

  my $method = $self->context->method();

  if ($self->_is_public_method($method)) {
    $self->$method();    
    return 1;
  }
  else {
    warn "Don't know how to handle $method\n"; 
  }

  return;
}

=head2 doc
 
  Handles documentation

=cut
sub doc : Regex('/doc$') {
  my $self = shift;
  my $method = '';

  print "\n---------------My Supported Methods---------------";
  my $handlers = $self->_get_handler_paths();
  foreach my $path (keys %{$handlers}) {
    my $methods = $handlers->{$path}{'methods'};
    my $package = $handlers->{$path}{'package'};
    if ($path eq '') {
      $path = 'GLOBAL';
    }
    print "\n$path\n";
    foreach my $method (@{$methods}) {
      print "\t$method\n";
      if (my $poddoc = $self->_get_pod(package => $package,
                                       method => $method)) {
        print "\t\t$poddoc\n";
      }
    }
  }
  print "---------------------------------------------------\n";

  return 1;
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

  if ($args{'package'} =~ /::([^:]+)$/) {
    my $document = PPI::Document->new($module_dir . $1 . '.pm') or return;
    if (my $results = $document->find(sub {
                                   $_[1]->isa('PPI::Token::Pod')
                                   and ($_[1]->content =~ /=head2 $args{'method'}/) 
                                 })) {
      my $content = @$results[0]->content();
      $content =~ s/=head2 $args{'method'}//m;
      $content =~ s/=cut//m;
      $content =~ s/\n//gm;
      $content =~ s/\s{2}/ /gm;
      return $content;
    }
  }

  return;
}

=head2 _init

  Override in modules.

=cut
sub _init {
  my $self = shift;
  $self->maybe::next::method(@_);
}

1;
