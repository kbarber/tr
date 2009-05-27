#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use CGI;

use lib "$Bin/../lib";
use lib "$Bin";

use Test::More tests => 6;
use TR::Test;

use_ok('TR::Pod');
use_ok('TR');

my ($response, $time);

$response = json_test('TR', uri => '/t', method => 'testmethod', params => {aparam => 'test'});
like($response, qr/Method is unsupported: testmethod/, 'Correct error given for unsupported method');

$response = json_test('TR', uri => '/', method => 'system.version');
like($response, qr/"version"/, 'Can get version');

($response, $time) = json_test('TR', uri => '/t', method => 'system.doc', params => { show => 'system_schema' });
like($response, qr/"poddoc"/, "Can show doc for system_schema method ($time seconds)");

($response, $time) = json_test('TR', uri => '/', method => 'system.schema', params => { show => 'system_doc' });
like($response, qr/"schema"/, "Can show schema for system_doc method ($time seconds)");

