package Me::RestController;
use strict;
use base 'Me::Controller';
use JSON;

sub route {
	my ($this, @route) = @_;

	Me->app->{default_content_type} = 'Content-Type: application/json; charset=utf-8';

	my $http_method = $ENV{REQUEST_METHOD};
	my $action = ucfirst(lc(Me->app->GET->{_method} || $http_method));

	# If HTTP method is GET, allow only a Get action
	throw Me::HttpException(400)
		if ($action ne 'Get' && $http_method eq 'GET');

	my $method = 'action'.$action;
	throw Me::HttpException(404, '', "Action \"$action\" not found")
		if (!$this->can($method));

	$this->$method(@route);
}

1;
