#!/usr/bin/perl
use FindBin qw($Bin);
use lib "$Bin/../lib";
use lib "$Bin";

use TR::Standard;
use File::Find qw/find/;
# TR::Standard enables strict and warnings which critic doesn't pick up.
use Test::Perl::Critic (-severity => 3, -exclude => ['RequireUseStrict',
                                                     'RequireUseWarnings']);
use Test::More tests => 14;

chdir("$Bin/../lib");

find({ wanted => \&check_syntax, no_chdir => 1}, '.');

# Disabled for now :)
sub check_syntax {
  /Attributes\.pm/ && return;
  /\.pm$/ && do {
    critic_ok($_);
  }
}
