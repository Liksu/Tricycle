package Tricycle::Plugin::EditableText;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Base 'Mojolicious::Controller';

use File::Basename 'dirname';
use File::Spec::Functions 'catdir';

#TODO: save text vs PUT and INSERT OR UPDATE
sub register {
	my ($plugin, $app, $config) = @_;

	# Append "templates" and "public" directories
	my $base = catdir(dirname(__FILE__), 'EditableText');
	push @{$app->renderer->paths}, catdir($base, 'templates');
	push @{$app->static->paths},   catdir($base, 'public');

	# self routing
	my $route = $app->routes->bridge('/plugins/editable_text')->to(cb => sub {
		my $c = shift;
		$c->set_stash_by_referrer();
		return 1;
	})->route->to(namespace => 'Tricycle::Plugin', controller => 'EditableText', action => 'list');

	$route->route->via('POST')->to(action => 'create');
#	$route->route->via('GET')->to(action => 'list');
	$route->route('/upload_(:type)')->via('POST')->to(action => 'upload');

	$route = $route->route('/:text_id');
	$route->via('PUT')->to(action => 'update');
#	$route->via('GET')->to(action => 'get_text');
#	$route->via('DELETE')->to(action => 'delete');

	# create helper for internal use
	$app->helper( 'editable_text' => \&_get_editable );
}

# <%= editable_text %> get all texts for stash('category_id') and create editable texts and set text_id for each of them, if there is no text - creates an open editor with actual category_id
# <%= editable_text url => $url, text => $text %> same as previous, but edited text will be sent for specified $url.
# <%= editable_text $id %> get text by text_id == $id; $id == ^\d+$; if there is no this $id in DB - do nothing
#TODO: different editor calls:
# <%= editable_text $url %> get all texts for category fetched from $url, and create editors and set text_id for each of them, if there is no text for this $id - creates an open editor, and set category_id into it
# <%= editable_text category_id => $id %> equal to <%= editable_text $url %>
# <%= editable_text category_id => $id, text => $text %> create editor for this text, and save to specified category or stash('category_id') unless $id given.
# <%= editable_text category_url => $url, text => $text %> same as previous, but with $url instead $id.
# <%= editable_text text => $text, cb => 'name' %> create editor for this text, and onSave call javascript cb

sub _get_editable {
	my $c = shift;
	my %options = @_;
	my $texts = []; # [{ text_id, category_id, text }]
	my ($param) = keys %options unless $#_;

	if (defined $options{url} && defined $options{text}) {
		$texts = [{text => $options{text}, text_id => undef, category_id => undef, specified_url => $options{url}, launched => !!$options{text}}]
	} elsif ($param && $param =~ /^\d+$/) {
		$texts = $c->db('get_texts', $param, 'id')->{result};
	} else {
		# get text, text_id, category_id; set launched
		$texts = $c->db('get_texts', $c->stash('category_id'));
		unless ($texts->{count}) {
			$texts = [{text => $c->config('no_text_phrase') || '', text_id => undef, category_id => $c->stash('category_id'), launched => 1}]
		} else {
			$texts = $texts->{result};
			foreach my $text (@$texts) {
				$text->{text} = _links_to_uri( $c, $text->{text} );
			}
		}
	}

	my $access = $c->check_page_access('admin');
	$c->render(template => 'editable_text', partial => 1
		, texts => $texts
		, access => $access
		);
}

sub _cid2uri {
	my $c = shift;
	unless ($c->stash('cid2uri')) {
		$c->stash('cid2uri', $c->db->selectall_arrayref('select category_id as id, tricycle_get_uri_by_id(category_id) as uri from prefix_category where uri_name is not null order by xpath desc', {Slice => {}}));
	}
	return $c->stash('cid2uri');
}

sub _links_to_id {
	my $c = shift;
	my $text = shift;

	my $voc = $c->_cid2uri();
	$text =~ s|(href=['"]?/?)$_->{uri}([^'">]*)(['"]?)|$1%cid:=$_->{id}%$2$3|ig foreach (@$voc);

	return $text;
}

sub _links_to_uri {
	my $c = shift;
	my $text = shift;

	my %voc = map {$_->{id} => $_->{uri}} @{_cid2uri($c)};
#	warn $c->dumper(\%voc);
	$text =~ s|%cid:=(\d+)%|$voc{$1}|ig;

	return $text;
}

sub create {
	my $c = shift;

	my $text = $c->_links_to_id( $c->param('text') );

	my $rows = $c->db->do(q|INSERT INTO prefix_texts (category_id, text) VALUES (?, ?)|, undef, $c->param('category_id') || $c->stash('category_id'), $text);
	my $new_id = $c->dbh->last_insert_id(undef, undef, undef, undef);
	$c->log('Create text for category %d, with new id %d', $c->stash('category_id'), $new_id);
	$c->render(json => {new_id => $new_id, status => $c->dbh->errstr ? 'error' : 'ok', rows => $rows});
}

sub update {
	my $c = shift;

	my $rows = $c->db->do('UPDATE prefix_texts SET text = ? WHERE text_id = ?', undef, $c->_links_to_id( $c->param('text') ), $c->stash('text_id'));
	$c->log('Update text %d', $c->stash('text_id'));

	$c->render(json => $c->dbh->errstr ? {status => 'error', message => $c->dbh->errstr} : {status => 'ok'});
}

sub upload {
	my $c = shift;
	$c->render(json => {status => 'error', message => 'Not supported file format'}) if $c->param('type') ne 'photos' || $c->param('type') ne 'files';

	my ($fileinfo) = $c->uploader({type => $c->param('type'), param => 'file', destination => $c->param('type') eq 'photos' ? $c->config('images') : $c->config('files'), category_id => undef, description => 'Uploaded from page editor'});

	my $json = {status => 'ok', filelink => $fileinfo->{filelink}, filename => $fileinfo->{filename}};
	$json = {message => $fileinfo->{error}, status => 'error'} if $fileinfo->{error};
	$c->render(json => $json);
}

1;
