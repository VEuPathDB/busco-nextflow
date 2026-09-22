# busco-nextflow

A Nextflow pipeline that runs [BUSCO](https://busco.ezlab.org/) genome and proteome completeness assessments, automatically selecting the appropriate BUSCO lineage dataset from an organism's NCBI taxonomy.

## Overview

This pipeline assesses genome (and, optionally, protein-set) completeness by scoring the presence of lineage-specific single-copy orthologs with BUSCO. Rather than requiring a lineage dataset to be specified manually, it looks up the full NCBI taxonomic lineage for a given taxon ID, cross-references it against a table of taxon-to-BUSCO-lineage mappings, and picks the most specific matching dataset. It then runs BUSCO in `genome` mode against the assembly and, unless skipped, in `proteins` mode against the annotated protein set. Within VEuPathDB's genomic data workflows, this provides an automated quality-control metric for genome assemblies and annotations as they are loaded and updated.

## Requirements

- [Nextflow](https://www.nextflow.io/) (DSL2)
- Docker or Singularity/Apptainer — processes run in the `veupathdb/edirect:1.0.0`, `ezlabgva/busco:v5.8.2_cv1`, and `perl:bookworm` container images (select the engine via the `docker` or `singularity` profile/config in `conf/`)
- Network access for NCBI E-utilities lookups
- A pre-populated BUSCO downloads cache (`buscoDownloadsDir/lineages/<name>_odbN[.N]`) containing every lineage the pipeline may select; see `tests/` for chooser behavior (`prove tests/`)

## Usage

```
nextflow run VEuPathDB/busco-nextflow -r main \
  --ncbiTaxId 5833 \
  --genomeFile /path/to/genome.fasta \
  --proteinFile /path/to/annotatedProteins.fasta \
  --outDir /path/to/results \
  -C conf/docker.config \
  -resume
```

The pipeline has a single (default) entry point:

1. `lineageFromTaxon` fetches the NCBI taxonomic lineage for `params.ncbiTaxId` using EDirect (`efetch`/`xtract`).
2. The workflow lists the lineage datasets present in `${buscoDownloadsDir}/lineages`. BUSCO runs `--offline`, so only cached datasets are candidates.
3. `bestLineageDataset` (via `bin/chooseLineage.pl`) walks the taxonomic lineage from most to least specific and picks the first rank with either an override in `lineage_dataset_map.txt` or a matching cached dataset. When several versions of a lineage are cached (e.g. `_odb12` and `_odb12.2`), the highest is used.
4. `genome` runs `busco -m genome` against `params.genomeFile` using the chosen lineage dataset.
5. `protein` runs `busco -m proteins` against `params.proteinFile`, unless `params.skipProteomeAnalysis` is `true`.

## Key Parameters

| Parameter | Default | Description |
|---|---|---|
| `ncbiTaxId` | `5833` | NCBI taxonomy ID of the organism being assessed; drives automatic lineage dataset selection |
| `genomeFile` | `input/PlasmoDB-68_Pfalciparum3D7_Genome.fasta` | Genome assembly FASTA to run BUSCO against in genome mode |
| `proteinFile` | `input/PlasmoDB-68_Pfalciparum3D7_AnnotatedProteins.fasta` | Annotated protein FASTA to run BUSCO against in protein mode |
| `skipProteomeAnalysis` | `false` | Skip the protein-mode BUSCO run and only assess the genome |
| `lineageMappingFile` | `lineage_dataset_map.txt` | Tab-delimited file mapping lowercase taxon names to BUSCO lineage names (no `_odb` version; it is resolved from the cache), used when a taxon has no directly matching dataset. An override pointing at an uncached lineage fails the run |
| `buscoDownloadsDir` | `busco_downloads` | Local BUSCO downloads cache; its `lineages/` subdirectory is the source of truth for dataset selection |
| `outDir` | `results` | Directory the BUSCO summary output files are published to |

## Output

- `busco_genome.txt` — BUSCO short summary for the genome assembly, published to `outDir`
- `busco_protein.txt` — BUSCO short summary for the protein set, published to `outDir` (omitted if `skipProteomeAnalysis` is `true`)

Each summary reports counts of complete (single-copy and duplicated), fragmented, and missing BUSCOs against the selected lineage dataset.
