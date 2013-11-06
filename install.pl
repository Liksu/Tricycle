#!/usr/bin/perl

$config = {
	db => {prefix => 'site_'},
	users => [
		{value => 'guest', title => 'гость', indb => 0, canset => 1},
		{value => 'user', title => 'зарегистрированный пользователь', indb => 1, canset => 1, default => 1},
		{value => 'admin', title => 'администратор', indb => 1, canset => 1},
		{value => 'su', title => 'super user', indb => 1, canset => 0}
	],
	# core\lib\Tricycle\Plugin\Helpers.pm::_check_page_access, line 17
	# all values
	# my %user_levels = map {$_ => $n++} qw(guest user admin su);
	
	# install.sql, table prefix_users, line 226
	# indb values, default
	# `access_level` enum('user','admin','su') NOT NULL DEFAULT 'user'

	# core\templates\admin\tree.html.ep, select_field access_level, line 37
	# canset values, default
	# select_field access_level => [['гость' => 'guest', 'selected'], ['зарегистрированный пользователь' => 'user'], ['администратор' => 'admin']]
};

local $/ = undef;
open($fh, '<', 'install.sql') or die "Cann't open file: $!";
	my $sql = <$fh>;
close $fh;
$sql =~ s/prefix_/$config->{db}->{prefix}/ig;
open($fh, '>', 'ready.sql') or die "Cann't open file: $!";
	print $fh $sql;
close $fh;
