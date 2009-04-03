#!/usr/bin/perl
use strict;
use warnings;

use Exception::Class (
      'E', # Quick to type and shouldn't have any name space clashes.
      'E::Fatal' => {
        isa         => 'E',
        description => 'Time to give up and go home',
      },
      
      'E::Invalid' => {
        isa         => 'E',
        description => 'Something was done wrong',
      },
      'E::Invalid::Params' => {
        isa         => 'E::Invalid',
        description => 'Method was passed wrong params',
      },
      'E::Invalid::Method' => {
        isa         => 'E::Invalid',
        description => 'Method is unsupported',
      },

      'E::Invalid::ContentType' => {
        isa         => 'E::Invalid',
        description => 'Unhandled content-type',
      },
);


1;
