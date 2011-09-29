<%augment wrap>\
<html>
    <head>
        <title><% $.head_title %></title>
    </head>
    <body>
        <div id="header"><% $.header_content %></div>
        <div id="main"><% inner() %></div>
        <div id="footer"><% $.footer_content %></div>
    </body>
</html>
</%augment>
