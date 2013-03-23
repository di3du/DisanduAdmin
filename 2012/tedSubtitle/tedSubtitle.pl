#!/usr/local/bin/perl
################################################################################
#  File: tedSubtitle.pl
#  Desscription: Get ted talk's subtitle from TED.com 
#                and convert subtitle of TED video to SRT format(SubRip Subtitle File)
#  Usage: ted.pl URL languageCode output.src 
#  Creator: Thinkhy
#  Date: 2011.04.30   
#  Online Doc: http://blog.csdn.net/thinkhy/article/details/6564434   
#  Last version of source code: https://gist.github.com/949659 
#  ChangeLog: 1 Add language code. [thinkhy 2011.05.06]
#             2 Read advertisement time from the parameter of introDuration in html.
#               If the time is not correct by intorDuratoin parameter,
#               you can set it up in the last argument of command line($ARGV[3]).    [thinkhy 2011.07.16]
#             3 Optimized code, add  code for checking command arguments. [thinkhy 2011.09.3]
#             4 Ajust Regexp for extraction of Adv. duration [thinkhy 2012.01.26]
#             5 Thanks to doyouwanna's bug report, fixed the problem of inaccurate advertisement duration which is due to  percent-encode in html. [thinkhy 2012.10.21]
#             6. Ted.com changed the vedio page recently, fixed the problem that failed to get talk id.  
#                Thanks to Xianglin  for reporting this problem. [thinkhy 3/23/2013]        
#
#  LanguageCode     Language  
#  alb              Albanian
#  ara              Arabic      
#  arm              Armenian
#  aze              Azerbaijani   
#  bul              Bulgarian        
#  bur              Burmese (Myanmar)
#  cat              Catalan
#  chi_hans         Chinese (Simplified)
#  chi_hant         Chinese (Traditional)
#  cze              Czech
#  dan              Danish
#  dut              Dutch
#  eng              English
#  epo              Esperanto
#  est              Estonian
#  fin              Finnish
#  fre_fr           French (France)
#  geo              Georgian
#  ger              German
#  gre              Greek
#  heb              Hebrew
#  hun              Hungarian
#  ind              Indonesian    
#  ita              Italian
#  jpn              Japanese
#  kor              Korean    
#  lav              Latvian
#  lit              Lithuanian
#  mac              Macedonian
#  may              Malay
#  nob              Norwegian, Bokm錶 (Bokmaal)
#  pol              Polish   
#  por_br           Portuguese (Brazil)
#  por_pt           Portuguese (Portugal)
#  rum              Romanian
#  rus              Russian
#  scc              Serbian
#  scr              Croatian
#  slo              Slovak
#  slv              Slovenian
#  swe              Swedish
#  spa              Spanish
#  tam              Tamil
#  tgl              Tagalog    
#  tha              Thai
#  tur              Turkish
#  ukr              Ukrainian
#  uzb              Uzbek
#  vie              Vietnamese
#
################################################################################
use strict;
use Data::Dumper;
use JSON;
use URI::Escape;

use LWP::Simple qw(get);


# check for argument number
my $argc = @ARGV;
if ($argc < 3)
{
    print "USAGE: ted.pl URL languageCode output.src\n";
    exit -1;
}

# Magic Number
my $durationOfAdv = 16000; #  seconds of Advertisement time(millisecond).
                           #  depends on talk year     

# Get content from file
# my $content = GetContentFromFile("back.json");

# The TED talk URL
my $url = $ARGV[0];
print "URL: $url\n";

# languageCode  
my $languageCode = $ARGV[1];

# output file of SRT format
my $outputFile = $ARGV[2];

# !!Note: What you should do is to write URL of TED talks here.
# my $url = "http://www.ted.com/talks/stephen_wolfram_computing_a_theory_of_everything.html";

print "Get html content from URL: $url\n";

open OUT, ">out.html";

# First of all, Get the talkID from the web page.
my $html = GetUrl($url);

#my $html = do { local( @ARGV, $/ ) = "out.html"; <> };
print OUT $html;

