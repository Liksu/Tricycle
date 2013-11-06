package Demo::Products;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $self = shift;

	my $sublinks = $self->db->selectall_arrayref(q|select * from prefix_category where parent_id = ? and visible = '' and enabled = '' and pagetype = 'gallery' order by IF(sort_order > 0, sort_order , IF(sort_order is NULL , 128, 256 - sort_order))|, {Slice => {}}, $self->stash('category_id'));

	$self->stash(sublinks => $sublinks);

	$self->render('products');
}

1;