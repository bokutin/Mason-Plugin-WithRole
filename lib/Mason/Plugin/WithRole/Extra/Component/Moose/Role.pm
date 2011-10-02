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
    Moose::Role->init_meta(@_);
    {
        no strict 'refs';
        *{ $for_class . '::CLASS' } = sub () { $for_class };    # like CLASS.pm
    }
}

1;
