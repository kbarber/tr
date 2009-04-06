#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use CGI;

use lib "$Bin/../lib";
use lib "$Bin";

use Test::More tests => 4;
use Test::Exception;

use_ok('LWFW');

# Set ENV variables for CGI object for testing with.
$ENV{'CONTENT_TYPE'}   = 'application/json';
$ENV{'REQUEST_METHOD'} = 'POST';
$ENV{'SCRIPT_NAME'}    = "/";

{
  my $test_json = '{
    "jsonrpc":"2.0",
    "method":"testmethod",
    "params":{
      "aparam":"testtext"
    },
    "id":1
  }';

  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI({POSTDATA => $test_json});

  my $fw;
  dies_ok { $fw = LWFW->new($cgi) } 'LWFW object dies with incorrect method';
}

{
  my $test_json = '{
    "jsonrpc":"2.0",
    "method":"doc",
    "params":{
      "show":"schema"
    }
  }';

  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI({POSTDATA => $test_json});

  my $fw;
  lives_ok { $fw = LWFW->new($cgi) } 'Can show doc for schema';
}

{
  my $test_json = '{
    "jsonrpc":"2.0",
    "method":"schema",
    "params":{
      "show":"doc"
    }
  }';

  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI({POSTDATA => $test_json});

  my $fw;
  lives_ok { $fw = LWFW->new($cgi) } 'Can show schema for doc';
}

