package TR::ModPerl2;
use TR::Standard;

use vars qw($VERSION);
use version; $VERSION = qv('1.1');

use Apache2::RequestRec;
use Apache2::RequestIO;
use Apache2::RequestUtil;
use Apache2::Request;
use Apache2::Const -compile => qw(OK);
use TR;
=head1 NAME

  TR::ModPerl2 - mod_perl handler for TR.

=head1 VERSION

  See $VERSION

=head1 LICENSE AND COPYRIGHT

  GNU GENERAL PUBLIC LICENSE
	Version 3, 29 June 2007

  Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

=head1 SYNOPSIS

  # Mod perl setup
  PerlSwitches -I/opt/tr/engine/lib -I/opt/tr/app
  PerlSetVar config /etc/tr/registry.conf 

  <Location /t>
    SetHandler perl-script
    PerlResponseHandler TR::ModPerl2
    PerlOptions +ParseHeaders
  </Location>

=head1 DESCRIPTION 

  The mod_perl handler for <TR>

=head1 CONFIGURATION AND ENVIRONMENT

  # Mod perl setup
  PerlSwitches -I/opt/tr/engine/lib -I/opt/tr/app
  PerlSetVar config /etc/tr/registry.conf 

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

=head1 SUBROUTINES/METHODS


=head2 handler

    Creates the TR object and hands off control.

=cut

sub handler {
    my $r = shift;

    my $request = new Apache2::Request($r);

    my $tr = new TR(
        request => $request,
        config  => $r->dir_config('config')
    );
    $tr->handler();

    return Apache2::Const::OK;
}

1;
