package Tricycle::Admin::Tree;
use Mojo::Base 'Mojolicious::Controller';
use File::Basename 'dirname';

sub get {
	my $c = shift;
	unless ($c->stash('access_granted')) {
		$c->render('admin/forbidden');
		return 0;
	}

	# read pagetypes
	my @files = ();
	my $basedir;
	my %folders = (
		'' => $c->app->home->detect($c->app->routes->namespaces->[0]).'/lib/'.$c->app->routes->namespaces->[0],
		'admin-' => $c->app->home->detect('Tricycle').'/lib/Tricycle/Admin'
	);
	for my $prefix (keys %folders) {
		$basedir = $folders{$prefix};
		opendir D, $basedir;
			my @list = readdir D;
		closedir D;

		push @files, map {"$prefix$_"} grep {-f "$basedir/$_" && /\.pm$/} @list;
		foreach my $folder (grep {-d "$basedir/$_" && !/^\./ && !/^Plugins?$/i} @list) {
			opendir D, "$basedir/$folder";
				push @files, map {"$prefix$folder-$_"} grep {-f "$basedir/$folder/$_" && /\.pm$/} readdir D;
			closedir D;
		}
	}

	@files = map {lc} map {/(.+)\.pm$/} @files;
	$c->stash(pagetype => \@files);

	$c->session(admin_session => $c->rnd(16));

	$c->log('Get site tree');
	$c->render('admin/tree');

#	$c->respond_to(
#		json => {json => {hello => 'world'}},
#		html => {template => 'hello', message => 'world'},
#	);
}

sub _log {
	my $c = shift;
	my ($type, $id, $new, $old) = @_;

	foreach (qw(visible system enabled)) {
		$old->{$_} = defined $old->{$_} ? 'yes' : 'no' if $old;
		$new->{$_} = defined $new->{$_} ? 'yes' : 'no' if $new && exists $new->{$_};
	}

	$id = sprintf('%d [%s]', $id, $old->{title}) if defined $old && ($old->{title} eq $new->{title} || !exists $new->{title});
	$c->log('%s tree node %s:{%s}', ucfirst $type, $id, join ', ', map {"$_: " . (defined $old ? $old->{$_} . ' => ' : '') . $new->{$_}} grep {defined $new->{$_} && (defined $old ? $new->{$_} ne $old->{$_} : 1)} qw(title parent_id uri_name pagetype sort_order access_level visible enabled system));
}

sub _process {
	my $c = shift;
	my $type = shift;

	if ( !$c->stash('access_granted') || $c->param('email') || $c->session('admin_session') ne ($c->param('admin_session') || '') ) {
		$c->render(json => {status => 'error', message => 'Forbidden'});
		return 0;
	}

	my $rows = 0;
	my $json = {status => 'ok'};

	# get, process and store params into %params
	my $params = $c->req->body_params->to_hash;
	$params->{sort_order} ||= undef;
	$params->{visible} = $params->{visible} ? '' : undef if defined $c->param('visible');
	$params->{system} = $params->{system} ? '' : undef if defined $c->param('system');
	$params->{enabled} = $params->{enabled} ? '' : undef if defined $c->param('enabled');
	$params->{parent_id} ||= undef;
#	warn 'BODYPARAMS: ', $c->dumper($params);

	if ($type eq 'create') {
		my $parent = $c->db->selectrow_hashref(q|select * from prefix_category where category_id = ?|, {}, $c->param('parent_id'));
		$params->{xpath} = (($parent->{xpath} || '') eq '/' || !$parent->{xpath} ? '' : $parent->{xpath}) . '/' . ($params->{parent_id} || '');
		$params->{level} = $params->{parent_id} ? ($parent->{level} || 0) + 1 : 0;

		my $fields = 'parent_id, xpath, level, title, visible, enabled, uri_name, pagetype, sort_order, access_level, system';
		$rows = $c->db->do(qq|INSERT INTO prefix_category ($fields) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|, undef, map {$params->{$_}} split ', ', $fields);
		$json = {new_id => $c->dbh->last_insert_id(undef, undef, undef, undef), error => $c->dbh->errstr, status => $c->dbh->errstr ? 'error' : 'ok', rows => $rows};

		_log($c, $type, $json->{new_id}, $params);
	} elsif ($type eq 'update') {
		my $old = $c->db->selectrow_hashref(q|select * from prefix_category where category_id = ?|, {}, $params->{category_id}); #for log only

		if ($params->{reparenting}) {
			if ($params->{parent_id}) {
				my $parent = $c->db->selectrow_hashref(q|select * from prefix_category where category_id = ?|, {}, $params->{parent_id});
				$params->{xpath} = ($parent->{xpath} eq '/' || !$parent->{xpath} ? '' : $parent->{xpath}) . '/' . ($params->{parent_id} || '');
				$params->{level} = ($parent->{level} || 0) + 1;
			} else {
				$params->{parent_id} = undef;
				$params->{level} = 0;
				$params->{xpath} = '/';
			}
			$rows = $c->db->do(qq|UPDATE prefix_category SET parent_id = ?, xpath = ?, level = ? WHERE category_id = ?|, undef, map {$params->{$_}} qw(parent_id xpath level category_id));
			$c->db->do('call tricycle_rearrange_children(?)', undef, $params->{category_id});

			_log($c, 'Reparenting', $params->{category_id}, $params, $old);
		} else {
			$rows = $c->db->do(qq|UPDATE prefix_category SET title = ?, visible = ?, enabled = ?, uri_name = ?, pagetype = ?, sort_order = ?, access_level = ?, system = ? WHERE category_id = ?|, undef, map {$params->{$_}} qw(title visible enabled uri_name pagetype sort_order access_level system category_id));
			_log($c, $type, $params->{category_id}, $params, $old);
		}

		my $new_data = $c->db->selectrow_hashref(q|select *, concat('/', tricycle_get_uri_by_id(category_id)) as url from prefix_category where category_id = ?|, {}, $params->{category_id});
		$new_data->{visible} = Mojo::JSON->true if defined $new_data->{visible};
		$new_data->{system} = Mojo::JSON->true if defined $new_data->{system};
		$new_data->{enabled} = Mojo::JSON->true if defined $new_data->{enabled};
#		warn 'NEWDATA: ', $c->dumper($new_data);
#		foreach (keys %$new_data) {
#			$new_data->{$_} = Mojo::JSON->true if defined $new_data->{$_} && $new_data->{$_} eq '';
#		}
		$json = {error => $c->dbh->errstr, status => $c->dbh->errstr ? 'error' : 'ok', rows => $rows, new_data => $new_data};
	}

	return $c->render( json => $json );
}

# create tree node
sub post {
	my $c = shift;
	$c->_process('create', @_);
}

# update tree node
sub put {
	my $c = shift;
	$c->_process('update', @_);
}

# delete tree node
sub delete {
	my $c = shift;
	unless ($c->stash('access_granted') && !$c->param('email')) {
		$c->render('admin/forbidden');
		return 0;
	}

	my ($id) = $c->uri_params();
	my ($title) = $c->db->selectrow_array('select title from prefix_category where category_id = ?', undef, $id); # for log only
	my $deleted = $c->db('delete_category', $id);

	if ($deleted->{result}) {
		$c->render(json => {status => 'ok', deleted => $id, rows => $deleted->{count}, redirect => $c->stash('recognized_url')});
	} else {
		$c->render(json => {status => 'error', $deleted->{err}});
	}

	$c->log('Delete tree node %d [%s]: %s', $id, $title, $deleted->{err} || 'success');
}

1;