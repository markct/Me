package Me::Application;
use strict;
use Module::Load;
use Clone qw(clone);
use Hash::Merge::Simple;

DESTROY {}

sub param {
	my ($this, $k) = @_;
	defined($this->{_params}{$k})? clone($this->{_params}{$k}) : undef;
}

sub commandPath { shift->{_commandPath} }
sub controllerPath { shift->{_controllerPath} }
sub viewPath { shift->{_viewPath} }

sub load_config {
	my ($this, @configs) = @_;

	my $defaults = {
		commandPath => 'app/commands',
		controllerPath => 'app/controllers',
		viewPath => 'app/views',
		commands => {
			migrate => {
				class => 'Me::MigrateCommand',
				migrationPath => 'app/migrations',
				migrationTable => 'migrations',
				dbComponentID => 'db',
			},
		},
	};
	my $config = Hash::Merge::Simple::merge($defaults, @configs);

	# Load configuration; prep components for lazy loading
	foreach my $k (qw(params modules commands commandPath controllerPath viewPath)) {
		$this->{'_'.$k} = $config->{$k}; # if $config->{$k};
	}
	if ($config->{components}) {
		while (my ($cid, $cdata) = each %{$config->{components}}) {
			next unless $cdata->{class};
			next if defined($cdata->{enabled}) && !$cdata->{enabled};
			$this->{_components_to_load}{$cid} = $cdata;
		}
	}
}

sub load_component {
	my ($this, $cid) = @_;
	my $cdata = $this->{_components_to_load}{$cid};
	load $cdata->{class};
	my $c = $this->{_loaded}{$cid} = $cdata->{class}->new;
	while (my ($k, $v) = each %$cdata) { $c->{$k} = $v }
	delete $this->{_components_to_load}{$cid};
	$c->init if $c->can('init');
	$c;
}

sub component {
	my ($this, $name) = @_;
	if ($this->{_loaded}{$name}) {
		$this->{_loaded}{$name};
	} elsif ($this->{_components_to_load}{$name}) {
		$this->load_component($name);
	}
}

sub end { throw Me::EndException() }

1;