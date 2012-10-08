package Me::Controller;
use strict;
use Error qw(:try);
use Me::Helpers;
use Capture::Tiny qw(capture_stdout);

sub new {
	bless {
		layout => 'layouts/main',
		body_end => '',
	}, shift;
}

sub route {
	my $this = shift;
	my @route = @_;
	my $action = @route? shift(@route) : 'index';
	my $method = 'action'.ucfirst($action);

	throw Me::HttpException(404, '', "Action \"$action\" not found")
		if (!$this->can($method));

	$this->$method(@route);
}

sub redirect {
	my ($this, $uri) = @_;
	Me->app->header('Status: 302');
	Me->app->header('Location: '.$uri);
	Me->app->end;
}

sub render {
	my ($this, $view, $data, $return) = @_;
	return $this->renderText($this->renderInternal($view, $data, 1), $return);
}

sub renderText {
	my ($this, $output, $return) = @_;
	if ($this->{layout}) {
		$output = $this->renderInternal($this->{layout}, {'content' => $output}, 1);
	}
	if ($return) { return $output }
	else { print $output }
}

sub renderInternal {
	my ($this, $_viewFile_, $_data_, $_return_) = @_;
	# 100% of the weirdness here is to control variable scope - to
	# make available the items in the $_data_ hash as variables local
	# to the view (plus $this), while not adding any other variables.

	if (ref($_data_) eq 'HASH') {
		$_data_->{this} = $this;
	} else {
		$_data_ = {data => $_data_, this => $this};
	}

	# Embperl - gave up before getting it fully working
	# if (-f Me->app->viewPath.'/'.$_viewFile_.'.epl') {
	# 	# This forces Embperl to be loaded at runtime, so it won't load if not used:
	# 	eval {
	# 	    require Embperl;
	# 	    Embperl->import;
	# 	    1;
	# 	} or die $@;
	# 
	# 	my $out;
	# 	Embperl::Execute({
	# 		inputfile => Me->app->viewPath.'/'.$_viewFile_.'.epl',
	# 		output => \$out,
	# 		param => [$_data_],
	# 	});
	# 	return $out if $_return_;
	# 	print $out;
	# 	return;
	# }

	# Text::Xslate - don't like it; too sandboxed/restricted
	# if (-f Me->app->viewPath.'/'.$_viewFile_.'.tx') {
	# 	# This forces Text::Xslate to be loaded at runtime, so it won't load if not used:
	# 	eval {
	# 	    require Text::Xslate;
	# 	    Text::Xslate->import;
	# 	    1;
	# 	} or die $@;
	# 
	# 	my $tx = Text::Xslate->new;
	# 	my $out = $tx->render(Me->app->viewPath.'/'.$_viewFile_.'.tx', $_data_);
	# 	return $out if $_return_;
	# 	print $out;
	# 	return;
	# }

	# Text::Haml - basically useless at this point (no loops, blocks, conditionals, etc.)
	# if (-f Me->app->viewPath.'/'.$_viewFile_.'.haml') {
	# 	# This forces Text::Haml to be loaded at runtime, so it won't load if not used:
	# 	eval {
	# 	    require Text::Haml;
	# 	    Text::Haml->import;
	# 	    1;
	# 	} or die $@;
	# 
	# 	my $haml = Text::Haml->new;
	# 	my $out = $haml->render_file(Me->app->viewPath.'/'.$_viewFile_.'.haml', %{$_data_});
	# 	return $out if $_return_;
	# 	print $out;
	# 	return;
	# }

	# Mason
	# if (-f Me->app->viewPath.'/'.$_viewFile_.'.mc') {
	# 	# This forces Mason to be loaded at runtime, so it won't load if not used:
	# 	eval {
	# 	    require Mason;
	# 	    Mason->import;
	# 	    1;
	# 	} or die $@;
	# 	my $out = '';
	# 	my $interp = Mason->new(
	# 		comp_root => Me->app->viewPath,
	# 		data_dir => 'app/mason_cache',
	# 		);
	# 	{
	# 		local *STDOUT; # This is a hack; Mason destroys STDOUT without it
	# 		$out = $interp->run('/'.$_viewFile_, $_data_)->output;
	# 	};
	# 	return $out if $_return_;
	# 	print $out;
	# 	return;
	# }

	my $_eval_;

	while (my ($k, $v) = each %{$_data_}) {
		$_eval_ .= 'my $'.$k.' = $_data_->{'.$k."};\n";
	}
	$_eval_ .= 'my ($_data_, $_eval_);'."\n";
	$_eval_ .= '# line 1 "'.Me->app->viewPath.'/'.$_viewFile_.'.pl"'."\n";

	# ePerl
	if (-f Me->app->viewPath.'/'.$_viewFile_.'.epl') {
		# This forces Parse::ePerl to be loaded at runtime, so it won't load if not used:
		eval {
		    require Parse::ePerl;
		    Parse::ePerl->import;
		    1;
		} or die $@;
		open my $fh, Me->app->viewPath.'/'.$_viewFile_.'.epl'
			or die "Could not load view $_viewFile_.epl - $!";
		my $out;
		Parse::ePerl::Translate({
			Script => do { local $/;  <$fh> },
			Result => \$out,
			BeginDelimiter => '<?',
			EndDelimiter => '?>',
		});
		$_eval_ .= $out;
	} else {
		open my $_fh_, Me->app->viewPath.'/'.$_viewFile_.'.pl'
			or die "Could not load view $_viewFile_.pl - $!";
		$_eval_ .= do { local $/;  <$_fh_> };
	}

	if ($_return_) {
		my $_out_;
		open(my $_fh_, '>', \$_out_);
		{
			try {
				local *STDOUT = $_fh_;
				my ($_viewFile_, $_return_, $_fh_, $_out_);
				eval $_eval_;
				die $@ if $@;
			} catch Me::EndException with {
				my $e = shift;
				print $_out_;
				$e->throw;
			}
		}
		return $_out_;
	} else {
		my ($_viewFile_, $_return_, $_fh_);
		eval $_eval_;
		die $@ if $@;
	}
}

1;