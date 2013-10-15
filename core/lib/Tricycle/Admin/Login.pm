package Tricycle::Admin::Login;
use Mojo::Base 'Mojolicious::Controller';

sub get {
	my $c = shift;

	$c->render($c->session('user') ? 'admin/logout_form' : 'admin/login_form');
}

sub put { # create new login
	my $c = shift;

	my $user = $c->db->selectrow_hashref('select user_id, login, access_level from prefix_users where login = ? and pass = password(?)', {}, $c->param('login'), $c->param('password'));

	if ($user) {
		$c->session('user' => {login => $user->{'login'}, id => $user->{'user_id'}});
		$c->session('user_access_level' => $user->{'access_level'});
		$c->render(json => {redirect => '/' . $c->db('get_url_by_pagetype', 'admin-mainpage')->{result}->[0]->{uri}, status => 'ok'});
		$c->log('Login successful');
	} else {
		$c->session('user' => undef);
		$c->session('user_access_level' => 'guest');
		$c->render(json => {status => 'error', message => 'User not found'});
		$c->log('Failed login for %s:%s', $c->param('login'), $c->param('password'));
	}
}

sub delete { # logout
	my $c = shift;
	$c->log('Logout successful');

	$c->session('user' => undef);
	$c->session('user_access_level' => 'guest');

	$c->render(json => {redirect => '/', status => 'ok'});
}

1;