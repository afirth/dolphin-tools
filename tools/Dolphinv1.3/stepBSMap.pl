#!/usr/bin/env perl
use strict; use warnings;

use vars qw($VERSION); $VERSION = '0.0.1';  ## Current version of tis file
require  5.008;    ## requires this Perl version or later

#########################################################################################
#                                       stepBSMap.pl
#########################################################################################
#
#  This program runs BSMAP in RRBS mode
#
#
#########################################################################################
# AUTHORS:
#
# Alastair Firth
# Jun 18, 2015
# Alper Kucukural, PhD
# Jul 4, 2014
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

use File::Path qw(make_path);
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;  $Data::Dumper::Indent = 1;

#################### VARIABLES ######################

# default arguments
# using hash option of GetOpt, must declare optional args or check exists()
my %args = (
	'params'     => '',
	'verbose'    => 0,
);

################### PARAMETER PARSING ####################

GetOptions( \%args,
	'binpath=s',
	'digestion:s', #TODO we might want to support WGBS, in which case the argument checking should allow null here
	'dspaired=s',
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

#ref must exist and be .fasta
unless ( -e $args{ref} and ( $args{ref} =~ /.*\.(fa|fasta)/ )) {
	die ( "Invalid ref file $args{ref}" );
}

#binpath must exist and be executable
unless ( -e $args{binpath} and -x $args{binpath} ) {
	die ( "Invalid option binpath: location $args{binpath}" );
}

#digestion must be valid
unless ( exists $args{digestion} ) {
	warn ( "Warning, no digestion site specified, using WGBS mapping" );
	next;
	unless ( $args{digestion} =~ /[CGAT-]+/ ) {
		die ( "Invalid option digestion: site $args{digestion}" );
	}
}

#samtools must exist and be executable
unless ( -e $args{samtools} and -x $args{samtools} ) {
	die ( "Invalid option samtools: location $args{samtools}" );
}

unless ( exists $args{dspaired} and $args{dspaired} =~ /no|none|yes|paired/i ) {
  die ( "Invalid option dspaired [no|none|yes|paired]: $args{dspaired}" );
}


################### MAIN PROGRAM ####################
# run bsmap in RRBS mode

# Setup the output directory
my $binname = basename( $args{binpath} ); #the name of the binary we execute (bsmap here)
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

# Expecting paired or single end libraries?
my $spaired;
$spaired = 1 if ( $args{dspaired} =~ /yes|paired/i );
$spaired = 0 if ( $args{dspaired} =~ /no|none/i );
die "Bad option dspaired: $args{dspaired}" unless ( defined $spaired );

### Construct the file list ###
my %files;
opendir(my $dh, $inputdir) || die "can't opendir $inputdir: $!";
my @file_list = grep { /\.fastq/ } readdir($dh);
closedir $dh;
if ( $spaired ) {
  #create a hash of arrays { s1 => [s1.1.fq, s1.2.fq], s2 => [s2.1.fq],[s2.2.fq] ]
  foreach my $file ( @file_list ) {
    #DO NOT include .1 or .2 in the hash key
    m/(.*)\.([12])\.fastq/; #get the "bname" as $1 and use it as the hash key
    #order matters, so unshift if it's .1 and push if it's .2
    unshift @{ $files{$1} }, "$inputdir/$file" if ($2 == 1); #unshift the filename into the array $files{bname} => [filename.1.fastq ?,file2?]
    push @{ $files{$1} }, "$inputdir/$file" if ($2 == 2); #push the filename into the array $files{bname} => [?file1,? filename.2.fastq]
  }
}
else {
  #create a hash of filenames {s1.1 => inputdir/s1.1.fq, s1.2 => inputdir/s1.2.fq}
  foreach my $file ( @file_list ) {
    #DO INCLUDE .1 or .2 in the hash key, if present
    $file =~ m/(.*)\.fastq/; #get the "bname" as $1 and use it as the hash key
    push @{ $files{$1} }, "$inputdir/$file"; #push the filename into the array $files{bname} => [filename]
  }
}

### Run the jobs ###
foreach my $bname ( keys %files ) {
  if ( $spaired and ( scalar @{ $files{$bname} } != 2 ) ) {
    die "Expected paired files for $bname but found " . Dumper($files{$bname});
  }
  if ( ! $spaired and ( scalar @{ $files{$bname} } != 1 ) ) {
    die "Expected single file for $bname but found " . Dumper($files{$bname});
  }
  do_job( $bname, @{ $files{$bname} } );
}

sub do_job {
  my ($bname, $file1, $file2) = @_;

  #$file2 will be undef if not paired
  die "Invalid file (must be a regular file): $file1" if ( ! -f $file1 );
  die "Invalid file (must be a regular file): $file2" if ( $file2 and ! -f $file2 );


# construct the move command
# not implemented
# TODO this can be used to copy files to web dir
  my $mvcom = '';
# $mvcom .= "&& mv x y";


#construct the command
  my $logfile = "$bname.$binname.log";
  my $outfile = "$outdir/$bname.bam";
  my $com = $args{binpath};
  $com .= " -a $file1";
  $com .= " -b $file2" if ( $file2 ); #only for paired end libs
  $com .= " -o $outfile";
  $com .= " -d $args{ref}";
	$com .= " -D $args{digestion}" if ( exists $args{digestion} );
  $com .= " $args{params}" if ( exists $args{params} );
  $com .= " > $logfile 2>&1";
  $com .= " $mvcom";
#TODO sort and index using samtools
#BUG mcall will not function until data is sorted and indexed

  print "command: $com\n" if $args{verbose};

# construct the job submission command
# jobname = servicename_bname
  my $jobname = "$args{servicename}_$bname";

  my $job = qq($args{jobsubmit} -n $jobname -c "$com"); #TODO $com should be single quoted?
  print "job: $job\n" if $args{verbose};

# /share/pkg/moabs/1.3.2//bin/bsmap -a s1_r1.fq              -o wt_r1.bam   -d /share/data/umw_biocore/genome_data/mouse/mm10/mm10.fa  -R   -D C-CGG  -p 8  > moabs.bsmap.wt_r1.bam.log 2>&1

# run the job
  unless ( system ($job) == 0 ) {
    die "Error 25: Cannot run the job $job: $!";
  }
}

__END__


=head1 NAME

stepBSMap.pl

=head1 SYNOPSIS  

  stepBSMap.pl -binpath     bsmap binary path </path/to/bsmap>
               -digestion   restriction enzyme digestion site <C-CGG>
               -dspaired    paired end or single end <none|yes|paired>
               -jobsubmit   command to execute to submit job
               -outdir      output directory </output/directory/> 
               -params      additional optional bsmap params [bsmap params]
               -previous    previous step in pipeline
               -ref         reference sequences file <fasta>
               -samtools    samtools binary location
               -servicename service name to use in job name
               -verbose     print extra debugging output [boolean]
  
  stepBSMap.pl -help
  
  stepBSMap.pl -version
  
  For help, run this script with -help option.


=head1 OPTIONS

=head2 -binpath

bsmap binary path </path/to/bsmap>

=head2 -digestion

	restriction enzyme digestion site
	The argument to -D of bsmap. If multiple digestion sites are used, must specify more in -params
	e.g -D="C-CAA" -params="-D C-CGG"

=head2 -help

Display this documentation.

=head2 -jobsubmit

command to execute to submit job

=head2 -outdir

output directory </output/directory/> 

=head2 -params

additional optional bsmap params [bsmap params]

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

stepBSMap.pl TODO


=head1 ARGUMENTS

BSMAP arguments included for reference.

  -a  <str>   query file, FASTA/FASTQ/BAM format.  The input format will be auto-detected. (required)
  -b  <str>   query file b for pair end data, FASTA/FASTQ/BAM format.  The input format will be auto-detected. 
              if the input format is in BAM format, it should be the same as the file specified by "-a" option.
              BSMAP will read the two sets of reads w.r.t to the 0x40/0x80 flag in the input BAM file. 
              (required for pair-end mapping)
  -d  <str>   reference sequences file, FASTA format. (required)
  -o  <str>   output alignment file, if filename has .sam suffix, the output
              will be in SAM format, if the filename has .bam suffix, the output file
              be in sorted BAM file, and a filename.bai index file will be generated, 
              for other filename suffix the output is in BSP format. (required)
  -2  <str>   output alignment file for unpaired reads in pair end mapping, only used for BSP format output. 
              If the output format is specified in BAM/SAM format, this option will be ignored, all alignments will be 
              writen to one BAM/SAM output file specified by the "-o" option. 
              (required for pair-end mapping with BSP format output)
  -s  <int>   seed size, default=16, min=8, max=16. (WGBS mode)
              For RRBS mode, seed length is fixed to 12 and this command line option is neglected.
              longer seed size is faster, ~1.5 times faster with each additional nt
  -v  <int>   max number of mismatches allowed on a read, default=2, max=15, 
              usually this number should be around 10% of the read length.
  -w  <int>   max number of equal best hits to count, smaller will be faster, default=MAXHITS in makefile
  -q  <int>   quality threshold in trimming 3'end of reads, 0-40, default=0. (no trim)
  -z  <int>   base quality, default=33 [Illumina is using 64, Sanger Institute is using 33]
  -f  <int>   filter low-quality reads containing >n Ns, default=5
  -p  <int>   number of processors to use, default=1. The parallel performance scales well with 8 threads or less.
              For more than 8 threads, there might be no significant overall speed gain.
  -x  <int>   max insertion size for pair end mapping, default=500
  -m  <int>   min insertion size for pair end mapping, default=28
  -L  <int>   mapping the first N nucleotide of the read, default: 0 (map the whole read).
  -I  <int>   index interval (1~16), meaning the reference genome will be indexed every Nbp, default=4. (WGBS mode)
              For RRBS mode, index_interval is fixed to 1bp and this command line option is neglected.
              larger index interval uses memory, and slightly reduces mapping sensitivity. (~0.5% difference) 
              for human genome, -I 16 uses ~5GB, compared with ~9GB at the default -I 4.
  -A  <str>   set the adapter sequence(s) and trim from 3'end of reads, default=none, requires at least 4nt matched, no mismatch allowed.
              Multiple -A options could be specified to set more than one adapter sequences, i.e. in pair-end sequencing case. 
              default: none (no adapter trimming)
  -R          include the reference sequences as the XR:Z:<string> field in SAM output. default=do not include.
  -B  <int>   start from the Nth read or read pair, default: 1.
  -E  <int>   end at the Nth read or read pair, default: 4,294,967,295.
              Using -B and -E options user can specify part of the input file to be mapped, so that the input file 
              could be divided into several parts and mapped parallely over distributed system, without creating temporary files. 
  -D  <str>   set restriction enzyme digestion site and activate reduced representation bisulfite mapping mode (RRBS mode), 
              i.e. reads must be mapped to digestion sites, the digestion site must be palindromic, digestion position is marked by '-', 
              for example: '-D C-CGG' for MspI digestion.
              default: none, meaning whole genome shot gun mapping (WGBS mode).
  -S  <int>   seed for random number generation in selecting multiple hits.  default: 0 (seed set from system clock).
              other seed values generate pseudo random number based on read index number, so that mapping results are reproducible. 
  -n  [0,1]   set mapping strand information:
              -n 0: only map to 2 forward strands, i.e. BSW(++) and BSC(-+)    (i.e. the "Lister protocol")
              for PE sequencing, map read#1 to ++ and -+, read#2 to +- and --. 
              -n 1: map SE or PE reads to all 4 strands, i.e. ++, +-, -+, --    (i.e. the "Cokus protocol")
              default: -n 0. Most bisulfite sequencing data is generated only from forward strands.
  -M  <str>   set the alignment information for the additional nucleotide transition. <str> is in the form of two different nucleotides, 
              the first one in the reads could be mapped to the second one in the reference sequences.
              default: -M TC, corresponds to C=>U(T) transition in bisulfite conversion.
              example: -M GA could be used to detect to A=>I(G) transition in RNA editing. 
  -h          help


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


