package Tricycle::Plugin::Ajax;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Base 'Mojolicious::Controller';

sub register {
	my ($plugin, $app, $config) = @_;
	$app->routes->bridge->to(cb => sub {
		my $c = shift;
		$c->set_stash_by_referrer();
		return 1;
	})->route('/ajax/:action')->to(namespace => 'Tricycle::Plugin', controller => 'ajax', action => 'status');
};

sub status {
	my $c = shift;
	$c->render(json => {status => 'ok'});
}

sub valid_uri {
	my $c = shift;
	my $json = {status => 'ok', passed => Mojo::JSON->true, error => undef};

	unless ($c->param('value') =~ m|^([a-z0-9\-\_\.]+)$|i) {
		$json->{passed} = Mojo::JSON->false;
		$json->{error} = 'Bad symbols. Allowed only a-z, 0-9, _, - and .';
	} else {unless ($c->param('value') eq ($c->param('initial_value') || '')) {
		my $found_id = ($c->db->selectrow_array(q|select category_id from prefix_category where COALESCE(parent_id,0) = ? and uri_name = ?|, {}, $c->param('parent_id') || 0, $c->param('value')));
		if ($found_id) {
			$json->{passed} = Mojo::JSON->false;
			$json->{error} = 'Uri already exists';
			$json->{id} = $found_id;
		}
    }}

	$c->render(json => $json);
}

sub get_main_menu {
	my $c = shift;
	$c->render(text => $c->menu('main'), layout=>undef);
}

sub get_photos_list {
	my $c = shift;

	my $photos = $c->db->selectall_arrayref(q|SELECT concat(?, filename) as thumb, concat(?, filename) as image, left(description, 25) as title, tricycle_get_uri_by_id(category_id) as folder FROM prefix_photos ORDER BY if(category_id = ?, -1, folder)|, {Slice=>{}}, $c->thumb(), $c->config('images') . '/', $c->stash('category_id'));
	$c->render(json => $photos);
}

1;