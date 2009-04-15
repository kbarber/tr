package TR::Test;
use TR::Global;

use CGI;
use JSON::XS qw/encode_json/;
use IO::Capture::Stdout;

use base 'Exporter';
our @EXPORT = qw/json_test/;
no warnings 'redefine';

my $id = 0;

=head2 json_test

  Sub which does all the work of setting up the environment for a test.

  ie:
  
  json_test($app, uri => '/', method => 'testmethod', params => {..});

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
  my $cgi = new CGI({POSTDATA => $test_json});

  my $app;

  eval("\$app = new $module(request => \$cgi)");
  if ($@) { die "Unable to run tests $@\n"; }
  
  my $capture = IO::Capture::Stdout->new();
  $capture->start();
  $app->handler();
  $capture->stop();
  
  return join('', $capture->read);
}

1;
