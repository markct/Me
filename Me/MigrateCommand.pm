package Me::MigrateCommand;
use strict;
use base 'Me::Command';
use Error qw(:try);
use File::Basename;

sub actionIndex { shift->actionUp }

sub actionUp {
	my $this = shift;
	my @migrations = glob($this->{migrationPath}.'/m*.pm');
	if (!@migrations) {
		print "No migrations found.\n";
		exit;
	}
	@migrations = sort @migrations;

	my $db = Me->app->component($this->{dbComponentID});
	my @migrations_already_run = $db->select($this->{migrationTable}, 'name')->flat;

	my @migrations_to_run;
	foreach my $m (@migrations) {
		(my $class = basename $m) =~ s/\.[^.]+$//;
		next if (grep $_ eq $class, @migrations_already_run);
		push @migrations_to_run, [$class, $m];
	}

	return print "All migrations have already been run.\n"
		unless @migrations_to_run;

	print "Running these migrations:\n";
	print "\t",$_->[0],"\n" foreach @migrations_to_run;
	print 'Proceed? [y/N] ';
	my $response = <STDIN>;
	return print "Canceled.\n" unless ($response =~ /^y/i);

	foreach (@migrations_to_run) {
		my ($class, $m) = @{$_};
		print "\nUp $class\n";
		my $r = $this->_run($class, 'up', $m);
		if ($r->{success}) {
			$db->insert($this->{migrationTable}, { name => $class });
			next;
		}
		return print 'Failed',($r->{message} ? ': '.$r->{message} : '.'),"\n\n";
	}
	print "\nDone.\n";
}

sub actionDown {
	my $this = shift;
	my $db = Me->app->component($this->{dbComponentID});
	$db->select($this->{migrationTable}, 'name', undef, 'name desc', 1)
		->into(my $last_migration);
	return print "No migrations have been run.\n" if !$last_migration;

	print 'Reverting ',$last_migration,'; proceed? [y/N] ';
	my $response = <STDIN>;
	return print "Canceled.\n" unless ($response =~ /^y/i);

	my $r = $this->_run($last_migration, 'down');
	if ($r->{success}) {
		$db->delete($this->{migrationTable}, { name => $last_migration });
	} elsif ($r->{message}) {
		print 'Failed: ',$r->{message},"\n";
	} else {
		print "Failed.\n";
	}
	print "Done.\n";
}

sub _run {
	my ($this, $name, $direction, $file) = @_;
	my ($result, $message);
	my $file = defined($file)? $file : $this->{migrationPath}.'/'.$name.'.pm';
	return { success => 0, message => 'Can\'t find migration '.$name }
		if !-f $file;
	try {
		require $file;
		$result = $name->$direction;
	} catch Error with {
		my $e = shift;
		$message = $e->text;
		$result = 0;
	};
	return {
		success => ($result ne 0) ? 1 : 0,
		message => $message,
	};
}

sub init {
	my $this = shift;
	my $db = Me->app->component($this->{dbComponentID});
	my $res = $db->query('SHOW tables like ?', $this->{migrationTable});
	return if ($res->rows);
	$db->query('CREATE TABLE `'.$this->{migrationTable}.'` (
		`name` varchar(128),
		PRIMARY KEY (`name`)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8');
}

1;
