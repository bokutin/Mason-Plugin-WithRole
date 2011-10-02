use strict;
use feature ":5.10";
use Test::More;

use lib "lib";

use File::Path qw(remove_tree);
use FindBin;
remove_tree("$FindBin::Bin/data");

use Mason;
my $interp = Mason->new(
    comp_root => "t/comp",
    data_dir  => "t/data",
    plugins => [
        "WithRole",
    ],
);

is( $interp->run("/hello")->output, "hello world.\n");
is( $interp->run("/hello_with_role")->output, uc "hello world.\n");

is( $interp->run("/01-hello/hello")->output, "hello world.\n");
is( $interp->run("/01-hello/hello_with_role")->output, uc "hello world.\n");

is( $interp->run("/02-wrap/html/index")->output, <<'');
<html>
    <head>
        <title>default title</title>
    </head>
    <body>
        <div id="header">default header content</div>
        <div id="main">html content</div>
        <div id="footer">default footer content</div>
    </body>
</html>

is( $interp->run("/02-wrap/text/index")->output, <<'');
[title]
default title
[header]
default header content
[content]
text content
[footer]
default footer content

is( $interp->run("/02-wrap/html/crud/edit")->output, <<'');
<html>
    <head>
        <title>edit mode title</title>
    </head>
    <body>
        <div id="header">default header content</div>
        <div id="main">edit mode content</div>
        <div id="footer">default footer content</div>
    </body>
</html>

is( $interp->run("/02-wrap/html/crud/list")->output, <<'');
<html>
    <head>
        <title>list mode title</title>
    </head>
    <body>
        <div id="header">default header content</div>
        <div id="main">list mode content</div>
        <div id="footer">default footer content</div>
    </body>
</html>

is( $interp->run("/02-wrap/text/crud/edit")->output, <<'');
[title]
edit mode title
[header]
default header content
[content]
edit mode content
[footer]
default footer content

is( $interp->run("/02-wrap/text/crud/list")->output, <<'');
[title]
list mode title
[header]
default header content
[content]
list mode content
[footer]
default footer content

is( $interp->run("/03-no_main/html/index")->output, <<'');
<html>
    <head>
        <title>default title</title>
    </head>
    <body>
        <div id="header">default header content</div>
        <div id="main">html content</div>
        <div id="footer">default footer content</div>
    </body>
</html>

is( $interp->run("/03-no_main/text/index")->output, <<'');
[title]
default title
[header]
default header content
[content]
text content
[footer]
default footer content

is( $interp->run("/03-no_main/html/crud/edit")->output, <<'');
<html>
    <head>
        <title>edit mode title</title>
    </head>
    <body>
        <div id="header">default header content</div>
        <div id="main">edit mode content</div>
        <div id="footer">default footer content</div>
    </body>
</html>

is( $interp->run("/03-no_main/html/crud/list")->output, <<'');
<html>
    <head>
        <title>list mode title</title>
    </head>
    <body>
        <div id="header">default header content</div>
        <div id="main">list mode content</div>
        <div id="footer">default footer content</div>
    </body>
</html>

is( $interp->run("/03-no_main/text/crud/edit")->output, <<'');
[title]
edit mode title
[header]
default header content
[content]
edit mode content
[footer]
default footer content

is( $interp->run("/03-no_main/text/crud/list")->output, <<'');
[title]
list mode title
[header]
default header content
[content]
list mode content
[footer]
default footer content

is( $interp->run("/04-with_at_class/dot")->output, ".");
is( $interp->run("/04-with_at_class/dot1")->output, ">.<");
is( $interp->run("/04-with_at_class/dot2")->output, ">.<");
is( $interp->run("/04-with_at_class/dot3")->output, "(>.<)");

done_testing();
