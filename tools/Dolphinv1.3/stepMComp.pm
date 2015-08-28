#!/usr/bin/env perl
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.0.1';  ## Current version of this file
require  5.008;    ## requires this Perl version or later

#########################################################################################
#                                       stepMComp.pl
#########################################################################################
#
#  This program runs MComp
#
#
#########################################################################################
# AUTHORS:
#
# Alastair Firth
# Jul 6, 2015
# Alper Kucukural, PhD
# Jul 4, 2014
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

use File::Path qw(make_path);
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
$Data::Dumper::Indent = 1;

#################### VARIABLES ######################

# default arguments
# using hash option of GetOpt, must declare optional args or check exists()
my %args = (
	'params'     => '',
	'verbose'    => 0,
);

################### PARAMETER PARSING ####################

#TODO pass binary specific options in params, not here. Call another module to validate params for each binpath
#ref
#
GetOptions( \%args,
	'binpath=s',
	'condition=s',
	'help',
	'jobsubmit=s',
	'outdir=s',
	'params:s',
	'previous=s',
	'ref=s',
	'samtools=s',
	'servicename=s',
	'verbose',
	'version',
) or pod2usage();

print "Arguments:\n" . Dumper(\%args) if ( $args{verbose} );

if ( exists $args{help} ) {
	pod2usage( {
			'-verbose' => 2,
			'-exitval' => 1,
		} );
}

if ( exists $args{version} ) {
	print "$0 version $VERSION\n";
	exit 0;
}


################### VALIDATE ARGS ####################

#outdir must already exist
unless ( -d $args{outdir} ) {
	die ( "Invalid output directory $args{outdir}: Directory must already exist" );
}

#if ref exists, must be .fasta
if ( exists $args{ref} ) {
	unless ( -e $args{ref} and ( $args{ref} =~ /.*\.(fa|fasta)/ )) {
		die ( "Invalid ref file $args{ref}" );
	}
}

#binpath must exist and be executable
unless ( -e $args{binpath} and -x $args{binpath} ) {
	die ( "Invalid option binpath: location $args{binpath}" );
}

#samtools must exist and be executable
unless ( -e $args{samtools} and -x $args{samtools} ) {
	die ( "Invalid option samtools: location $args{samtools}" );
}

################### MAIN PROGRAM ####################

# Setup the output directory
my $binname = basename( $args{binpath} ); #the name of the binary we execute
my $outdir = "$args{outdir}/".lc($binname);
make_path($args{outdir});

# Setup the input directory
# if this is the first step, it will be path/input/
# otherwise it will be path/previous/
my $inputdir;
if ($args{previous} =~ /NONE/) {
	$inputdir = "$outdir/input";
}
else {
	$inputdir = "$outdir/".lc( $args{previous} );
}

### Construct the file list ###
my %files;
opendir(my $dh, $inputdir) || die "can't opendir $inputdir: $!";
my @file_list = grep { /\.bed/ } readdir($dh);
closedir $dh;
#create a hash of filenames {s1.1 => inputdir/s1.1.bed, s1.2 => inputdir/s1.2.bed}
foreach my $file ( @file_list ) {
	m/(.*)\.bed/; #get the "bname" as $1 and use it as the hash key
	# each array should contain all files for that condition
	push @{ $files{$1} }, "$inputdir/$file"; #push the filename into the array $files{bname} => [filename]
}

### Run the jobs ###
# only one job (one bed file from each condition)
if ( scalar ( keys %files ) != 2 ) {
       die "Expected exactly two files, but got ", Dumper( \%files );
}
foreach my $bname ( keys %files ) {
	if ( scalar ( @{$files{$bname}} ) != 1 ) {
		die "Expected exactly one file for condition $bname but got ", Dumper( $files{$bname} );
	}
}

# name of the comparision file for mcomp (--compFile)
my $comparefile = join( '.', keys %files );
$comparefile .= 'comp.txt';

do_job( $comparefile, values %files );

sub do_job {
	my ($comparefile, @files) = @_;
	
	#construct and check the file list
	my $filelist = '';
	foreach my $file ( @files ) {
		die "Invalid file (must be a regular file): $file" if ( ! -f $file );
		$filelist .= " -r $file";
	}


# construct the move command
# not implemented
# TODO this can be used to copy files to web dir
	my $mvcom = '';
# $mvcom .= "&& mv x y";


#construct the command
	# e.g. mcomp -m ko_r1.bam -m ko_r2.bam --sampleName ko -p 4 -r hg19.fa
	my $logfile = "$bname.$binname.log";
	my $com = $args{binpath};
	$com .= " $filelist";
	$com .= " -c $comparefile";
	$com .= " $args{params}" if ( exists $args{params} );
	$com .= " > $logfile 2>&1";
	$com .= " $mvcom";
#TODO sort and index using samtools

	print "command: $com\n" if $args{verbose};

# construct the job submission command
# jobname = servicename_bname
	my $jobname = "$args{servicename}_$bname";

	my $job = qq($args{jobsubmit} -n $jobname -c "$com"); #TODO $com should be single quoted?
	print "job: $job\n" if $args{verbose};

# /share/pkg/moabs/1.3.2//bin/mcomp -r wt.G.bed -r ko.G.bed -c comp.wt.vs.ko.txt > moabs.mcomp.comp.wt.vs.ko.txt.log


# run the job
	unless ( system ($job) == 0 ) {
		die "Error 25: Cannot run the job $job: $!";
	}
}

__END__


=head1 NAME

stepMComp.pl

=head1 SYNOPSIS  

  stepMComp.pl -binpath     binary path </path/to/mcomp>
               -jobsubmit   command to execute to submit job
               -outdir      output directory </output/directory/> 
               -params      additional optional mcomp params [mcomp params]
               -previous    previous step in pipeline
               -ref         reference sequences file <fasta>
               -samtools    samtools binary location
               -servicename service name to use in job name
               -verbose     print extra debugging output [boolean]
  
  stepMComp.pl -help
  
  stepMComp.pl -version
  
  For help, run this script with -help option.


=head1 OPTIONS

=head2 -binpath

mcomp binary path </path/to/mcomp>

=head2 -help

Display this documentation.

=head2 -jobsubmit

command to execute to submit job

=head2 -outdir

output directory </output/directory/> 

=head2 -params

additional optional mcomp params [mcomp params]

=head2 -ref

reference sequences file <fasta>

=head2 -servicename

service name to use in constructing the job name

=head2 -verbose

print extra debugging output [0|1]

=head2 -version

Display the version

=head1 DESCRIPTION

This program does methylation comparision for RRBS


=head1 EXAMPLE

stepMComp.pl TODO


=head1 ARGUMENTS

For full MComp arguments, please see the MOABS readme.


=head1 AUTHORS

 Alastair Firth github:@afirth
 Alper Kucukural, PhD


=head1 LICENSE AND COPYING

 This program is free software; you can redistribute it and / or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, a copy is available at
 http://www.gnu.org/licenses/licenses.html


