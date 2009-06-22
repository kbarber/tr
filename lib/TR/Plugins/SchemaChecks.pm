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

=head1 LICENSE AND COPYRIGHT

    GNU GENERAL PUBLIC LICENSE
	  Version 3, 29 June 2007

    Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

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


=head1 CONFIGURATION AND ENVIRONMENT

    See <TR>

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

  Probably a few.

=head1 SUBROUTINES/METHODS

=cut

use Kwalify qw(validate);
use JSON::XS qw(decode_json);

use base 'Class::Accessor::Fast';

=head2 pre_method_hook 

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

=head2 post_method_hook 

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

1;
