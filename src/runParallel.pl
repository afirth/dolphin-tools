#!/usr/bin/perl
use strict; use warnings;

use vars qw($VERSION); $VERSION = '0.0.1';  ## Current version of this file
require  5.008;    ## requires this Perl version or later

use Getopt::Long qw(:config auto_help);
use Pod::Usage;

use IPC::ConcurrencyLimit;
use File::Path qw(make_path);


### ARG PARSING AND VERIFICATION ###
#
my %args = (
	'concurrent' => 10,
	'lockpath'   => '/tmp/locks',
	'sleep'      => 1,
	'verbose'    => 0,
	'command'    => '',
);

getoptions();

unless ( $args{command} ) {
	die( "Invalid Args: command to parallelize must be specified as --command='string'\n" );
}


### MAIN PROGRAM ###

# create the lock directory
make_path( $args{lockpath} );
# make_path will fail if the dir already exists, so check
unless ( -d $args{lockpath} ) {
	die "Unable to create path $args{lockpath}: $!";
}

my $cmd = $args{command};

# create the lock object
my $limit = IPC::ConcurrencyLimit->new(
	type      => 'Flock', # that's also the default
	max_procs => $args{concurrent}, # how many locks to allow
	path      => $args{lockpath}, # an option to the locking strategy. ConcurrencyLimits using the same lockpath share the limit
);

# Try to get a lock. If it succeeds, run $cmd. Otherwise, sleep and try again.
# NOTE: when $limit goes out of scope, the lock is released
my $lock_id;
do {
	$lock_id = $limit->get_lock();
	if ( $lock_id ) {
		# Got one of the worker locks (ie. number $lock_id)
		# Execute the $cmd
		warn "PID $$ executing command: $cmd\n" if $args{verbose};
		unless ( 0 == system($cmd) ) {
			$limit->release_lock();
			die "COMMAND: $cmd\n Returned failure: $!\n";
		}
	}
	else {
		# Did not get a lock
		# Sleep and try again
		warn "PID $$ got none of the worker locks. Sleeping." if $args{verbose};
		sleep( $args{sleep} );
	}
} until ( $lock_id );
# lock released with $limit going out of scope here

sub getoptions {
	GetOptions( \%args,
		'command=s',
		'concurrent:i',
		'lockpath:s',
		'sleep:i',
		'verbose'
	) or pod2usage();
}

=head1 NAME

runparallel

=head1 DESCRIPTION

Runs command in parallel with other commands, up to n concurrently. Sleeps until a slot is available.

=head1 SYNOPSIS

  runparallel.pl --command='echo foo bar'

  runparallel.pl [--sleep=1] [--verbose] [--lockpath=/tmp/locks] [--concurrent=10] <--command=COMMAND>

  --command     command to execute
  --concurrent  maximum procs to run. Default 10. Multiple scripts using different MAX_PROCS on the same lock dir is NOT supported.
  --lockpath    where to create the lock file. Default /tmp/locks 
  --sleep       seconds to sleep before trying to obtain a lock again. Default 1
  --verbose     print basic status messages to STDERR. Default False

  Use the IPC::ConcurrencyLimit module to run at most --concurrent worker processes. Executes arguments as a call to system().

The STDOUT and STDERR of COMMAND is discarded

=head1 EXAMPLE

  for i in {0..12}; do perl runparallel.pl --command 'sleep 2 && echo proc $$ `date +"%H:%M:%S"`' --verbose & done

=head1 AUTHOR

Alastair Firth github:@afirth

=cut
