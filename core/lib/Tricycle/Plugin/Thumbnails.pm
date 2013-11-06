package Tricycle::Plugin::Thumbnails;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Base 'Mojolicious::Controller';
use Image::Magick;

sub register {
	my ($plugin, $app, $config) = @_;

	my $width = $app->config('thumbnails') && $app->config('thumbnails')->{width} || [];
	my $height = $app->config('thumbnails') && $app->config('thumbnails')->{height} || [];
	my @dimensions = keys %{{ map {$_ => 1} @$width, @$height }};

	unshift @{$width}, '';
	unshift @{$height}, '';

	$app->routes->route($app->config('images') . '/(:width)x(:height)/#file', width => $width, height => $height)->to(namespace => 'Tricycle::Plugin', controller => 'Thumbnails', action => 'process', width => undef, height => undef);
	$app->routes->route($app->config('images') . '/(:dimension)/#file', dimension => \@dimensions)->to(namespace => 'Tricycle::Plugin', controller => 'Thumbnails', action => 'process');

	$app->helper('thumb' => \&_get_thumbnail);
	foreach my $name ( keys %{$app->config('thumbnails')->{named}}, '' => '' ) {
		$app->helper("thumb_$name" => sub { _get_thumbnail( shift, shift, $app->config('thumbnails')->{named}->{$name} // '' ) }  );
	}
	$app->helper('delete_thumbnails' => \&_clear_thumb);
}

sub process {
	my $c = shift;
	my ($width, $height) = $c->stash('dimension')
		? ($c->stash('dimension') // 16, $c->stash('dimension') // 16)
		: ($c->stash('width') // '', $c->stash('height') // '');

	my $filepath = $c->uploader_path($c->config('images'), $c->stash('file'));
	unless ( ($width || $height) && -f $filepath ) {
		$c->render_not_found;
		return 0;
	}
	$c->app->log->debug(sprintf('Process thumbnail (%sx%s) for %s', $width, $height, $filepath));

	my $image = Image::Magick->new;
	$image->Read($filepath);
	$image->Set(quality => 85);
	$image->Resize(geometry => $width . 'x' . $height . '>');

	my $folder = $c->uploader_path(undef, $c->config('images'), $width . 'x' . $height);
	mkdir $c->uploader_path($folder) unless -d $c->uploader_path($folder);
	$image->Write( filename => $c->uploader_path($folder, $c->stash('file')) );

	$c->render_static(substr $c->uploader_path(undef, $c->config('images'), $width . 'x' . $height, $c->stash('file')), 1);
}

sub _get_thumbnail {
	my $c = shift;
	my $file = shift;
	my $dimension = shift // $c->config('thumbnails')->{default};
	$dimension = $c->config('thumbnails')->{named}->{$dimension} // $dimension;
	if (defined $c->config('thumbnails')->{named}->{$file}) {
		$dimension = $c->config('thumbnails')->{named}->{$file};
		undef $file;
	}

	my $filepath = join '/', $c->config('images'), $dimension, $file;
	$filepath =~ s|/+|/|g;

	return $filepath;
}

sub _clear_thumb {
	my $c = shift;
	my ($root_folder, $file) = @_;
	opendir D, $root_folder;
	unlink "$root_folder/$_/$file" foreach grep {!/^\./ && -d "$root_folder/$_"} readdir D;
	closedir D;
}

1;