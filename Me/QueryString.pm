package Me::QueryString;
use strict;

sub parse {
	my ($q, $pattern) = @_;
	$pattern ||= qr/&/;
	my @pairs = split($pattern, $q);
	my %out;
	foreach my $pair (@pairs) {
		my ($k, $v) = split(/=/, $pair);
		$k =~ s/\+/ /g;
		$k =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
		$v =~ s/\+/ /g;
		$v =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
		
		my @m = $k =~ /([^[]+)((?:\[[^[]*\])*)/;
		my @keys;
		if ($m[1] eq '[]') {
			push @keys, $m[0], '';
		} elsif ($m[1]) {
			push @keys, $m[0], split(/\]\[/, substr($m[1], 1, -1), -1);
		} else {
			push @keys, $k;
		}
		set_by_path(\%out, \@keys, $v);
	}
	\%out;
}

sub set_by_path {
	my ($hash, $keys, $value) = @_;
	my $k = shift @$keys;
	$k = next_numeric_key($hash) if $k eq '';
	if (!@$keys) {
		$hash->{$k} = $value;
	} else {
		$hash->{$k} = {} if (!ref($hash->{$k}));
		set_by_path($hash->{$k}, $keys, $value);
	}
}

sub next_numeric_key {
	my ($hash) = @_;
	my $max = -1;
	foreach my $k (keys %$hash) {
		$max = $k if ($k =~ /^\d$/ && $k > $max);
	}
	$max + 1;
}

1;