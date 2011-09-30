package Mason::Plugin::WithRole::CodeCache;
use Mason::PluginRole;

use Devel::GlobalDestruction;

override remove => method ($key) {
    if ( my $entry = $self->{datastore}->{$key} ) {
        if ( !in_global_destruction() ) {
            my $compc = $entry->{compc};
            $compc->_unset_class_cmeta();
            $compc->meta->make_mutable() unless $compc->meta->isa("Moose::Meta::Role");
            Mason::Util::delete_package($compc);
        }
        delete $self->{datastore}->{$key};
    }
};

1;
