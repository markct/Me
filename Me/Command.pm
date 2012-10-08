package Me::Command;
use strict;

sub new { bless {}, shift }

sub route {
	my $this = shift;
	my @route = @_;
	my $action = @route? shift(@route) : 'index';
	my $method = 'action'.ucfirst($action);

	throw Error::Simple("Action \"$action\" not found")
		if (!$this->can($method));

	$this->$method(@route);
}

1;
