package Tricycle::Plugin::Upload;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Base 'Mojolicious::Controller';

use File::Basename 'dirname';
use File::Spec::Functions 'catdir';

sub register {
	my ($plugin, $app, $config) = @_;

	# Append "templates" and "public" directories
	my $base = catdir(dirname(__FILE__), 'Upload');
	push @{$app->renderer->paths}, catdir($base, 'templates');
	push @{$app->static->paths},   catdir($base, 'public');

	# self routing
	$app->routes->bridge('/plugins/upload/:action')->to(cb => sub {
		my $c = shift;
		$c->set_stash_by_referrer();
		return 1;
	})->route->via('POST')->to(namespace => 'Tricycle::Plugin', controller => 'upload', action => 'photo');

	# create helper for internal use
	$app->helper('uploader' => \&_uploader);
	$app->helper('uploader_path' => \&_uploader_path);
	$app->helper('uploader_droparea' => \&_uploader_droparea);
	$app->helper('uploader_delete' => \&_uploader_delete);

	$ENV{MOJO_MAX_MESSAGE_SIZE} = 3_000_000;
}

sub photo {
	my $c = shift;
	my $json = {status => 'error', message => 'Something strange during upload'};

	my @photos = $c->_uploader({type => 'photos', param => 'files', destination => $c->config('images'), category_id => undef, description => ''});

	$json = {status => 'ok', 'files' => \@photos};
	$c->render(json => $json);
}

sub file {
	my $c = shift;
	my $json = {status => 'error', message => 'Something strange during upload'};

	my @photos = $c->_uploader({type => 'files', param => 'files', destination => $c->config('files'), category_id => undef, description => ''});

	$json = {status => 'ok', 'files' => \@photos};
	$c->render(json => $json);
}

sub _uploader_droparea {
	my $c = shift;
	my ($upload_url, $upload_type) = @_;
	$c->render('droparea', partial => 1, upload_url => $upload_url || '/', upload_type => $upload_type || 'photos');
}

sub _uploader {
	my $c = shift;
	my $options = shift; # hash {type => 'photos', param => 'file', destination => $c->config('images'), category_id => undef, description => ''}
	my @files;

	# Check file size
	return $c->render(text => 'File is too big.', status => 400) if $c->req->is_limit_exceeded;

	my @uploads = $c->req->upload($options->{param});
	foreach my $upload (@uploads) {
		next unless $upload->filename;
		my ($fname, $fext) = (($c->rnd(4) . '_' . $upload->filename) =~ /^(.*?)(\.[^\.]+)?$/);
		$fname =~ s|\.+|.|g;
		$fname =~ s|/||g;
		my $file_name = substr($fname, 0, 64 - length $fext) . $fext;
		#TODO: change table
		#TODO: add insert time
		if ($options->{type} eq 'photos') {
			$c->db->do(q|INSERT INTO prefix_photos(category_id, filename, description) VALUES (?, ?, ?)|, undef, $options->{category_id} || $c->stash('category_id'), $file_name, $options->{description});
		} elsif ($options->{type} eq 'files') {
			$c->db->do(q|INSERT INTO prefix_files(category_id, filename, type, size, description, access_level) VALUES (?, ?, ?, ?, ?, ?)|, undef, $options->{category_id} || $c->stash('category_id'), $file_name, $fext, $upload->size, $options->{description}, $c->session('user_access_level'));
		}
		my $new_id = $c->dbh->last_insert_id(undef, undef, undef, undef);
		my $file_path = $options->{destination} . "/$file_name";
		$upload->move_to($c->uploader_path() . $file_path);
		push @files, {
			  filename => $file_name
			, filelink => $file_path
			, id => $new_id
			, error => $c->dbh->errstr
		};
		$c->log('Upload %s, file %s with new id: %d', $options->{type}, $file_name, $new_id);
	}

	return @files;
}

sub _uploader_path {
	my $c = shift;
	my $base = $c->app->static->paths->[1];

	$base = shift if scalar @_ && !(defined $_[0]);
	my $path = join '/', ($base // ''), @_;
	$path =~ s|/+|/|g;

	return $path
}

sub _uploader_delete {
	my $c = shift;
	my $options = shift; #{type => photos|files, file_id => id OR file_name => name}
	return {error => 'Bad params for delete'} unless $options->{type} && ( $options->{file_id} || $options->{file_name} );

	my $id_field = 'file_id';
	my $filename_field = 'filename';
	my $table = 'files';
	my $config_item = 'files';

	if ($options->{type} eq 'photos') {
		$id_field = 'photo_id';
		$filename_field = 'filename';
		$table = 'photos';
		$config_item = 'images';
	}

	if (!$options->{file_name}) {
		($options->{file_name}) = $c->db->selectrow_array("select $filename_field from prefix_$table WHERE $id_field = ?", undef, $options->{file_id});
	} elsif (!$options->{file_id}) {
		($options->{file_id}) = $c->db->selectrow_array("select $id_field from prefix_$table WHERE $filename_field = ?", undef, $options->{file_name});
	}

	if ($options->{file_name}) {
		my $folder = $c->uploader_path( $c->config($config_item) );
		my $rows_count = $c->dbh->do("DELETE FROM prefix_$table WHERE $id_field = ?", undef, $options->{file_id});
		$c->log('Delete photo %s (id: %d): %s', $options->{file_name}, $options->{file_id}, $c->dbh->errstr || 'success');
		return { error => $c->dbh->errstr } if $c->dbh->errstr;

		unlink $folder . '/' . $options->{file_name};

		return {
			  deleted => !!$rows_count
			, file => $options->{file_name}
			, folder => $folder
#			, id => $options->{file_id} # id of deleted row!
		}
	} else {
		return {error => 'No file to delete'}
	}
}

1;