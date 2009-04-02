#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use CGI;

use lib "$Bin/../lib";
use lib "$Bin";

use Test::More tests => 3;

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

  ok(my $fw = LWFW->new($cgi), 'Can create LWFW object');
  ok($fw->dispatch(), "Can dispatch $ENV{'SCRIPT_NAME'})");
}

