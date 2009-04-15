#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use CGI;

use lib "$Bin/../lib";
use lib "$Bin";

use Test::More tests => 7;
use TR::Test;

use_ok('TR::Pod');
use_ok('TR::Plugins');
use_ok('TR');

my $response = json_test('TR', uri => '/', method => 'testmethod', params => {aparam => 'test'});
like($response, qr/Method is unsupported: testmethod/, 'Correct error given for unsupported method');

$response = json_test('TR', uri => '/', method => 'system.version');
like($response, qr/"version"/, 'Can get version');

$response = json_test('TR', uri => '/', method => 'system.doc', params => { show => 'system_schema' });
like($response, qr/"version"/, 'Can show doc for schema method');

$response = json_test('TR', uri => '/', method => 'system.schema', params => { show => 'system_doc' });
like($response, qr/"version"/, 'Can show schema method system_doc');

