package TR::Context::JSON;
use TR::Standard;
use English;

use Kwalify qw(validate);
use JSON::XS '2.2';

use base 'TR::Context';
__PACKAGE__->mk_ro_accessors(qw/coder json_request/);

=head2 new

  Creates new TR::Context::JSON object

=cut
sub new {
  my $proto = shift;
  my($class) = ref $proto || $proto;

  my $self = bless {
    supported => ['Application/JSON'],
  }, $class;

  return $self;
}

=head2 _init

  Basic JSON RPC setup stuff.

=cut
sub _init {
  my $self  = shift;

  my $request = $self->request;

  $self->{'coder'} = JSON::XS->new->utf8->pretty(1)->allow_nonref;

  my $content;

  # Code for perl < 5.10 - don't use a switch statement.

  for ($request->request_method) {
    /POST/ && do {
      $content = $self->retrieve_json_from_post();
      last;
    };
    /GET/ && do {
      $content = $self->retrieve_json_from_get();
      last;
    };
    E::Fatal->throw("Unable to handle request method '$_'");
  }

  if ($content) {
    if (my $json_request = $self->coder->decode($content)) {

      my $json_rpc_schema = $self->coder->decode(<<'JSONRPC2'
{
  "type": "map",
  "require": true,
  "mapping": {
    "jsonrpc": { "type": "float", "enum": ["2.0"], "required": true },
    "method":  { "type": "str", "required": true },
    "params": { "type": "any", "required": false },
    "id": { "type": "int", "required": false }
  }
}
JSONRPC2
                            );
      eval {
        validate($json_rpc_schema, $json_request);
        1;
      }
      or do {
        E::Invalid->throw(error => "The received JSON not a valid JSON-RPC Request: $EVAL_ERROR",
                          err_code => '-32600');
      };

      $self->{'json_request'} = $json_request;
      return;
    }
  
    E::Invalid->throw(error    => 'Invalid JSON. An error occurred on the server while parsing the JSON text',
                      err_code => '-32700');
  }

  return;
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
  my ($self, %params) = @_;

  $self->{'json_request'}{'params'} = \%params;

  return;
}


=head2 retrieve_json_from_post

  Grabs POST data 

=cut
sub retrieve_json_from_post {
  my $self = shift;

  if (my $content = $self->request->postdata()) {
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
  return;
}

=head2 view

  Displays data

=cut
sub view {
  my $self   = shift;
  my $result = $self->result;

  print "Content-type: application/json\n\n";

  my %rpcdata;
  $rpcdata{'jsonrpc'} = '2.0';

  if (ref($result) eq 'HASH' && $result->{'error'}) {
    my $error = $result->{'error'};
    $rpcdata{'error'} = {
      name    => "JSONRPCError",
      message => $error,
    };
  }
  else {
    $rpcdata{'result'} = $result;  
  }
  
  if (my $id = $self->json_request->{'id'}) {
    $rpcdata{'id'} = $id;
  }

  print $self->coder->encode(\%rpcdata);

  return;
}

=head2 error_handler


=cut
sub error_handler {
  my ($self, $exception) = @_;

  return;
}

1;
