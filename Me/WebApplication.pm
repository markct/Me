package Me::WebApplication;
use strict;
use base 'Me::Application';
use Error qw(:try);
use Me::HttpException;
use Me::Helpers qw(trim);
use Me::QueryString;
use vars qw{$AUTOLOAD};

sub new {
	bless {
		default_content_type => 'Content-Type: text/html; charset=utf-8',
		_headers => [],
		_components_to_load => {},
		_loaded => {},
		_modules => [],
	}, shift;
}

sub AUTOLOAD {
	my $this = $_[0] or return undef;
	(my $method = $AUTOLOAD) =~ s/.*:://g;

	if ($method eq 'GET') {
		return $this->{_GET} ||= Me::QueryString::parse($ENV{QUERY_STRING});

	} elsif ($method eq 'POST') {
		return $this->{_POST} if $this->{_POST};
		if ($ENV{CONTENT_TYPE} =~ m{^application/x-www-form-urlencoded}) {
			return $this->{_POST} = Me::QueryString::parse($this->RAW_POST);
		} elsif ($ENV{CONTENT_TYPE} =~ m{^application/json}) {
			eval { require JSON } or die $@; # lazy-load JSON
			return $this->{_POST} = JSON::decode_json($this->RAW_POST);
		} else {
			return {};
		}

	} elsif ($method eq 'COOKIE') {
		return $this->{_COOKIE} ||= Me::QueryString::parse($ENV{HTTP_COOKIE}, qr/;\s*/);

	} elsif ($method eq 'RAW_POST') {
		return $this->{_RAW_POST} ||= ${\ <STDIN>};

	}

	$this->component($method)
	or do {
		my ($p, $file, $line) = caller;
		die "Component or method \"$method\" does not exist in package \"".__PACKAGE__."\" - called from $file line $line";
	};
}

sub run {
	my ($this, @configs) = @_;
	$this->load_config(@configs);
	$this->route(split('/', trim($ENV{PATH_INFO}, '/')));
}

sub header {
	my $this = shift;
	push @{$this->{_headers}}, shift;
}

sub send_headers {
	my $this = shift;

	$this->header($this->{default_content_type})
		unless grep /^content-type:/i, @{$this->{_headers}};

	print join("\n", @{$this->{_headers}})."\n\n";
}

sub set_cookie {
	my $this = shift;
	my %params = @_;
	use CGI::Cookie;
	my $c = CGI::Cookie->new(%params);
	$this->header("Set-Cookie: $c");
}

sub route {
	my $this = shift;
	my @path = @_;
	@path = qw(dash index) if (!$path[0]);

	my ($file, $class) = ('','');
	if ($this->is_module($path[0])) {
		$file .= $path[0].'/';
		$class .= ucfirst(shift @path).'::';
	}
	$file .= ucfirst($path[0]);
	$class .= ucfirst($path[0]).'Controller';

	try {
		throw Me::HttpException(404, '', "Controller $class not found")
			unless (-f Me->app->controllerPath.'/'.$file.'.pm');
		eval { require Me->app->controllerPath.'/'.$file.'.pm' };
		if ($@) {
			throw Me::HttpException(500, '', "Unable to load $class: $@");
		}

		my $out;
		open(my $fh, '>', \$out);
		{
			try {
				local *STDOUT = $fh;
				my $controller = $class->new;
				$controller->route(@path[1..$#path]);
			} catch Me::EndException with {
				# Ignore
			} catch Me::HttpException with {
				shift->throw;
			} catch Error with {
				my $e = shift;
				throw Me::HttpException(500, '', $e);
			}
		}

		Me->app->send_headers;
		print $out;
	} catch Me::HttpException with {
		my $e = shift;
		my $logmsg = "Error: code $e->{code}";
		$logmsg .= ", message: $e->{message}" if $e->{message};
		$logmsg .= ", detail: $e->{detail}" if $e->{detail};
		$logmsg =~ s/\s+$//g;
		print STDERR $logmsg,"\n";

		try {
			eval { require Me->app->controllerPath.'/Error.pm' };
			die $@ if $@;
			Me->app->{error} = $e;

			my $out;
			open(my $fh, '>', \$out);
			{
				local *STDOUT = $fh;
				my $controller = ErrorController->new;
				$controller->route;
			}
			Me->app->send_headers;
			print $out;

		} catch Error with {
			print STDERR "Unable to load ErrorController; displaying error in plain text.\n";
			print 'Status: ',$e->{code},"\n",
				"Content-Type: text/plain\n\n",
				$e->{code},' ',$e->code_text,"\n",
				$e->{message};
			exit 1;
		}
	}
}

sub is_module {
	my ($this, $name) = @_;
	scalar(grep $_ eq $name, @{$this->{_modules}});
}

1;
