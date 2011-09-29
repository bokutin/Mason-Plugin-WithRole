<%class>
method Greedy () {
    sub {
	for ($_[0]) {
	    s/\s*\R\s*//g;
	}
	$_[0]; 
    };
}

use B::Hooks::EndOfScope;

method no_main () {
    on_scope_end {
        $self->meta->remove_method("main");
    };
}
</%class>
