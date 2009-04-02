package LWFW::Attributes;
use strict;
use warnings;
use Attribute::Handlers;

use base 'Class::Accessor::Fast';

sub UNIVERSAL::Local : ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data) = @_;
  push @{$LWFW::attribute_cache{$package}{$referent}}, $attr;
}

sub UNIVERSAL::Regex : ATTR(CODE, BEGIN) {
  my ($package, $symbol, $referent, $attr, $data) = @_;
  push @{$LWFW::attribute_cache{$package}{$referent}}, $attr;
}

sub UNIVERSAL::Params : ATTR(CODE) {
  print "Stuff...\n"; 
}

=head2 _get_handler_paths

  Returns list of handlers registered with attributes

=cut
sub _get_handler_paths {
  my %handlers = ();

  foreach my $package  (keys %LWFW::attribute_cache) {
    foreach my $code_ref (keys %{$LWFW::attribute_cache{$package}}) {
      my $method_name = _get_name_by_code_ref($package, $code_ref);

      # generate a path from package/method
      my $path = lc($package);
      $path =~ s#::#/#g;
      $path =~ s#^[^/]+##; # Remove base package name

      # Store package and method details
      $handlers{$path}{'package'} = $package;
      push @{$handlers{$path}{'methods'}}, $method_name;
    }
  }

  return \%handlers;
}

=head2 _get_name_by_code_ref

  Resolves a code ref to sub name

=cut
sub _get_name_by_code_ref {
  my ($package, $code_ref) = @_;

  my %symbol_table;
  eval('%symbol_table = %' . $package . '::'); 
  foreach my $entry (keys %symbol_table) {
    my $symbol = $symbol_table{$entry};
    if (*{$symbol}{'CODE'}) {
      if(*{$symbol}{'CODE'} eq $code_ref) {
        return *{$symbol}{'NAME'};
      }
    }
  }
}

1;
