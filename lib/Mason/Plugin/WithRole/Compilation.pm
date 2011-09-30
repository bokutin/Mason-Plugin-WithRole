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

    my $flags = $self->$orig;
    push @$flags, "with";

    $flags;
};

override _output_class_initialization => method {
    my $ret = super();

    $ret =~
         s{
            \$_interp->component_moose_class->import;
         }{
            \$_interp->component_moose_class->import if __PACKAGE__->isa('Moose::Object');
            \$_interp->component_moose_role_class->import unless __PACKAGE__->isa('Moose::Object');
         }msx or die;

    $ret;
};

1;
