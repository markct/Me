package Me;
use strict;
use Module::Load;

my ($_app);
sub app { $_app }
sub reset {
	my ($me, $app_class) = @_;
	load $app_class;
	$_app = $app_class->new;
}

package Me::EndException;
use base 'Error';

1;