# Fixed the problem that failed to get talk id, it's because Ted.com changed the vedio page recently.
# Thanks to Xianglin for reporting this problem timely. [thinkhy 3/23/2013]        
$html =~ m/(?<=var talkDetails = \{"id":).*?(\d+)/g;

my $talkID = $1;
chomp($talkID);
die "Failed to extract talk ID." unless $talkID;

print "\ntalk ID: $talkID\n";
my ($talkYear) = $html =~ m/(?<=;year=)(\d+);/i;
#my $talkYear = $1;
print "\nSeems good, go on.\n";
chomp($talkYear);
print  "Talk year: $talkYear\n";

my $durationOfAdv = $ARGV[3];
if (!$durationOfAdv)
{
    if ($html =~ m/(?<="introDuration":)(\d+)\.?(\d+)?,/i)
    {
        $2 = 0 unless $2; 
        $durationOfAdv = $1*1000 + $2*10;
        #$durationOfAdv += 2500;
    }
    else
    {
        # print $html; # debug
        # Advertisement time depends on talk year. 
        if ($talkYear == 2005)
        {
            $durationOfAdv  = 15100;
        }
        elsif ($talkYear == 2009)
        {
#$durationOfAdv  = 18000;
            $durationOfAdv  = 15600;
        }
    }
}

print "Duration of advertisement: $durationOfAdv\n";

#/(?<=\t)\w+/ 
# print OUT $html;
print "Have gotten html content from URL: $url\n";

# Get subtitle content from TED.COM
my $subtitleUrl = "http://www.ted.com/talks/subtitles/id/$talkID/lang/$languageCode/format/text"; 
print "Subtitle URL: $subtitleUrl\n";
my $content = GetUrl($subtitleUrl);

#open DEBUG, ">out.json";
#print DEBUG $content;

# Decode JSON text
open SRT, ">$outputFile";
my $json = new JSON;
my $obj = $json->decode($content);

my $len = scalar(@{$obj->{captions}});
if ($len > 0)
{
    print "Subtitle line count: $len\n";
}
else
{
    print "NO valid subtitle found!\n";
}

printf "Done, enjoy. ";

my $startTime = $obj->{captions}->[10]->{startTime};
my $duration = $obj->{captions}->[10]->{duration};
my $subtitle = $obj->{captions}->[10]->{content};

my $cnt = 0;

#foreach my $element ($obj->{captions})
for (;$cnt < $len; $cnt++)
{
    #my %hash = %$element;
    my $startTime = $obj->{captions}->[$cnt]->{startTime};
    my $duration = $obj->{captions}->[$cnt]->{duration};
    my $subtitle = $obj->{captions}->[$cnt]->{content};

    OutputSrt(1+$cnt, $startTime, $duration, $subtitle);
} 

###########################################################
# Sub Functions
###########################################################
sub GetTime
{
    my ($time) = @_;

    my $mils = $time%1000;
    my $segs = int($time/1000)%60;
    my $mins = int($time/60000)%60;
    my $hors = int($time/3600000);

    return ($hors, $mins, $segs, $mils);
}

sub OutputSrt
{
    my ($orderNum, $startTime, $duration, $subtitle) = @_;

    # plus the duration of advertisement
    $startTime += $durationOfAdv;

    # Caculate endTime by duration
    my $endTime = $startTime + $duration; 

    my($hour, $minute, $second, $msecond) = GetTime($startTime); 

    print SRT "$orderNum\n"; # order number

    # Begin time
    print SRT $hour.":".$minute.":".$second.",$msecond";

    # delimitation
    print SRT " --> ";

    # End time
    my($hour1, $minute1, $second1) = GetTime($endTime); 
    print SRT $hour1.":".$minute1.":".$second1.",$msecond\n";

    # Subtitle
    print SRT "$subtitle\n\n";
}


sub GetContentFromFile
{
    my $file = shift; 
    my $content;

    open FILE, $file;  
    while(<FILE>) {
        $content .= "$_";
    }

    return $content;
}

# Test URL: http://www.ted.com/talks/subtitles/id/843/lang/eng/format/text
sub GetUrl
{
    my $url = shift;
    my $content = get($url) or die "Can't get $url\n";

    # Thanks to doyouwanna's bug report, 
    # fix the problem of inaccurate advertisement duration which is due to  percent-encode in html. [thinkhy 2012.10.21]
    my $encode = uri_unescape($content);

    return $encode;
}
