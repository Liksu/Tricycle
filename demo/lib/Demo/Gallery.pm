package Demo::Gallery;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $c = shift;
	my $category_id = shift;
	my $partial = shift || !!$category_id || 0;
	$category_id ||= $c->stash('category_id');

	my $title = $c->stash('category_title');
	my $gallery_url = $c->stash('old_url');
	if ($partial) {
		($title, $gallery_url) = $c->db->selectrow_array('select title, tricycle_get_uri_by_id(category_id) from prefix_category where category_id = ?', {}, $category_id);
	}

	my $photos = $c->db->selectall_arrayref(q|SELECT photo_id, filename, description, if(pride is null, 0, 1) as pride FROM prefix_photos WHERE category_id = ? ORDER BY filename|, {Slice=>{}}, $category_id);
	$c->stash(photos => $photos);

	$c->render('gallery' . ($c->check_page_access('admin') ? '_admin' : ''), partial => $partial, title => $title, cid => $category_id, gallery_url => $gallery_url);
}

sub post { # create
	my $c = shift;
	my $json = {status => 'error', message => 'Something strange during upload'};
	$c->render(json => $json) unless $c->check_page_access('admin');

	my @photos = $c->uploader({type => 'photos', param => 'files', destination => $c->config('images'), category_id => undef});

	$json = {status => 'ok', 'files' => \@photos};
	$c->render(json => $json);
}

#TODO: change photo_id to filename
sub put { # update
	my $c = shift;

	my ($photo_id) = $c->uri_params();
	my $rows;

	if ($c->param('description')) {
		$rows = $c->db->do(qq|UPDATE prefix_photos SET description = ? WHERE photo_id = ?|, undef, $c->param('description'), $photo_id);
		$c->log('Change photo [%d] description to: %s', $photo_id, $c->param('description'));
	}
	if (defined $c->param('pride')) {
		$rows = $c->db->do(qq|UPDATE prefix_photos SET pride = if(?,'',null) WHERE photo_id = ?|, undef, !!$c->param('pride'), $photo_id);
		$c->log('Set photos [%d] flag into «%s»', $photo_id, !!$c->param('pride') ? 'yes' : 'no');
	}

	$c->render(json => {status => $c->dbh->errstr ? 'error' : 'ok', message => $c->dbh->errstr});
}

sub delete {
	my $c = shift;

	my ($photo_id) = $c->uri_params();
	my $result = $c->uploader_delete({file_id => $photo_id, type => 'photos'});
	$c->delete_thumbnails($result->{folder}, $result->{file});

	$c->render(json => {status => $result->{error} ? 'error' : 'ok', message => $result->{error}, reload => 1});
}

use Mojo::Base 'Mojolicious::Plugin';
sub register {
	my ($plugin, $app, $config) = @_;
	$app->helper(gallery => sub {
		my $c = shift;
		my $category_id = shift;
		return get($c, $category_id);
	});
}

1;