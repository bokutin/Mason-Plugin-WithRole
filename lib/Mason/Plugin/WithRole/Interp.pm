package Mason::Plugin::WithRole::Interp;
use Mason::PluginRole;

use Carp;
use Data::Dumper;
use Mason::Util
  qw(can_load catdir catfile combine_similar_paths find_wanted first_index is_absolute json_decode mason_canon_path read_file taint_is_on touch_file uniq write_file);
use Memoize qw(memoize unmemoize);

has role_extensions => ( is => "ro", default => sub { ['.mr'] } );
has role_regex      => ( is => "ro", lazy_build => 1 );
method is_role_comp_path ($path) {
    return ( $path =~ $self->role_regex ) ? 1 : 0;
}
method _build_role_regex () {
    my $extensions = $self->role_extensions;
    if ( !@$extensions ) {
        return qr/(?!)/;                  # matches nothing
    }
    else {
        my $regex = join( '|', @$extensions ) . '$';
        return qr/$regex/;
    }
}

use Mason::Plugin::WithRole::Extra::Component::Moose::Role;
has component_moose_role_class => ( is => "rw", isa => "Str", default => "Mason::Plugin::WithRole::Extra::Component::Moose::Role" );

BEGIN { unmemoize(\&Mason::Interp::load); }
BEGIN {
    use PadWalker qw(peek_sub);
    use vars qw($max_depth);
    *max_depth = peek_sub(\&Mason::Interp::load)->{'$max_depth'};
}

my $memoized = 0;
sub BUILD {
    unless ( $memoized++ ) {
        memoize('Mason::Interp::load');
    }
}

override load => method ($path) {
    local $Mason::Interp::current_load_interp = $self;

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

    local $Mason::Interp::in_load = $Mason::Interp::in_load + 1;
    if ( $Mason::Interp::in_load > $max_depth ) {
        die ">$max_depth levels deep in inheritance determination (inheritance cycle?)"
          if $$Mason::Interp::in_load >= $max_depth;
    }

    my $compile = 0;
    my (
        $default_parent_path, $source_file, $source_lastmod, $object_file,
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
    $default_parent_path = $self->is_role_comp_path($path) ? "" : $self->_default_parent_path($path);

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
                && $entry->{source_file} eq $source_file
                && $entry->{default_parent_path} eq $default_parent_path )
            {
                my $compc = $entry->{compc};
                if ( $self->is_role_comp_path($path) or $entry->{superclass_signature} eq $self->_superclass_signature($compc) ) {
                    return $compc;
                }
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

    $self->_load_class_from_object_file( $compc, $object_file, $path, $default_parent_path );
    $compc->meta->make_immutable() unless $compc->meta->isa("Moose::Meta::Role");

    # Save component class in the cache.
    #
    $code_cache->set(
        $path,
        {
            source_file          => $source_file,
            source_lastmod       => $source_lastmod,
            default_parent_path  => $default_parent_path,
            compc                => $compc,
            superclass_signature => $compc->meta->isa("Moose::Meta::Role") ? "" : $self->_superclass_signature($compc),
        }
    );

    return $compc;
};

after modify_loaded_class => method ($compc) {
    my $object_file = $compc->cmeta->object_file;
    my $flags = $self->_extract_flags_from_object_file($object_file);
    #warn Dumper $flags;

    my @roles;
    if ( exists( $flags->{with} ) ) {
        my @args = ref($flags->{with}) ? @{$flags->{with}} : ($flags->{with});
        my @roles;
        for my $path (@args) {
            $path = mason_canon_path( join( "/", Mason::Util::mason_canon_path($compc->cmeta->dir_path), $path ) ) if substr( $path, 0, 1 ) ne '/';
            my $role = $self->load($path);
            push @roles, $role;
        }
        Moose::Util::apply_all_roles($compc, @roles, { -excludes => [qw(cmeta)] });
    }
};

override _add_default_wrap_method => method ($compc) {
    unless ( $compc->meta->isa("Moose::Meta::Role") ) {
        super();
    }
};

override _load_class_from_object_file => method ( $compc, $object_file, $path, $default_parent_path ) {
    my $flags = $self->_extract_flags_from_object_file($object_file);

    my $code = do {
        if ( $self->is_role_comp_path($path) ) {
            sprintf( 'package %s; use Moose::Role; do("%s"); die $@ if $@',
                $compc, $object_file );
        }
        else {
            my $parent_compc =
                $self->_determine_parent_compc( $path, $flags )
                || ( $default_parent_path eq '/' && $self->component_class )
                || $self->load($default_parent_path);

            sprintf( 'package %s; use Moose; extends "%s"; do("%s"); die $@ if $@',
                $compc, $parent_compc, $object_file );
        }
    };
    ($code) = ( $code =~ /^(.*)/s ) if taint_is_on();
    eval($code);
    die $@ if $@;

    $compc->_set_class_cmeta($self);
    $self->modify_loaded_class($compc);
};

1;
