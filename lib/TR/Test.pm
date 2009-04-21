package TR::Test;
use TR::Standard;

use CGI::Simple;
use JSON::XS qw/encode_json/;
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
  my ($module, %args) = @_;

  my $test_data = {
    'jsonrpc' => '2.0',
    'method'  => $args{'method'},
    'params'  => $args{'params'},
    'id'      => ++$id,
  };

  $ENV{'CONTENT_TYPE'}   = 'application/json';
  $ENV{'REQUEST_METHOD'} = 'POST';
  $ENV{'SCRIPT_NAME'}    = $args{'uri'};

  my $test_json = encode_json $test_data;
  
  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI::Simple({POSTDATA => $test_json});

  my $app;

  my %tr_args;
  $tr_args{'request'} = $cgi;

  # Ugly.. for now.
  if ($ENV{'TR_CONFIG_FILE'}) {
    $tr_args{'config'} = $ENV{'TR_CONFIG_FILE'};
  }

  # Try and create the new instance of TR
  eval("\$app = new $module(\%tr_args)");
  if ($@) { die "Unable to run tests $@\n"; }
 
  # Capture output and time handler
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  my $t0 = [gettimeofday];
  $app->handler();
  my $elapsed = tv_interval ($t0);
  $capture->stop();

  my $response = join('', $capture->read);
  return wantarray ? ($response, $elapsed) : $response;
}

1;
