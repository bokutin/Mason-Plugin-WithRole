package Mason::Plugin::WithRole::Interp;
use Mason::PluginRole;

use Data::Dumper;
use Carp;
use Mason::Util
  qw(can_load catdir catfile combine_similar_paths find_wanted first_index is_absolute json_decode mason_canon_path read_file taint_is_on touch_file uniq write_file);

use Mason::Plugin::WithRole::Extra::Role;

has component_moose_role_class => ( is => "rw", isa => "Str", default => "Mason::Plugin::WithRole::Extra::Role" );

my $max_depth = 16;
{
    no strict 'refs';
    use vars qw($current_load_interp $in_load);
    *current_load_interp = \$Mason::Interp::current_load_interp;
    *in_load             = \$Mason::Interp::in_load;
}

override modify_loaded_class => sub {
    my $self = shift;
    my $compc = shift;

    my $object_file = $compc->cmeta->object_file;
    my $flags = $self->_extract_flags_from_object_file($object_file);
    #warn Dumper $flags;

    my @roles;
    if ( exists( $flags->{with} ) ) {
        my @args = ref($flags->{with}) ? @{$flags->{with}} : ($flags->{with});
        my @roles;
        for my $path (@args) {
            $path = mason_canon_path( join( "/", Mason::Util::mason_canon_path($compc->cmeta->dir_path), $path ) ) if substr( $path, 0, 1 ) ne '/';
            my $role = $self->load_role($path);
            push @roles, $role;
        }
        Moose::Util::apply_all_roles($compc, @roles, { -excludes => [qw(cmeta)] });
    }

    super();
};

override _add_default_wrap_method => method ($compc) {
    return unless $compc->isa("Moose::Object");
    super();
};

method load_role ($path) {

    local $current_load_interp = $self;

    my $code_cache = $self->code_cache;

    # Canonicalize path
    #
    croak "path required" if !defined($path);
    $path = Mason::Util::mason_canon_path($path);

    # Quick check memory cache in static source mode
    #
    if ( $self->static_source ) {
        if ( my $entry = $code_cache->get($path) ) {
            return $entry->{compc};
        }
    }

    local $in_load = $in_load + 1;
    if ( $in_load > $max_depth ) {
        die ">$max_depth levels deep in inheritance determination (inheritance cycle?)"
          if $in_load >= $max_depth;
    }

    my $compile = 0;
    my (
        $source_file, $source_lastmod, $object_file,
        $object_lastmod,      @source_stat, @object_stat
    );

    my $stat_source_file = sub {
        if ( $source_file = $self->_source_file_for_path($path) ) {
            @source_stat = stat $source_file;
            if ( @source_stat && !-f _ ) {
                die "source file '$source_file' exists but it is not a file";
            }
        }
        $source_lastmod = @source_stat ? $source_stat[9] : 0;
    };

    my $stat_object_file = sub {
        $object_file = $self->_object_file_for_path($path);
        @object_stat = stat $object_file;
        if ( @object_stat && !-f _ ) {
            die "object file '$object_file' exists but it is not a file";
        }
        $object_lastmod = @object_stat ? $object_stat[9] : 0;
    };

    # Determine source and object files and their modified times
    #
    $stat_source_file->() or return;


    # Determine default parent comp
    #
    #$default_parent_path = $self->_default_parent_path($path);

    if ( $self->static_source ) {

        if ( $stat_object_file->() ) {

            # If touch file is more recent than object file, we can't trust object file.
            #
            if ( $self->{static_source_touch_lastmod} >= $object_lastmod ) {

                # If source file is more recent, recompile. Otherwise, touch
                # the object file so it will be trusted.
                #
                if ( $source_lastmod > $object_lastmod ) {
                    $compile = 1;
                }
                else {
                    touch_file($object_file);
                }
            }
        }
        else {
            $compile = 1;
        }

    }
    else {

        # Check memory cache
        #
        if ( my $entry = $code_cache->get($path) ) {
            if (   $entry->{source_lastmod} >= $source_lastmod
                && $entry->{source_file} eq $source_file )
            {
                my $compc = $entry->{compc};
                #if ( $entry->{superclass_signature} eq $self->_superclass_signature($compc) ) {
                    return $compc;
                #}
            }
            $code_cache->remove($path);
        }

        # Determine object file and its last modified time
        #
        $stat_object_file->();
        $compile = ( !$object_lastmod || $object_lastmod < $source_lastmod );
    }

    $self->_compile_to_file( $source_file, $path, $object_file ) if $compile;

    my $compc = $self->_comp_class_for_path($path);

    $self->_load_role_class_from_object_file( $compc, $object_file, $path );
    #$compc->meta->make_immutable();

    # Save component class in the cache.
    #
    $code_cache->set(
        $path,
        {
            source_file          => $source_file,
            source_lastmod       => $source_lastmod,
            #default_parent_path  => $default_parent_path,
            compc                => $compc,
            #superclass_signature => $self->_superclass_signature($compc),
        }
    );

    return $compc;
}

method _load_role_class_from_object_file ( $compc, $object_file, $path ) {
    my $flags = $self->_extract_flags_from_object_file($object_file);

    my $code = sprintf( 'package %s; use Moose::Role; do("%s"); die $@ if $@',
        $compc, $object_file );
    ($code) = ( $code =~ /^(.*)/s ) if taint_is_on();
    eval($code);
    die $@ if $@;

    $compc->_set_class_cmeta($self);
    $self->modify_loaded_class($compc);
}

1;
