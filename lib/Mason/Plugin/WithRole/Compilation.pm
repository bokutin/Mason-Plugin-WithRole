package Mason::Plugin::WithRole::Compilation;
use Mason::PluginRole;

method BUILD () {
    if ( $self->interp->is_role_comp_path($self->path) ) {
        delete $self->{methods}{main};
    }
}

around valid_flags => sub {
    my $orig = shift;
    my $self = shift;

    my $flags = $self->$orig(@_);
    push @$flags, "with";

    $flags;
};

around _output_class_initialization => sub {
    my $orig = shift;
    my $self = shift;

    my $ret = $self->$orig(@_);

    if ( $self->interp->is_role_comp_path($self->path) ) {
        $ret =~
            s{
                \$_interp->component_moose_class->import;
            }{
                \$_interp->component_moose_role_class->import;
                sub cmeta () { \$_[0]->can('_class_cmeta') ? \$_[0]->_class_cmeta : undef }
            }msx or die;
    }

    $ret;
};

1;
