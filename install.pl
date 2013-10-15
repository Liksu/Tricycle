#!/usr/bin/perl

local $/ = undef;
open($fh, '<', 'install.sql') or die "Cann't open file: $!";
	my $sql = <$fh>;
close $fh;
$sql =~ s/prefix_/$db->{prefix}/ig;
open($fh, '>', 'ready.sql') or die "Cann't open file: $!";
	print $fh $sql;
close $fh;
