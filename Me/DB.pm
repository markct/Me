package Me::DB;
use strict;
use DBIx::Simple;
use SQL::Abstract::Limit;
use vars qw{$AUTOLOAD};

sub new { bless {}, shift }

sub AUTOLOAD {
	my $this = shift or return undef;
	(my $method = $AUTOLOAD) =~ s/.*:://g;

	my $ref = $this->{conn}->can($method);
	if ($ref) {
		unshift @_, $this->{conn};
		goto &$ref;
	}
	die "Method \"$method\" does not exist in package \"".__PACKAGE__.'"';
}
DESTROY {}

sub init {
	my $this = shift;
	$this->{conn} = DBIx::Simple->connect($this->{data_source}, $this->{username}, $this->{password});
	$this->{conn}->abstract = SQL::Abstract::Limit->new( limit_dialect => $this->{conn}->dbh );
}

1;
