process KRAKEN2 {
    publishDir "${params.output_dir}", mode:'copy'
    tag "speciation of ${meta}"

    input:
    tuple val(meta), path(reads)
    val database

    output:
    tuple val(meta), path('*report.txt'), emit: kraken_report_ch
    path "versions.yml",                  emit: versions_ch

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta}"
    """
    # speciation step using kraken2
    kraken2 --db ${database} --threads $task.cpus --report ${prefix}.kraken2.report.txt --gzip-compressed ${prefix}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
   	 kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
       	 pigz: \$( pigz --version 2>&1 | sed 's/pigz //g' )
    END_VERSIONS
    """
}

process EXTRACT_TAXON_SPECIFIC_INFO {
    //publishDir "${params.output_dir}", mode:'copy'
    tag "extract $taxon from ${sample_id}.kraken.report.txt"


    input:
    tuple val(sample_id), path(kraken_report)
    val(taxon)


    output:
    path("*.${taxon}.kraken.txt"), emit: taxon_kraken_ch


    script:
    """

    echo "percentage\tcladeReads\ttaxonReads\ttaxRank\ttaxID\tspecies" > ${sample_id}.${taxon}.kraken.txt

    grep "\\s${taxon}\\s" ${kraken_report} >> ${sample_id}.${taxon}.kraken.txt

    """
}

process COMBINE_KRAKEN_REPORT_FROM_TAXA {
    publishDir "${params.output_dir}", mode:'copy'
    tag "combine kraken.report.txt for $taxon"


    input:
    path(kraken_taxon_report_files)
    val(taxon)
    val(date)


    output:
    path("combined_kraken_report_${taxon}_${date}.txt"), emit: kraken_comb_ch


    script:
    """
    KRAKEN_TAXON_REPORT_FILES=(${kraken_taxon_report_files})

    for index in \${!KRAKEN_TAXON_REPORT_FILES[@]}; do
    KRAKEN_TAXON_REPORT_FILE=\${KRAKEN_TAXON_REPORT_FILES[\$index]}
    sample_id=\${KRAKEN_TAXON_REPORT_FILE%.${taxon}.kraken.txt}

    # add header line if first file
    if [[ \$index -eq 0 ]]; then
      echo "samplename\t\$(head -1 \${KRAKEN_TAXON_REPORT_FILE})" >> combined_kraken_report_${taxon}_${date}.txt
    fi
    
    # awk -F '\\t' 'FNR>=2 { print FILENAME, \$0 }' \${KRAKEN_TAXON_REPORT_FILE} |  sed 's/\\.${taxon}\\.kraken\\.txt//g' >> combined_kraken_report_${taxon}_${date}.txt
    
    awk -v OFS='\\t' 'FNR>=2 { print FILENAME, \$0 }' \${KRAKEN_TAXON_REPORT_FILE} |  sed 's/\\.${taxon}\\.kraken\\.txt//g' >> combined_kraken_report_${taxon}_${date}.txt
    done

    """
}
