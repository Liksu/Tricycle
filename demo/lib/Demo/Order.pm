package Demo::Order;
use Mojo::Base 'Mojolicious::Controller';

use Email::MIME;
use Email::Sender::Simple qw(sendmail);
#use Email::Sender::Transport::SMTP::TLS;

sub get {
	my $c = shift;

	$c->render('order');
}

sub post {
	my $c = shift;

	$c->_mail( $c->render(partial => 'order_mail') );

	$c->render('order_sent');
}

sub _mail {
	my $c = shift;
	my $body = shift;

	my $upload = $c->req->upload('upfile');

	my @parts = (
		Email::MIME->create(
			attributes => {
				content_type  => "text/html"
			},
			body => $body
		),
	);

	foreach my $upload ($c->req->upload('upfile')) {
		next unless $upload->filename;
		warn $upload->filename;
		push @parts, Email::MIME->create(
			attributes => {
				filename      => $upload->filename,
				content_type  => $upload->headers->content_type,
				encoding      => "base64",
				disposition   => "attachment",
				Name          => $upload->filename
	        },
	        body => $upload->asset->slurp
	    );
#	    warn $upload->asset->slurp;
	}

	my $email = Email::MIME->create(
	    header => [
			@{$c->config('mail_headers')},
	        content_type   =>'multipart/mixed'
	    ],
	    parts  => [ @parts ],
	);

	sendmail( $email, {transport => $c->config('mail_transport') } );
#	sendmail( $email, {transport => Email::Sender::Transport::SMTP::TLS->new( @{$c->config('mail_transport')} )} );
}

1;