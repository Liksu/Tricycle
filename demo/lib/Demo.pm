package Demo;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
	my $app = shift;

	push @{$app->plugins->namespaces}, '';
	$app->plugin('Tricycle', {config => 'lib/myapp.conf'});

	$app->plugin('Demo::Gallery');

	$app->secret( $app->config('secret') );
}

1;
