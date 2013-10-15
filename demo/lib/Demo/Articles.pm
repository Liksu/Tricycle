package Demo::Articles;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $self = shift;

	my $sublinks = $self->db->selectall_arrayref(q|select * from prefix_category where parent_id = ? and visible = '' and enabled = ''|, {Slice => {}}, $self->stash('category_id'));
	$self->stash(sublinks => $sublinks);

	$self->render('articles');
}

1;