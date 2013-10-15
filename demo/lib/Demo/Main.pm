package Demo::Main;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $self = shift;

	$self->stash(pride => $self->db('get_pride'));

	$self->render('main');
}

1;