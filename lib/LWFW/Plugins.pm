package LWFW::Plugins;
use strict;
use warnings;
use Cwd qw/realpath/;
use base 'Class::Accessor::Fast';

our @plugin_dirs = qw/C M V/;

=head2 _load_plugins

  Look for certain directories (C M V) under the current 
  package ref($self) and load any modules found there automatically.

=cut
sub _load_plugins {
  my $self = shift;

  my $module = shift || ref($self);

  my $module_dir = $self->_get_path_to_module();
  $module_dir =~ s/[^\/]+\.pm//;

#  print "Base: $module_dir: Module: $module\n"; 
}

sub _get_path_to_module {
  my $self   = shift;
  my $module = shift || ref($self);

  $module =~ s#::#/#g;
  $module .= '.pm';

  return realpath($INC{$module});
}

1;
