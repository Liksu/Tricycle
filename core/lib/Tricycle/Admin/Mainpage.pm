package Tricycle::Admin::Mainpage;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $c = shift;
	unless ($c->stash('access_granted')) {
		$c->render('admin/forbidden');
		return 0;
	}

	$c->render('admin/main');
}

1;