package TR::ModPerl2;
use TR::Standard; 
  
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Request (); 
use Apache2::Const -compile => qw(OK);
use TR;

=head2 handler

    <Location />
	      SetHandler perl-script
    		PerlResponseHandler TR::ModPerl2
    		PerlOptions +ParseHeaders
    		Order allow,deny
     		Allow from 127.0.0.1
    </Location>

=cut
sub handler {
  my $r = shift;

  my $request = new Apache2::Request($r);

  my $tr = new TR(request => $request,
                  config => '/home/knoxc/Projects/TR.perl/config/registry.conf');
  $tr->handler();

  return Apache2::Const::OK;
}

1;
