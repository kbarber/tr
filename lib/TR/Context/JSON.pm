package TR::Context::JSON;
use TR::Global;

use base 'Class::Accessor::Fast';
__PACKAGE__->mk_ro_accessors(qw/coder json_request/);
__PACKAGE__->mk_accessors(qw/request/);

=head2 new

  Creates new TR::Application::Json object to handle application/json

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  my $coder = JSON::XS->new->utf8->pretty(1)->allow_nonref;

  my $self = bless {
               context => {},
               coder   => $coder,
             }, $class;

  return $self;
}

=head2 handles

 Called by TR to see if this module handles the current contact type.

=cut
sub handles {
  my ($self, %args) = @_;

  my @SUPPORTED_TYPES = ('Application/JSON');

  my $request      = $args{'request'};
  my $content_type = $request->content_type();

  foreach my $type (@SUPPORTED_TYPES) {
    if ( lc($content_type) eq lc($type)) {
      $self->request($request);
      $self->_init();
      return $self;
    }
  }

  return;
}

=head2 _init

  Basic JSON RPC setup stuff.

=cut
sub _init {
  my $self  = shift;

  my $request = $self->request;

  my $content;

  # Code for perl < 5.10 and don't use a switch statement.
  for ($request->request_method()) {
    /POST/ && do {
      $content = $self->retrieve_json_from_post();
      last;
    };
    /GET/ && do {
      $content = $self->retrieve_json_from_get();
      last;
    };
    warn ("Unable to handle request method '$_'");
  }

  if ($content) {
    if (my $json_request = $self->coder->decode($content)) {
      if (not $json_request->{'jsonrpc'} eq '2.0') {
        E::Invalid->throw(error => 'The received JSON not a valid JSON-RPC Request',
                          err_code => '-32600');
      }
      $self->{'json_request'} = $json_request;
      return;
    }
  
    E::Invalid->throw(error    => 'Invalid JSON. An error occurred on the server while parsing the JSON text',
                      err_code => '-32700');
  }

}

=head2 method 

  simple accessor to method called in JSON RPC.

=cut
sub method {
  my $self = shift;

  if (my $json_request = $self->json_request()) {
    if (exists($json_request->{'method'})) {
      return $json_request->{'method'};
    }
  }

  return;
}

=head2 params

  simple accessor to params called in JSON RPC.

=cut
sub params {
  my $self = shift;

  if (my $json_request = $self->json_request()) {
    if (exists($json_request->{'params'})) {
      return $json_request->{'params'};
    }
  }

  return;
}

=head2 set_params

  Work around for setting params for others.  TODO - do in a better way?

=cut
sub set_params {
  my $self   = shift;
  my %params = @_;

  $self->{'json_request'}{'params'} = \%params;

  return;
}


=head2 retrieve_json_from_post

  Grabs POST data 

=cut
sub retrieve_json_from_post {
  my $self = shift;

  my $request = $self->request();
  if (my $content = $request->param('POSTDATA')) {
    return $content;
  }
  return;
}


=head2 retrieve_json_from_get

  Unimplemented

=cut
sub retrieve_json_from_get {
  my $self = shift;
  # TODO
}

=head2 view

  Displays data

=cut
sub view {
  my $self = shift;
  my $data = shift;

  print "Content-type: application/json\n\n";

  my %rpcdata;
  $rpcdata{'jsonrpc'} = '2.0';

  if (my $error = $data->{'error'}) {
    $rpcdata{'error'} = {
      name    => "JSONRPCError",
      code    => $error->{'err_code'},
      message => $error->{'message'},
    };
  }
  else {
    my $result = $data->{'result'};
    $rpcdata{'result'} = $result;  
  }
  
  if (my $id = $self->json_request->{'id'}) {
    $rpcdata{'id'} = $id;
  }

  print $self->coder->encode(\%rpcdata);
}

1;
