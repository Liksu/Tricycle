package Tricycle;
use Mojo::Base 'Mojolicious::Plugin';

use File::Basename 'dirname';
use File::Spec::Functions 'catdir';

# This method will run once at server start
sub register {
	my ($plugin, $app, $options) = @_;
	srand();

	$app->{config} = $app->plugin('Config', {file => $options->{'config'}});
	if ($app->config('theme')) {
		push @{$app->renderer->paths}, $app->renderer->paths->[0];
		$app->renderer->paths->[0] .= '/themes/' . $app->config('theme');
		push @{$app->static->paths}, $app->static->paths->[0];
		$app->static->paths->[0] .= '/themes/' . $app->config('theme');

		push @{$app->renderer->paths}, catdir(dirname(__FILE__), '../templates/themes/' . $app->config('theme'));
		push @{$app->static->paths},   catdir(dirname(__FILE__), '../public/themes/' . $app->config('theme'));
	}
	# Append "templates" and "public" directories
	push @{$app->renderer->paths}, catdir(dirname(__FILE__), '../templates');
	push @{$app->static->paths},   catdir(dirname(__FILE__), '../public');

	warn join ', ', @{$app->static->paths};

	push @{$app->plugins->namespaces}, 'Tricycle::Plugin';
	$app->plugin('Ajax');
	$app->plugin('ORM');
	$app->plugin('Helpers');
	$app->plugin('Upload');
	$app->plugin('Menu');
	$app->plugin('EditableText');
	$app->plugin('Thumbnails');

	# Router

	$app->hook(before_routes => sub {
		my $c = shift;
		return 0 if $c->stash('mojo.static');

		# assess level
		$c->session('user_access_level' => 'guest') unless $c->session('user_access_level');

		# router
		my $path = ($c->req->url->path->to_string =~ m|^/(.*?)/?$|)[0];
		my $rs = {};
		my @xpath = ();

		unless ($path) {
			my $dbh = $c->db('check');
			$rs = $c->db('check')->selectrow_hashref(q|select category_id, pagetype, uri_name, access_level, '' as recognized_url from prefix_category where uri_name is NULL limit 1|);
		} else {
			my $query = q|select category_id, pagetype, uri_name, title, xpath, access_level, tricycle_get_uri_by_id(category_id) as recognized_url from prefix_category where category_id = tricycle_get_id_by_uri(?)| . ($c->check_page_access('su') ? '' : q| and enabled = ''|);
			$rs = $c->db('check')->selectrow_hashref($query, {}, $path) if $c->config('tree')->{multihead};
			$rs = $c->db('check')->selectrow_hashref($query, {}, "/$path") unless exists $rs->{category_id};
		}
		$path = "/$path";

		my $method = $c->req->method;
		if (uc($c->req->method) eq 'POST' && ($c->param('rest') // '') eq 'ore' && (($c->param('method') // '') ~~ [qw'GET POST PUT DELETE'])) {
			$method = $c->param('action');
		}

		if ($rs) {
			$c->req->url->path->{path} = join '/', '', $rs->{pagetype}, lc($method), $rs->{category_id}, '';
			$c->stash(category_title => $rs->{title} || '');
			$c->stash(title => ($rs->{title} || '') . ($rs->{title} ? ' « ' : '') . $c->config('title'));
			$c->stash(old_url => $path);
			$c->stash(recognized_url => $c->url('/', $rs->{recognized_url}, undef));
			$c->stash(uri_name => $rs->{uri_name});
			$c->stash(method => $method);
			$c->stash(page_access_level => $rs->{access_level});
			@xpath = ($rs->{xpath} ? $rs->{xpath} =~ /(\d+)/g : (), $rs->{category_id});
		}
		$c->stash(xpath => \@xpath);

		# else
		$c->stash('access_granted' => $c->check_page_access( $c->stash('page_access_level') ));
		$c->render('admin/forbidden') unless $c->stash('access_granted');
	});

	push @{$app->routes->namespaces}, 'Tricycle';
	$app->routes->route('/:controller/:action/:category_id')->to;
}

1;
