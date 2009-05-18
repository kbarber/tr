#!/usr/bin/perl
use strict;
use warnings;

use Exception::Class (
      'E' => {
        fields      => [ 'err_code' ],
      }, # 'E' is quick to type and shouldn't have any name space clashes.
      'E::Fatal' => {
        isa         => 'E',
        description => 'Time to give up and go home',
      },
      'E::Invalid' => {
        isa         => 'E',
        description => 'Something was done wrong',
      },
      'E::Invalid::Config' => {
        isa         => 'E::Invalid',
        description => 'Something is wrong with the configuration',
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

      'E::Invalid::EmptyResults' => {
        isa         => 'E::Invalid',
        description => 'Empty results',
      },

      'E::Service' => {
        isa         => 'E',
        description => 'Problem with talking to a remote service',
      },

      'E::Redirect' => {
        isa         => 'E',
        description => 'Handled by another controller.',
        fields      => [ 'newpath', 'method' ],
      },
);


1;
