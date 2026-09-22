#!/usr/bin/env perl

use strict;

use Getopt::Long;

my ($lineage, $cachedLineages, $outFile, $lineageMappersFile);
&GetOptions(
    "lineage=s" => \$lineage,
    "outFile=s" => \$outFile,
    "cached_lineages=s" => \$cachedLineages,
    "lineage_mappers=s" => \$lineageMappersFile
    );


# Overrides name a lineage, not a version; any _odbN[.N] suffix is ignored
# so the version is always resolved from the local cache.
open(MAP, $lineageMappersFile) or die "Cannot open $lineageMappersFile for reading: $!";

my %overrides;
while(<MAP>) {
    chomp;
    next if /^#/ || /^\s*$/;
    my ($taxon, $lineageOverride) = split(/\t/, $_);
    $lineageOverride =~ s/_odb\d+(\.\d+)?$//;
    $overrides{lc($taxon)} = lc($lineageOverride);
}

close MAP;


# Directory names under busco_downloads/lineages; keep the highest odb version per lineage
my %cached;

open(CACHE, $cachedLineages) or die "Cannot open file $cachedLineages for reading: $!";

while(<CACHE>) {
    chomp;
    next unless /^(\w+?)_odb(\d+)(?:\.(\d+))?$/;
    my ($name, $major, $minor) = (lc($1), $2, $3 || 0);

    my $current = $cached{$name};
    if(!$current || $major > $current->{major} || ($major == $current->{major} && $minor > $current->{minor})) {
        $cached{$name} = { dataset => $_, major => $major, minor => $minor };
    }
}
close CACHE;

open(FILE, $lineage) or die "Cannot open file $lineage for reading: $!";

my @taxa;

while(<FILE>) {
    chomp;
    push @taxa, lc($_);
}
close FILE;


my $chosen;
foreach my $taxon (reverse @taxa) {

    if(my $override = $overrides{$taxon}) {
        die "Override for '$taxon' maps to '$override' but no ${override}_odb* dataset exists in the BUSCO downloads cache\n"
            unless $cached{$override};
        $chosen = $cached{$override}->{dataset};
        last;
    }

    if($cached{$taxon}) {
        $chosen = $cached{$taxon}->{dataset};
        last;
    }
}


die "Could not determine a BUSCO lineage dataset from the local cache.  Download one or add an override to the lineage mapping file\n" unless($chosen);

open(OUT, ">$outFile") or die "Cannot open $outFile for writing: $!";
print OUT $chosen, "\n";

close OUT;
