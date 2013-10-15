package Demo::Products;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $self = shift;

	my $sublinks = $self->db->selectall_arrayref(q|select * from prefix_category where parent_id = ? and visible = '' and enabled = '' and pagetype = 'gallery'|, {Slice => {}}, $self->stash('category_id'));

	$self->stash(sublinks => $sublinks);

	$self->render('products');
}

1;