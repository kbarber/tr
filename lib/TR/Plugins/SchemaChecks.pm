package TR::Plugins::SchemaChecks;
use TR::Global;
use TR::Exceptions;
use TR::Pod;

# Schema validation support.
use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use base 'Class::Accessor::Fast';

sub pre_method {
  my ($self, %args) = @_;

  my $pod = new TR::Pod;

  if (my $schema = $pod->get_schema(package => $args{'package'},
                                    method  => $args{'method'})) {
    $self->_validate_params(schema => $schema, context => $args{'context'});
  }
}

=head2 _validate_params
 
  Valids params with given schema.

=cut
sub _validate_params {
  my ($self, %args) = @_;

  if ($args{'schema'}) {
    my $schema = decode_json($args{'schema'});
    my $params = $args{'context'}->params();
    eval {
      validate($schema, $params);
    };
    if ($@) {
      E::Invalid::Params->throw(error    => $@,
                                err_code => '-32602');
    }
  }
}

1;
