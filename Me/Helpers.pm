package Me::Helpers;
use strict;

# exports all subs by default, but if any are specified, exports only those
sub import {
	no strict 'refs';
	my ($package, $caller, %symbols) = (shift, caller);
	if (@_) {
		$symbols{$_} = '*'.$package.'::'.$_ foreach (@_);
	} else {
		%symbols = %{$package . '::'};
	}
	while (my ($name, $symbol) = each %symbols) {
		next if $name eq 'BEGIN' || $name eq 'import';
		next unless *{$symbol}{CODE}; # only export subs
		*{ $caller.'::'.$name } = \*{ $symbol };
	}
}

sub h {
	my $s = shift;
	$s =~ s/&/&amp;/g;
	$s =~ s/"/&quot;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s;
}

sub trim {
	my ($str, $charlist) = @_;
	$charlist ||= " \t\n\r\0\x0B";
	$str =~ s/^[\Q$charlist\E]+//;
	$str =~ s/[\Q$charlist\E]+$//;
	return $str;
}

sub content_for {
	return 1;
}

sub nl2br { shift }
sub strtotime { shift }
sub date { shift }
sub number_format { shift }

1;