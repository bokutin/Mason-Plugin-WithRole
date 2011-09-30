package Mason::Plugin::WithRole::Extra::Component::Moose::Role;

use Moose::Role                ();
use Method::Signatures::Simple ();
use Moose::Exporter;
Moose::Exporter->setup_import_methods( also => ['Moose::Role'] );

sub init_meta {
    my $class     = shift;
    my %params    = @_;
    my $for_class = $params{for_class};
    Method::Signatures::Simple->import( into => $for_class );
    #Moose->init_meta(@_);
    Moose::Role->init_meta(@_);
    {
        no strict 'refs';
        *{ $for_class . '::CLASS' } = sub () { $for_class };    # like CLASS.pm
        *{ $for_class . '::cmeta' } = sub () { my $self = shift; $self->can('_class_cmeta') ? $self->_class_cmeta : undef; };
        #*{ $for_class . '::m' } = \$Mason::Request::current_request;
    }
}

1;
