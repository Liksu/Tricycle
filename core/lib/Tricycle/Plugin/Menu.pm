package Tricycle::Plugin::Menu;
use Mojo::Base 'Mojolicious::Plugin';
use File::Basename 'dirname';
use File::Spec::Functions 'catdir';

sub register {
	my ($plugin, $app, $config) = @_;

	# Append "templates" and "public" directories
	my $base = catdir(dirname(__FILE__), 'Menu');
	push @{$app->renderer->paths}, catdir($base, 'templates');
	push @{$app->static->paths},   catdir($base, 'public');

	$app->helper( 'menu' => \&_get_menu );
}

sub _get_menu {
	my $c = shift;
	my $type = shift || 'main';
	my $parent_url = shift;

	my $id = $c->stash('category_id');
	my $items = [];

	my $own_where = $c->check_page_access('su') ? '' : q|and enabled = ''|;
	# in order "256 - sort_order" must be "256 + sort_order" for 1,2,3,null,null,-3,-2,-1. But now for right position order must be 1,2,3,null,null,-1,-2,-3; that's why minus.
	$own_where = qq|visible = '' $own_where order by IF(sort_order > 0, sort_order , IF(sort_order is NULL , 128, 256 - sort_order)), category_id|;
	my $parent_id = 0;
	if ($type eq 'main') {
		$parent_id = $c->db('get_mainpage_id') unless $c->config('tree')->{multihead};
		$items = $c->db->selectall_arrayref(qq|select category_id as id, title, uri_name, sort_order, access_level from prefix_category where ifnull(parent_id, 0) = ? and $own_where|, { Slice => {} }, $parent_id);
	} elsif ($type eq 'second') {
		$parent_id = $c->stash('category_id');
		if (defined $parent_url) {
			if ($parent_url =~ /^(\d+)$/) {
				$parent_id = $c->stash('xpath')->[$1];
			} else {
				($parent_id) = $c->db->selectrow_array(q|select category_id from prefix_category where category_id = tricycle_get_id_by_uri(?)|, {}, $parent_url);
			}
		}
		$items = $c->db->selectall_arrayref(qq|select category_id as id, title, uri_name, access_level, tricycle_get_uri_by_id(category_id) as path from prefix_category where ifnull(parent_id, 0) = ? and $own_where|, { Slice => {} }, $parent_id);
	}

	foreach my $line (@$items) {
		$line->{active} = $line->{id} == ($c->stash('category_id') // 0) || (grep {$line->{id} == $_} @{$c->stash('xpath')});
		$line->{visible} = $line->{uri_name} && $c->check_page_access( $line->{access_level} );
	}

	$c->render(template => "${type}_menu", partial => 1, items => $items);
#	$c->render(template => "main_menu", partial => 1, items => $items);
}

1;
