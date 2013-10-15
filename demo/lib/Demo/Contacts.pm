package Demo::Contacts;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $self = shift;

	$self->render('contacts');
}

1;