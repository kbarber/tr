package TR::Context::HTML;
use TR::Standard;
use TR::Pod;    # TODO For get_path_to_module :(
use TR::Exceptions;

use vars qw($VERSION);
use version; $VERSION = qv('1.1');

=head1 NAME

    TR::Context::HTML - Handles HTML requests/responses for TR.

=head1 VERSION

    See $VERSION

=head1 SYNOPSIS

    Used from within TR:

    use Module::Pluggable search_path => 'TR::Context',
                          inner       => 0,
                          sub_name    => 'context_handlers',
                          instantiate => 'new';

    foreach my $context ($self->context_handlers()) {
        next unless $context->can('handles');
        if ($context->handles(request => $request)) {
            $self->context($context);
            $context->init();
        }
    }

    my $method = $context->method;
    my $params = $context->params;

=head1 DESCRIPTION 

    Handles requests of type 'Text/HTML' and returns
    a response viewable in a browser.

    Not designed as a interface for applications to use,
    designed to provide and interface for humans to see 
    documentation, schemas, and to test/see reponses to
    available methods.

=head1 CONFIGURATION AND ENVIRONMENT

    See <TR>

=head1 DEPENDENCIES

=head1 INCOMPATIBILITIES

=head1 AUTHOR

=head1 DIAGNOSTICS

=head1 BUGS AND LIMITATIONS

  Probably a few.

=head1 SUBROUTINES/METHODS

=cut

use Template;
use JSON::XS 2.2;

use base 'TR::Context';
__PACKAGE__->mk_accessors(qw/_params/);

=head2 new

    Creates new TR::Context::HTML object to handle html requests

=cut

sub new {
    my $proto = shift;
    my ($class) = ref $proto || $proto;

    my $self = bless { supported => ['Text/HTML'], }, $class;

    return $self;
}

=head2 method 

    Grab the method from an html request

=cut

sub method {
    my $self = shift;

    if ( my $method = $self->request->param('method') ) {
        return $method;
    }

    return;
}

=head2 set_params

    Sets a param

=cut

sub set_params {
    my ( $self, %new_params ) = @_;

    $self->_params( \%new_params );

    return;
}

=head2 params

    Grabs params from request

=cut

sub params {
    my $self = shift;

    if ( not $self->_params ) {
        my %params = $self->request->params();

        delete $params{'method'};   # remove method as it's not needed/wanted.
        $self->_params( \%params );
    }

    return $self->_params;
}

=head2 view

    Displays view

=cut

sub view {
    my $self = shift;

    print "Content-type: text/html\n\n";

    my $pod  = new TR::Pod;
    my $path = $pod->get_path_to_module( ref $self );

    if ( my $result = $self->result ) {
        $result->{'location'} = $self->request->location();
        if ( ref($result) eq 'HASH' && $result->{'error'} ) {
            my $tt = Template->new( INCLUDE_PATH => $path );
            $tt->process( 'html_error.tmpl', $result )
                || E::Fatal->throw(
                'Unable to load Template: ' . $tt->error() );
        }
        else {
            if ( $result->{'doc'} ) {
                my $tt = Template->new( INCLUDE_PATH => $path );
                $tt->process( 'html_doc.tmpl', $result )
                    || E::Fatal->throw(
                    'Unable to load Template: ' . $tt->error() );
            }
            else {
                delete $result->{'location'};
                print "<html><body><pre>";
                # Disable perl critic complaining about JSON::XS's way of
                # setting options.
                ## no critic (ProhibitLongChainsOfMethodCalls)
                print JSON::XS->new->utf8->pretty(1)->allow_nonref->encode($result);
                print "</pre></body></html>";
            }
        }
    }
    else {
        print "<html><head>\n";
        print "<title>TR</title>\n";
        print "</head>\n";
        print "<body>";

        print "<p>No data to display</p>";

        print "</body>";
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

