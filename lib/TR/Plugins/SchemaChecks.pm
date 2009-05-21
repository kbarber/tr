package TR::Plugins::SchemaChecks;
use TR::Standard;
use TR::Exceptions;
use TR::Pod;

# Schema validation support. 
# Permance:  We take a big hit doing schemas this way:
#   Requests per second:    56.76  with
#   Requests per second:    124.39 without
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
    eval {
      validate(decode_json($schema), $params);
    };
    if ($@) {
      E::Invalid::Params->throw(error    => $@,
                                err_code => '-32602');
    }
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
    eval {
      validate(decode_json($schema), $result);
    };
    if ($@) {
      E::Invalid::Result->throw(error    => $@,
                                err_code => '-32602');
    }
  }

  return;
}

1;
