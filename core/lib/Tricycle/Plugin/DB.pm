package Tricycle::Plugin::DB;
use Mojo::Base 'Mojolicious::Plugin';
use Tricycle::DBWrapper;

has dbh => undef;

sub register {
	my ($plugin, $app, $config) = @_;

	$app->helper(db => sub {
		return $plugin->db(@_);
	});
	$app->helper(dbh => sub{$plugin->{dbh}});

	$plugin->check($app);
}

sub check {
	my $plugin = shift;
	my $app = shift;

	unless ($plugin->{dbh} && $plugin->{dbh}->ping) {
		$plugin->{dbh} = Tricycle::DBWrapper->connect('dbi:mysql:'.$app->{config}{db}{name}, $app->{config}{db}{user}, $app->{config}{db}{password}, {'AutoCommit' => 1, 'RaiseError' => 1, 'PrintError' =>1, 'mysql_enable_utf8' => 1, 'tricycle_teble_prefix' => $app->{config}{db}{prefix}});
		$plugin->{dbh}->do('SET NAMES UTF8');
	}
}

sub db {
	my ($plugin, $c, $method) = (shift, shift, shift);
	$method ||= '';
	$plugin->{controller} = $c;

#	$c->app->log->debug('DB: called ' . ($method ? "with $method" : 'withought method') . ($c->req->url ? ' for ' . $c->req->url : ''));
#	warn $c->dumper($plugin->{'query'}());
	if ($method eq 'ping' || $method eq 'check') {
		$method = undef;
		$plugin->check($c->app);
	}

	return $method ? $plugin->$method(@_) : $plugin->{dbh};
}


1;
