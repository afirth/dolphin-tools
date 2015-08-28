#!/usr/bin/env perl
use strict;
use warnings;

use vars qw($VERSION);
$VERSION = '0.0.1';  ## Current version of this file
require  5.008;    ## requires this Perl version or later

#########################################################################################
#                                       stepMCall.pl
#########################################################################################
#
#  This program runs MCall
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
my @file_list = grep { /\.bam/ } readdir($dh);
closedir $dh;
#create a hash of filenames {s1.1 => inputdir/s1.1.bam, s1.2 => inputdir/s1.2.bam}
foreach my $file ( @file_list ) {
	m/(.*)\.bam/; #get the "bname" as $1 and use it as the hash key
	# each array should contain all files for that condition
	push @{ $files{$1} }, "$inputdir/$file"; #push the filename into the array $files{bname} => [filename]
}

### Run the jobs ###
foreach my $bname ( keys %files ) {
  do_job( $bname, $files{$bname} );
}

sub do_job {
  my ($bname, @files) = @_;
	
	#construct and check the file list
	my $filelist = '';
	foreach my $file ( @files ) {
		die "Invalid file (must be a regular file): $file" if ( ! -f $file );
		$filelist .= " -m $file";
	}


# construct the move command
# not implemented
# TODO this can be used to copy files to web dir
  my $mvcom = '';
# $mvcom .= "&& mv x y";


#construct the command
	# e.g. mcall -m ko_r1.bam -m ko_r2.bam --sampleName ko -p 4 -r hg19.fa
  my $logfile = "$bname.$binname.log";
  my $com = $args{binpath};
  $com .= " $filelist";
	$com .= " --sampleName $bname";
  $com .= " -r $args{ref}";
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

# /share/pkg/moabs/1.3.2//bin/mcall  -m wt_r1.bam   -m wt_r2.bam    -r /share/data/umw_biocore/genome_data/mouse/mm10/mm10.fa  -p 8  --sampleName wt > moabs.mcall.wt.log

# run the job
  unless ( system ($job) == 0 ) {
    die "Error 25: Cannot run the job $job: $!";
  }
}

__END__


=head1 NAME

stepMCall.pl

=head1 SYNOPSIS  

  stepMCall.pl -binpath     binary path </path/to/mcall>
               -jobsubmit   command to execute to submit job
               -outdir      output directory </output/directory/> 
               -params      additional optional mcall params [mcall params]
               -previous    previous step in pipeline
               -ref         reference sequences file <fasta>
               -samtools    samtools binary location
               -servicename service name to use in job name
               -verbose     print extra debugging output [boolean]
  
  stepMCall.pl -help
  
  stepMCall.pl -version
  
  For help, run this script with -help option.


=head1 OPTIONS

=head2 -binpath

mcall binary path </path/to/mcall>

=head2 -help

Display this documentation.

=head2 -jobsubmit

command to execute to submit job

=head2 -outdir

output directory </output/directory/> 

=head2 -params

additional optional mcall params [mcall params]

=head2 -ref

reference sequences file <fasta>

=head2 -servicename

service name to use in constructing the job name

=head2 -verbose

print extra debugging output [0|1]

=head2 -version

Display the version

=head1 DESCRIPTION

This program maps the reads from RRBS


=head1 EXAMPLE

stepMCall.pl TODO


=head1 ARGUMENTS

