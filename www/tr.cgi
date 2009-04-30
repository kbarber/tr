#!/usr/bin/perl
use strict;
use warnings;
use lib '/home/knoxc/Projects/TR.perl/services';
use lib '/home/knoxc/Projects/TR.perl/engine/lib';
use TR;

my $tr = new TR(config => '/home/knoxc/Projects/TR.perl/config/registry.conf');
$tr->handler();

