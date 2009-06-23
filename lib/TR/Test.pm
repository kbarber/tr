package TR::Test;
use TR::Standard;
use English qw(-no_match_vars);

use vars qw($VERSION);
use version; $VERSION = qv('1.0');

=head1 NAME

    TR::Test - Used for writing unit tests

=head1 VERSION

  See $VERSION

=head1 LICENSE AND COPYRIGHT

  GNU GENERAL PUBLIC LICENSE
	Version 3, 29 June 2007

  Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

=head1 SYNOPSIS

    use TR::Test;

=head1 DESCRIPTION

=head1 DIAGNOSTICS

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

=head1 SUBROUTINES/METHODS

=cut

## no critic (ProhibitAutomaticExportation RequireExtendedFormatting ProhibitImplicitNewlines ProhibitNoWarnings ProhibitStringyEval RequireCheckingReturnValueOfEval)

use CGI::Simple;
use JSON::XS qw/encode_json decode_json/;
use Kwalify qw/validate/;
use IO::Capture::Stdout;
use Time::HiRes qw/gettimeofday tv_interval/;
use base 'Exporter';
our @EXPORT = qw/json_test/;
no warnings 'redefine';

my $id = 0;

=head2 json_test

  Sub which does all the work of setting up the environment for a test.

  ie:
  
  my $response = json_test($app, uri => '/', method => 'testmethod', params => {..});

  my ($response, $time) = json_test($app, uri => '/', method => 'testmethod', params => {..});

=cut

sub json_test {
    my ( $module, %args ) = @_;

    my $test_data = {
        'jsonrpc' => '2.0',
        'method'  => $args{'method'},
        'params'  => $args{'params'},
        'id'      => ++$id,
    };

    local $ENV{'CONTENT_TYPE'}   = 'application/json';
    local $ENV{'REQUEST_METHOD'} = 'POST';
    local $ENV{'SCRIPT_NAME'}    = $args{'uri'};

    my $test_json = encode_json $test_data;

    local $ENV{'CONTENT_LENGTH'} = length($test_json);
    my $cgi = new CGI::Simple( { POSTDATA => $test_json } );

    my $app;

    my %tr_args;
    $tr_args{'request'} = $cgi;

    # Ugly.. for now.
    if ( $ENV{'TR_CONFIG_FILE'} ) {
        $tr_args{'config'} = $ENV{'TR_CONFIG_FILE'};
    }

    # Try and create the new instance of TR
    eval("\$app = new $module(\%tr_args)");
    if ($EVAL_ERROR) { die "Unable to run tests $EVAL_ERROR\n"; }

    # Capture output and time handler
    my $capture = IO::Capture::Stdout->new();
    $capture->start();
    my $t0 = [gettimeofday];
    $app->handler();
    my $elapsed = tv_interval($t0);
    $capture->stop();

    my $response = join( q{}, $capture->read );

    # validate
    if ( my $result = $args{'validate'} ) {
        $response =~ s/Content-type: application\/json//;
        my $schema = '
      {
        "type": "map",
        "require": true,
        "mapping": {
          "jsonrpc": { "type": "float", "enum": ["2.0"], "required": true },
          "id": { "type": "int", "required": false },
          "result": { "type": "map", "mapping": ' . $result . ' }
        }
      }';
        eval {
            validate( decode_json($schema), decode_json($response) );
            1;
        }
        or do {
            return $EVAL_ERROR;
        };
    }

    return wantarray ? ( $response, $elapsed ) : $response;
}

1;
