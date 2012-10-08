package Me::ConsoleApplication;
use strict;
use base 'Me::Application';
use Error qw(:try);
use vars qw{$AUTOLOAD};
use Module::Load;

sub new {
	bless {
		_components_to_load => {},
		_loaded => {},
	}, shift;
}

sub AUTOLOAD {
	my $this = $_[0] or return undef;
	(my $method = $AUTOLOAD) =~ s/.*:://g;

	$this->component($method)
		or die "Component or method \"$method\" does not exist in package \"".__PACKAGE__.'"';
}

sub run {
	my ($this, @configs) = @_;
	$this->load_config(@configs);
	$this->route(@ARGV);
}

sub route {
	my $this = shift;
	my @path = @_;
	if (!$path[0]) {
		print STDERR "Command name missing\n";
		exit 1;
	}

	my $config = $this->{_commands}{$path[0]};

	my $class;
	if ($config->{class}) {
		$class = $config->{class};
		load $class;
	} else {
		my $file = ucfirst($path[0]);
		$class = $file.'Command';

		throw Error::Simple("Command $class not found")
			unless (-f Me->app->commandPath.'/'.$file.'.pm');
		eval { require Me->app->commandPath.'/'.$file.'.pm' };
		throw Error::Simple("Unable to load $class: $@")
			if ($@);
	}
	my $command = $class->new;
	if ($config) {
		while (my ($k, $v) = each %$config) { $command->{$k} = $v }
	}
	$command->init if $command->can('init');
	$command->route(@path[1..$#path]);
}

1;
