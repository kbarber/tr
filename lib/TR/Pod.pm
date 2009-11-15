package TR::Pod;
use TR::Standard;
use TR::Exceptions;
use English qw(-no_match_vars);

use PPI;
use Cache::FastMmap;
use Cwd qw/realpath/;

use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

  TR::Pod - Fetches schemas and documentation from modules.
            
=head1 VERSION

  See $VERSION

=head1 SYNOPSIS

=head1 DESCRIPTION 

    Finds and caches schema information from a module's Pod, also finds 
    and returns documentation from a module's pod.

    Is a singleton.

=head1 CONFIGURATION AND ENVIRONMENT

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

  Probably a few.

=head1 SUBROUTINES/METHODS

=cut

use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw/schema_cache rschema_cache/);

my $SINGLETON;

=head2 new

  Init pod module

=cut

sub new {
    return $SINGLETON if $SINGLETON;

    my $proto = shift;
    my ($class) = ref $proto || $proto;

    my $self = bless {}, $class;

    my $schema_cache = new Cache::FastMmap(
        share_file      => '/var/cache/tr/TR_schema.cache.' . $UID,
        cache_not_found => 1,
        page_size => '4k',     # Most schemas are smaller than 1k
        num_pages => '157',    # Max pages, should be prime.
        context   => $self,
        read_cb   => sub { $_[0]->_get_schema( $_[1] ) }, # Fetch schema on cache miss
    );
    my $rschema_cache = new Cache::FastMmap(
        share_file      => '/var/cache/tr/TR_rschema.cache.' . $UID,
        cache_not_found => 1,
        page_size => '4k',     # Most schemas are smaller than 1k
        num_pages => '157',    # Max pages, should be prime.
        context   => $self,
        read_cb => sub { $_[0]->_get_result_schema( $_[1] ) }, # Fetch schema on cache miss
    );

    $self->schema_cache($schema_cache);
    $self->rschema_cache($rschema_cache);

    $SINGLETON = $self;

    return $self;
}

=head2 _fetch 

  Returns PPI::Document object for a module if it's already been loaded, 
  else loads up a PPI::Document object for the module.

=cut

sub _fetch {
    my ( $self, %args ) = @_;

    my $module = $args{'module_file'}
        or E::Fatal->throw('Need to pass module_file');

    my $document = PPI::Document->new($module) or E::Fatal->throw( $ERRNO );

    return $document;
}

=head2 get_documentation
 
  Grabs pod documentation for a given package/method.
  Need to standardise on format so that it can be passed back
  to a caller,
  and that caller be able to present it any way it wants.

  ie maybe pod like this:

  head2 asub

    Description:
      blah

    Example:
      blah

  cut

  Could be returned as:

  {
    method      => asub,
    params      => [a, b, c,],  # (From params attribute)
    description => 'blah',
    example     => 'blah',
  }

=cut

sub get_documentation {
    my ( $self, %args ) = @_;

    if ( not defined $args{'package'} or
         not defined $args{'method'} ) {
        return;
    }

    my $module_dir = $self->get_path_to_module( $args{'package'} );

    if ( $args{'package'} =~ /([^:]+)$/sx ) {
        my $document = $self->_fetch( module_file => $module_dir . $1 . '.pm' );

        if (my $results = $document->find(
                sub {
                    $_[1]->isa('PPI::Token::Pod')
                        and ( $_[1]->content =~ /=head2\ $args{'method'}/mx );
                }
            )) {
            my $content = @{$results}[0]->content();
            $content =~ s/=head2\ $args{'method'}//xm;
            $content =~ s/=cut//xm;
            return $content;
        }
    }

    return;
}

=head2 _get_from_pod
  
  Looks for through pod for given "match" for method.
  TODO: lots of overlap with get_documentation need to refactor

=cut

sub _get_from_pod {
    my ( $self, %args ) = @_;

    if ( not defined $args{'package'} or
         not defined $args{'method'}  or
         not defined $args{'match'} ) {
        return;
    }

    my $module_dir = $self->get_path_to_module( $args{'package'} );

    if ( $args{'package'} =~ /([^:]+)$/sx ) {
        my $document
            = $self->_fetch( module_file => $module_dir . $1 . '.pm' );

        if (my $results = $document->find(
                sub {
                    $_[1]->isa('PPI::Statement::Sub')
                        and ( $_[1]->content =~ /sub\ $args{'method'}/x );
                }
            )) {
            my $method = @{$results}[0];
            if (my $children = $method->find(
                    sub {
                        $_[1]->isa('PPI::Token::Pod')
                            and ( $_[1]->content =~ /$args{'match'}/x );
                    }
                )) {
                my ($schema) = @{$children}[0]->content() =~ /$args{'match'}(.+)=cut/mxs;
                return $schema;
            }
        }
    }

    return;
}

=head2 get_schema
 
  Grab the schema for a method from cache

=cut

sub get_schema {
    my ( $self, %args ) = @_;

    if ( not defined $args{'package'} or
         not defined $args{'method'} ) {
        return;
    }

    return $self->schema_cache->get( join( q{:}, $args{'package'}, $args{'method'} ) );
}

=head2 _get_schema 

  Call on cache miss to fetch schema from perl module.

=cut

sub _get_schema {
    my ( $self, $key ) = @_;

    if ( $key =~ /^(.*):([^:]+$)/x ) {
        return $self->_get_from_pod(
            package => $1,
            method  => $2,
            match   => '=begin\ schema'
        );
    }

    return;
}

=head2 get_result_schema
 
  Grab the result schema for a method.

=cut

sub get_result_schema {
    my ( $self, %args ) = @_;

    if ( not defined $args{'package'} or
         not defined $args{'method'} ) {
        return;
    }

    return $self->rschema_cache->get( join( q{:}, $args{'package'}, $args{'method'} ) );
}

=head2 _get_result_schema 

  Call on cache miss to fetch result schema from perl module.

=cut

sub _get_result_schema {
    my ( $self, $key ) = @_;

    if ( $key =~ /^(.*):([^:]+$)/sx ) {
        return $self->_get_from_pod(
            package => $1,
            method  => $2,
            match   => '=begin\ result_schema'
        );
    }

    return;
}

=head2 get_path_to_module

  Grab the path to a module and return it's realpath (.. ie get rid 
                                                      of /../../ etc)/.

=cut

sub get_path_to_module {
    my $self = shift;
    my $module = shift || ref($self) || $self;

    $module =~ s#::#/#xg;
    $module .= '.pm';

    if ( defined $INC{$module} ) {
        my $path = realpath( $INC{$module} );
        $path =~ s/[^\/]+\.pm//mx;
        return $path;
    }
    else {
        warn "Couldn't find path for $module\n";
    }

    return;
}

=head1 LICENSE AND COPYRIGHT

  Copyright (C) 2009 Alfresco Software Ltd <http://www.alfresco.com>

  This file is part of TR.
    
  TR is free software: you can redistribute it and/or modify
  it under the terms of the GNU Affero General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
    
  TR is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU Affero General Public License
  along with TR.  If not, see <http://www.gnu.org/licenses/>.

=cut

1;
