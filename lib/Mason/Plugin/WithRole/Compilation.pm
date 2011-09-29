package Mason::Plugin::WithRole::Compilation;
use Mason::PluginRole;

method BUILD () {
    if ( $self->path =~ m/\.mr$/ ) {
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

method _output_class_initialization () {
    return join(
        "\n",
        "our (\$_class_cmeta, \$m, \$_m_buffer, \$_interp);",
        "BEGIN { ",
        "local \$_interp = Mason::Interp->current_load_interp;",
        #"\$_interp->component_moose_class->import;",
        "\$_interp->component_moose_class->import if __PACKAGE__->isa('Moose::Object');",
        "\$_interp->component_moose_role_class->import unless __PACKAGE__->isa('Moose::Object');",
        "\$_interp->component_import_class->import;",
        "}",
        "*m = \\\$Mason::Request::current_request;",
        "*_m_buffer = \\\$Mason::Request::current_buffer;",

        # Must be defined here since inner relies on caller()
        "sub _inner { inner() }"
    );
}

1;
