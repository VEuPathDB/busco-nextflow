#!/usr/bin/env perl
# Run with: prove tests/

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use FindBin;

my $script = "$FindBin::Bin/../bin/chooseLineage.pl";
my $dir = tempdir(CLEANUP => 1);

sub writeFile {
    my ($name, @lines) = @_;
    my $path = "$dir/$name";
    open(my $fh, '>', $path) or die $!;
    print $fh map { "$_\n" } @lines;
    close $fh;
    return $path;
}

sub choose {
    my ($taxa, $cached, $map) = @_;
    my $out = "$dir/out.txt";
    unlink $out;
    my $err = `perl $script --lineage $taxa --cached_lineages $cached --lineage_mappers $map --outFile $out 2>&1`;
    return (undef, $err) if $?;
    open(my $fh, '<', $out) or die $!;
    chomp(my $chosen = <$fh>);
    return ($chosen, $err);
}

my $cached = writeFile('cached.txt', qw(
    eukaryota_odb12 euglenozoa_odb12 euglenozoa_odb12.2 aconoidasida_odb12
    fungi_odb10 fungi_odb12 README));
my $map = writeFile('map.txt', "# comment", "plasmodium\taconoidasida", "trypanosoma\teuglenozoa_odb12",
    "cryptosporidium\tcoccidia");

my $trypanosomatid = writeFile('t1.txt', qw(Eukaryota Discoba Euglenozoa Kinetoplastea Trypanosomatidae Phytomonas));
is((choose($trypanosomatid, $cached, $map))[0], 'euglenozoa_odb12.2', 'direct match resolves highest cached version');

my $trypanosoma = writeFile('t2.txt', qw(Eukaryota Euglenozoa Trypanosoma));
is((choose($trypanosoma, $cached, $map))[0], 'euglenozoa_odb12.2', 'override version suffix is ignored in favor of cache');

my $plasmodium = writeFile('t3.txt', qw(Eukaryota Apicomplexa Aconoidasida Haemosporida Plasmodium));
is((choose($plasmodium, $cached, $map))[0], 'aconoidasida_odb12', 'override resolves to only cached version');

my $fungus = writeFile('t4.txt', qw(Eukaryota Fungi));
is((choose($fungus, $cached, $map))[0], 'fungi_odb12', 'higher odb major wins');

my $crypto = writeFile('t5.txt', qw(Eukaryota Apicomplexa Cryptosporidium));
my ($chosen, $err) = choose($crypto, $cached, $map);
ok(!defined $chosen, 'override to uncached lineage fails');
like($err, qr/coccidia/, 'failure names the missing lineage');

my $bacterium = writeFile('t6.txt', qw(Bacteria Proteobacteria));
ok(!defined((choose($bacterium, $cached, $map))[0]), 'no cached match fails');

done_testing();
