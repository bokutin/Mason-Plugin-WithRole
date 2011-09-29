use inc::Module::Install;

name 'Mason-Plugin-WithRole';
all_from 'lib/Mason/Plugin/WithRole.pm';

requires 'Mason' => "2.14";

auto_install;
auto_set_repository;
githubmeta;

WriteAll;
