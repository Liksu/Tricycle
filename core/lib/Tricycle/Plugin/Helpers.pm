package Tricycle::Plugin::Helpers;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
	my ($plugin, $app, $config) = @_;

	my @methods = map {/^_(.+)$/} grep { defined &{$_} && $_ =~ /^_/ } keys %Tricycle::Plugin::Helpers::;

	$app->helper($_ => \&{"_$_"}) foreach @methods;
}

sub _check_page_access {
	my $c = shift;
	my $page_access_level = shift || '';

	my $n = 1;
	my %user_levels = map {$_ => $n++} qw(guest user admin su);
	$user_levels{''} = 0;

	return $user_levels{ $c->session('user_access_level') || '' } >= $user_levels{ $page_access_level }
}

sub _uri_params {
	my $c = shift;

	my $uri_part = $c->stash('recognized_url');
	my ($params) = ($c->stash('old_url') =~ m|$uri_part/([^\?]+)|);

	return split '/', $params;
}

sub _set_stash_by_referrer {
	my $c = shift;

	my ($referrer) = ($c->req->headers->referrer =~ m|^.*//[^/]+/([^\?]*?)/?(?:\?.*)?$|);
	my $query = q|select * from prefix_category where category_id = tricycle_get_id_by_uri(?)|;

	my $category = {};
	$category = $c->db->selectrow_hashref($query, {}, $referrer) if $c->config('tree')->{multihead};
	$category = $c->db->selectrow_hashref($query, {}, "/$referrer") unless exists $category->{category_id};

	$c->stash(category_id => $category->{category_id});
	$c->stash(old_url => $c->req->headers->referrer);
	$c->stash(recognized_url => $c->url('/', $referrer, undef));
	$c->stash(uri_name => $category->{uri_name});
	$c->stash(page_access_level => $category->{access_level});
	$c->stash(xpath => [($category->{xpath} || '') =~ /(\d+)/g, $category->{category_id}]);
	$c->stash(access_granted => $c->check_page_access( $c->stash('page_access_level') ));
}

sub _rnd {
	my $c = shift;
	my $count = shift || 16;

	my @chars = ('A'..'Z', 'a'..'z', '0'..'9', '_');
	my $random_string = '';
	$random_string .= $chars[rand(@chars)] for (1..$count);

	return $random_string;
}

sub _once_include {
	my $c = shift;
	my ($type, $file) = @_;

	if ($type eq 'get') {
		return '' unless $c->stash('once_include') && $c->stash('once_include')->{$file};
		my %values = ();
		my @results = ();
		foreach my $value (@{$c->stash('once_include')->{$file}}) {
			$value = &{$value}() if ref $value eq 'CODE';
			unless ($values{$value}) {
				push @results, $value;
				$values{$value}++;
			}
		}
		return join "\n", @results;
	} else {
		$c->stash('once_include', {}) unless $c->stash('once_include');
		$c->stash('once_include')->{$type} = [] unless $c->stash('once_include')->{$type};
		push @{$c->stash('once_include')->{$type}}, $file;
	}
	return '';
}

sub _log {
	my $c = shift;
	my $message = shift;
	$message = sprintf($message, @_) if $message =~ /%[\s\+\-0\#]?[sdfcxe]/i;

	$c->db->do(q|INSERT INTO prefix_logs (datetime, ip, user, access_level, method, page, action) VALUES (NOW(), ?, ?, ?, ?, ?, ?)|, undef
		, $c->tx->remote_address
		, $c->session('user') ? $c->session('user')->{'login'} : 'guest'
		, $c->session('user_access_level')
		, $c->stash('method') || 'undef'
		, $c->stash('old_url')
		, $message
		);
}

sub _url {
	my $c = shift;
	my $url = join '/', '', (grep {$_} @_), defined $_[-1] ? '' : ();
	$url =~ s|/+|/|g;
	return $url
}

1;
