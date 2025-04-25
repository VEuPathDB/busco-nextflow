#!/usr/bin/env perl

use strict;

use Getopt::Long;
use Data::Dumper;

my ($lineage, $buscoLineageDatasets, $outFile);
&GetOptions(
    "lineage=s" => \$lineage,
    "outFile=s" => \$outFile,
    "busco_lineages=s" => \$buscoLineageDatasets
    );

my %overrides;
while(<DATA>) {
    chomp;
    next if/^#/;
    my ($taxon, $lineageDatasetOverride) = split(/,/, $_);
    $overrides{$taxon} = $lineageDatasetOverride;
}

my %buscoDatasets;

open(BUSCO, $buscoLineageDatasets) or die "Cannot open file $buscoLineageDatasets for reading: $!";

while(<BUSCO>) {
    chomp;
    my ($buscoLineageDataset) = /^\s*\-\s*([^\[\(\s]+)/;

    my ($t, $j) = split("_", $buscoLineageDataset);
    $buscoDatasets{$t} = $buscoLineageDataset;
    
}
close BUSCO;

open(FILE, $lineage) or die "Cannot open file $lineage for reading: $!";

my @taxa;

while(<FILE>) {
    chomp;
    push @taxa, lc($_);
}
close FILE;


my $chosen;
foreach my $taxon (reverse @taxa) {
    print $taxon . "\n";

    if($overrides{$taxon}) {
        $chosen = $overrides{$taxon};
        last;
    }

    if($buscoDatasets{$taxon}) {
        $chosen = $buscoDatasets{$taxon};
        last;
    }
}



die "Could not determine a busco Lineage dataset.  You can provide an override by updating the 'chooseLineage.pl' script" unless($chosen);

open(OUT, ">$outFile") or die "Cannot open $outFile for writing: $!";
print OUT $chosen, "\n";

close OUT;

__DATA__
# here we can list special cases
someTaxon,someLineageDataset
someOtherTaxon,someOtherLineageDataset
