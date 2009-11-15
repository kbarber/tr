package TR::Plugins::SchemaChecks;
use TR::Standard;
use TR::Pod;
use TR::Exceptions;
use English qw(-no_match_vars);

use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

TR::Plugins::SchemaChecks - 

=head1 VERSION

See $VERSION

=head1 SYNOPSIS

  package TR::C::example;
  use TR::Standard;

  use base 'TR::C::System';

  sub _init {
    # Setup...
  }

  sub helloworld :Local {

  =begin schema
  {
    "type": "map",
    "required": true,
    "mapping": {
      "name": { "type":"str", "required": true }
    }
  }
  =cut

    my $self = shift;
    my $params = $self->context->params;
    my $name = $params->{'name'}
    $self->context->result(message => "Hello $name");

  =begin result_schema
  {
    "type": "map",
    "required": true,
    "mapping": {
      "message": { "type": "str" }
    }
  }
  =cut

  }

=head1 DESCRIPTION 

Handles validation of incoming parameters 
and outgoing information using schemas defined within 
a function.  If no schema defined, no validation is
done.

Schemas defined are accessible via 'system.schema',
ie: 

  http://some.server/tr/example?method=system.schema&show=helloworld

=head1 SUBROUTINES/METHODS

=over 4

=cut

use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use base 'Class::Accessor::Fast';

=item pre_method_hook(%args)

Validates params with schema before method is run.

=cut

sub pre_method_hook {
    my ( $self, %args ) = @_;

    my $pod = new TR::Pod;

    my $control = $args{'control'};
    my $params  = $control->context->params();

    if (my $schema = $pod->get_schema(
            package => ref($control),
            method  => $args{'method'}
        )) {
        ## no critic (RequireCheckingReturnValueOfEval)
        eval { validate( decode_json($schema), $params ); };
        if ($EVAL_ERROR) {
            E::Invalid::Params->throw(
                error    => $EVAL_ERROR,
                err_code => '-32602'
            );
        }
    }

    return;
}

=item post_method_hook(%args)

Validates result with schema (if given).

=cut

sub post_method_hook {
    my ( $self, %args ) = @_;

    my $pod = new TR::Pod;

    my $control = $args{'control'};
    my $result  = $control->context->result();

    if (my $schema = $pod->get_result_schema(
            package => ref($control),
            method  => $args{'method'}
        )) {
        ## no critic (RequireCheckingReturnValueOfEval)
        eval { validate( decode_json($schema), $result ); };
        if ($EVAL_ERROR) {
            E::Invalid::Result->throw(
                error    => $EVAL_ERROR,
                err_code => '-32602'
            );
        }
    }

    return;
}

=back

=head1 AUTHOR

Craig Knox

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

  This file is part of TR.
    
  TR is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
    
  TR is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with TR.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
