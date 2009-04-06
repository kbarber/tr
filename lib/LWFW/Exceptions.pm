#!/usr/bin/perl
use strict;
use warnings;

use Exception::Class (
      'E', # 'E' is euick to type and shouldn't have any name space clashes.
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

      'E::Invalid::EmptyResults' => {
        isa         => 'E::Invalid',
        description => 'Empty results',
      },

      'E::Service' => {
        isa         => 'E',
        description => 'Problem with talking to a remote service',
      },
      'E::Service::LDAP' => {
        isa         => 'E::Service',
        description => 'Problem with LDAP',
      },

);


1;
