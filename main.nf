#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

genome_ch = channel.fromPath( params.input + "/" + params.genomeFileName)
protein_ch = channel.fromPath( params.input + "/" + params.proteinFileName)

process lineageFromTaxon {
  container = 'veupathdb/edirect:1.0.0'
  input:
    val taxonId

  output:
    path 'taxa.txt'

  script:
    """
    efetch -db taxonomy -id $taxonId -format xml \
    | xtract -pattern Taxon -block LineageEx -sep "\n" -element ScientificName >taxa.txt
    """
}

process buscoLineageDatasets {
    container "ezlabgva/busco:v5.8.2_cv1"

    output:
    path("lineage_datasets.txt")

    script:
    """
    busco --list-datasets  >lineage_datasets.txt
    """
}


process genome {
    container "ezlabgva/busco:v5.8.2_cv1"

    publishDir params.outDir, mode: 'copy'    
    
    input:
    path(fasta)
    path(lineageDataset)

    output:
    path("busco_genome.txt")

    script:
    """
    ld=\$(< $lineageDataset)
    busco -i $fasta -o busco_output -l \$ld -m genome -c 4 --offline --download_path /busco_downloads
    ln -s busco_output/*.txt busco_genome.txt
    """
}


process protein {
    container "ezlabgva/busco:v5.8.2_cv1"

    publishDir params.outDir, mode: 'copy'
    
    input:
    path(fasta)
    path(lineageDataset)

    output:
    path("busco_protein.txt")

    script:
    """
    ld=\$(< $lineageDataset)
    busco -i $fasta -o busco_output -l \$ld -m proteins -c 4  --offline --download_path /busco_downloads
    ln -s busco_output/*.txt busco_protein.txt
    """
}


process bestLineageDataset {
    container 'perl:bookworm'

    input:
    path(lineage)
    path(buscoLineageDatasets)
    path(lineageMappingFile)

    output:
    path("best_lineage_dataset.txt")

    script:
    """
    chooseLineage.pl --busco_lineages $buscoLineageDatasets --lineage $lineage --outFile best_lineage_dataset.txt --lineage_mappers $lineageMappingFile
    """
}

workflow {
    lineage = lineageFromTaxon(params.ncbiTaxId)
    buscoLineageDatasets = buscoLineageDatasets()

    lineageDataset = bestLineageDataset(lineage, buscoLineageDatasets, params.lineageMappingFile)
    
    genome(genome_ch, lineageDataset)
    protein(protein_ch, lineageDataset)
}