MCall arguments included for reference.

	help,h		Produce help message. Common options are provided with single letter format. Parameter defaults are in brackts. Ex- ample command: mCall -m Ko.bam; mCall -m wt_r1.bam -m wt_r2.bam -sampleName Wt; See doc for more details.)
	mappedFiles,m		Specify the names of RRBS/WGBS alignment files for methylation calling. Multiple files can be provided to com- bine them(eg. lanes or replicates) into a single track;
	sampleName		If two or more mappedFiles are specifed, this option gener- ates a merged result; Ignored for one input file;
	outputDir		The name of the output directory;
	webOutputDir		The name of the web-accessible output directory for UCSC Genome Browser tracks;
	genome,g		The UCSC Genome Browser identifier of source genome as- sembly; mm9 for example;
	reference,r		Reference DNA fasta file; It’s required if CHG methylation is wanted;
	cytosineMinScore		Threshold for cytosine quality score (default: 20). Discard the base if threshold is not reached;
	nextBaseMinScore		Threshold for the next base quality score(default: 3,ie, bet- ter than B or #); Possible values: -1 makes the program not to check if next base matches reference; any positive integer or zero makes the program to check if next base matches reference and reaches this score threshold;
	reportSkippedBase		Specify if bases that are not accepted for methylation anal- ysis should be written to an extra output file;
	qualityScoreBase		Specify quality score system: 0 means autodetec- tion; Sanger=>33;Solexa=>59;Illumina=>64; See wiki FASTQ_format for details;
	trimWGBSEndRepairPE2Seq		How to trim end-repair sequence from begin of +-/-- reads from Pair End WGBS Sequencing; 0: no trim; n(positive in- teger): trim n bases from begin of +-/-- reads; -2: model de- termined n; -1: trim from beginning to before 1st methylated C; Suggest 3; n>readLen is equivalent to use PE1 reads;
	trimWGBSEndRepairPE1Seq		How to trim end-repair sequence from end of ++/-+ reads from Pair End WGBS Sequencing; 0: no trim; n(positive integer): trim n + NM bases from end of ++/-+ reads if fragSize <= maxReadLen; -2: model determined n; Suggest 3;
	processPEOverlapSeq		1/0 makes the program count once/twice the overlap seq of two pairs;
	trimRRBSEndRepairSeq		How to trim end-repair sequence for RRBS reads; RRBS or WGBS protocol can be automatically detected; 0: no trim; 2: trim the last CG at exactly end of ++/-+ reads and trim the first CG at exactly begin of +-/-- reads like the WGBS situation;
	skipRandomChrom		Specify whether to skip random and hadrop chrom;
	requiredFlag,f		Requiring samtools flag; 0x2(properly paried), 0x40(PE1), 0x80(PE2), 0x100(not unique), r=0x10(reverse); Examples: -f 0x10 <=> +-/-+ (Right) reads; -f 0x40 <=> ++/-+ (PE1) reads; -f 0x50 <=> -+ read; -f 0x90 <=> +- read;
	excludedFlag,F		Excluding samtools flag; Examples: -f 0x2 -F 0x100 <=> uniquely mapped pairs; -F 0x10 <=> ++/-- (Left) reads; -F 0x40 <=> -f 0x80 +-/-- (PE2) reads; -f 0x40 -F 0x10 <=> ++ read; -f 0x80 -F 0x10 <=> -- read;
	minFragSize		Requiring min fragment size, the 9th field in sam file; Since non-properly-paired read has 0 at 9th field, setting this op- tion is requiring properly paired and large enough fragment size;
	minMMFragSize		Requiring min fragment size for multiply matched read; Same as option above but only this option is only applicable to reads with flag 0x100 set as 1;
	reportCpX		po::value<char>()->default_value(’G’), "X=G generates a file for CpG methylation; A/C/T generates file for CpA/CpC/CpT meth;
	reportCHX		po::value<char>()->default_value(’X’), "X=G generates a file for CHG methylation; A/C/T generates file for CHA/CHC/CHT meth; This file is large;
	fullMode,a		Specify whether to turn on full mode. Off(0): only *.G.bed, *.HG.bed and *_stat.txt are allowed to be generated. On(1): file *.HG.bed, *.bed, *_skip.bed, and *_strand.bed are forced to be generated. Extremely large files will be generated at fullMode.
	statsOnly		Off(0): no effect. On(1): only *_stat.txt is generated.
	keepTemp		Specify whether to keep temp files;
	threads,p		Number of threads on all mapped file. Suggest 1sim8 on EACH input file depending RAM size and disk speed.


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


