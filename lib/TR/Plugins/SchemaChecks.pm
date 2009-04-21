package TR::Plugins::SchemaChecks;
use TR::Standard;
use TR::Exceptions;
use TR::Pod;

# Schema validation support.
use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use base 'Class::Accessor::Fast';

=head2 pre_method_hook 

  Validates params with schema before method is run.

=cut
sub pre_method_hook {
  my ($self, %args) = @_;

  my $pod = new TR::Pod;

  my $control = $args{'control'};
  my $params = $control->context->params();

  if (my $schema = $pod->get_schema(package => ref($control),
                                    method  => $args{'method'})) {
    $self->_validate_params(schema => $schema, data => $params);
  }

  return;
}

=head2 post_method_hook 

  Validates result with schema (if given).

=cut
sub post_method_hook {
  my ($self, %args) = @_;

  my $pod = new TR::Pod;

  my $control = $args{'control'};
  my $result = $control->context->result();

  if (my $schema = $pod->get_result_schema(package => ref($control),
                                           method  => $args{'method'})) {
    $self->_validate_params(schema => $schema,
                            data   => $result);
  }

  return;
}


=head2 _validate_params
 
  Valids params with given schema,
  throws an exception if they don't validate correctly..

=cut
sub _validate_params {
  my ($self, %args) = @_;

  if ($args{'schema'}) {
    my $schema = decode_json($args{'schema'});

    eval {
      validate($schema, $args{'data'});
    };
    if ($@) {
      E::Invalid::Params->throw(error    => $@,
                                err_code => '-32602');
    }
  }

  return;
}

1;
