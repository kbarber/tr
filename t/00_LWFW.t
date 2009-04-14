#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use CGI;

use lib "$Bin/../lib";
use lib "$Bin";

use Test::More tests => 11;
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
  lives_ok { $fw = LWFW->new($cgi) } 'Can create LWFW object';
  lives_ok { $fw->handler() } 'LWFW object error with incorrect method';
}

{
  my $test_json = '{
    "jsonrpc":"2.0",
    "method":"forward",
    "params":{
      "aparam":"testtext"
    },
    "id":1
  }';

  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI({POSTDATA => $test_json});

  my $fw;
  lives_ok { $fw = LWFW->new($cgi) } 'Can create LWFW object';
  lives_ok { $fw->handler() } 'LWFW object errors with incorrect method';
}

{
  my $test_json = '{
    "jsonrpc":"2.0",
    "method":"system.doc",
    "params":{
      "show":"system_schema"
    }
  }';

  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI({POSTDATA => $test_json});

  my $fw;
  lives_ok { $fw = LWFW->new($cgi) } 'Can create LWFW object';
  lives_ok { $fw->handler() } 'Can show doc for schema';
}

{
  my $test_json = '{
    "jsonrpc":"2.0",
    "method":"system.schema",
    "params":{
      "show":"system_doc"
    }
  }';

  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI({POSTDATA => $test_json});

  my $fw;
  lives_ok { $fw = LWFW->new($cgi) } 'Can create LWFW object';
  lives_ok { $fw->handler() } 'Can show schema for doc';
}

{
  my $test_json = '{
    "jsonrpc":"2.0",
    "method":"system.version",
  }';

  $ENV{'CONTENT_LENGTH'} = length($test_json);
  my $cgi = new CGI({POSTDATA => $test_json});

  my $fw;
  lives_ok { $fw = LWFW->new($cgi) } 'Can create LWFW object';
  lives_ok { $fw->handler() } 'Can get version';
}

