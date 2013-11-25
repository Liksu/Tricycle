package Tricycle::DBWrapper;
use DBI;

our $AUTOLOAD;
sub AUTOLOAD {
	my $name = $AUTOLOAD;
	return if $name =~ /^.*::[A-Z]+$/;
	$name =~ s/^.*:://;

	my $sub = sub {
		my $self = shift;  #if $_[0] && $_[0]->can('isa')
		unshift @_, $self->fix(shift) if $name ~~ [qw(do selectrow_hashref selectrow_array selectrow_arrayref selectall_arrayref selectall_hashref selectcol_arrayref prepare)];
#		warn "DB.$name ($self->{dbh})> " . join '; ', @_;
		if ($name ~~ [qw(selectrow_array)]) {
			my @result;
			eval {@result = $self->{dbh}->$name(@_)};
			return @result unless $@;
		} else {
			my $result;
			eval {$result = $self->{dbh}->$name(@_)};
			return $result unless $@;
		}

		my ($package, $filename, $line) = caller;
		warn sprintf('Error: %s at %s line %d.', $@ || $! || $self->{dbh}->errstr, $filename, $line);

		return []
	};

	no strict 'refs';
	*{$AUTOLOAD} = $sub;
	use strict 'refs';
	goto &{$sub};
}

sub fix {
	my $self = shift;
	my $sql = shift;
	$sql =~ s/prefix_/$self->{prefix}/gi;
	return $sql;
}

sub connect {
	my $class = shift;
	my ($data_source, $username, $password, $config) = @_;
	my $self = {
		dbh => DBI->connect($data_source, $username, $password, $config),
		prefix => $config->{tricycle_teble_prefix}
	};
	bless $self, $class;
	return $self;
}

1;
