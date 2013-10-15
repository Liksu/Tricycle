package Demo::Article;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $self = shift;

	$self->render('article');
}

1;