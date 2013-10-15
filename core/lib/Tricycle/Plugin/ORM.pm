package Tricycle::Plugin::ORM;
use Mojo::Base 'Tricycle::Plugin::DB';
# $plugin->dbh accessible

#sub query {
#	my $plugin = shift;
#	my ($query, $params) = @_;
#
#	$plugin->{controller}->app->log->debug('DB: ORM::query called');
#
#	return {
#		  count => 1
#		, result => [{test => 'Tesssst!'}]
#		, err => "0E0"
#	}
#}

sub get_texts {
	my $plugin = shift;
	my $categiry_id = shift;
	my $type = shift;
	my $texts;

	unless ($type) {
		$texts = $plugin->dbh->selectall_arrayref('select * from prefix_texts where category_id = ?', {Slice=>{}}, $categiry_id);
	} elsif ($type eq 'id') {
		$texts = $plugin->dbh->selectall_arrayref('select * from prefix_texts where text_id = ?', {Slice=>{}}, $categiry_id);
	}

	return {
		  count => scalar @$texts
		, result => $texts
		, err => $plugin->dbh->errstr
	}
}

sub get_text {
	return shift->get_texts(shift)->{result}->[0]->{text};
}

sub get_pride {
	my $plugin = shift;

	my $pride = $plugin->dbh->selectrow_hashref('SELECT filename, description, photo_id FROM prefix_photos where pride is not null ORDER BY rand() LIMIT 1;');

	return $pride;
}

sub get_subtree_by_id {
	my $plugin = shift;
	my $parent_id = shift || 0;

	my $caregories = $plugin->db->selectall_arrayref(q|select *, concat('/', tricycle_get_uri_by_id(category_id)) as url from prefix_category where COALESCE(parent_id,0) = ? order by IF(sort_order > 0, sort_order , IF(sort_order is NULL , 128, 256 + sort_order)), category_id|, {Slice => {}}, $parent_id);

	return {
		  count => scalar @$caregories
		, result => $caregories
		, err => $plugin->dbh->errstr
	}
}

sub get_mainpage_id {
	my $plugin = shift;

	my ($id) = $plugin->db->selectrow_array(q|select category_id from prefix_category where uri_name is null limit 1|);

	return $id
}

sub get_url_by_pagetype {
	my $plugin = shift;

	my $urls = $plugin->dbh->selectall_arrayref('SELECT category_id, title, access_level, tricycle_get_uri_by_id(category_id) as uri, IF(visible is null, 0, 1) as visible, IF(enabled is null, 0, 1) as enabled FROM prefix_category where pagetype = ? and enabled = "" order by xpath, IF(sort_order > 0, sort_order , IF(sort_order is NULL , 128, 256 - sort_order))', { Slice => {} }, shift);

	return {
		  count => scalar @$urls
		, result => $urls
		, err => $plugin->dbh->errstr
	}
}

sub delete_category {
	my $plugin = shift;
	my $category_id = shift;

	my $rows_count = $plugin->dbh->do('DELETE FROM prefix_category WHERE category_id = ?', undef, $category_id);

	return {
		  count => $rows_count
		, result => !$plugin->dbh->errstr
		, err => $plugin->dbh->errstr
	}
}

sub get_url_by_uriname {
	my $plugin = shift;

	my $urls = $plugin->dbh->selectall_arrayref('SELECT category_id, title, access_level, tricycle_get_uri_by_id(category_id) as uri, IF(visible is null, 0, 1) as visible, IF(enabled is null, 0, 1) as enabled FROM prefix_category where uri_name = ? order by xpath, IF(sort_order > 0, sort_order , IF(sort_order is NULL , 128, 256 - sort_order))', { Slice => {} }, shift);

	return {
		  count => scalar @$urls
		, result => $urls
		, err => $plugin->dbh->errstr
	}
}

1;