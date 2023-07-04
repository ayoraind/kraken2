#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// include non-process modules
include { help_message; version_message; complete_message; error_message; pipeline_start_message } from './modules/messages.nf'
include { default_params; check_params } from './modules/params_parser.nf'
include { help_or_version } from './modules/params_utilities.nf'

version = '1.0dev'

// setup default params
default_params = default_params()
// merge defaults with user params
merged_params = default_params + params

// help and version messages
help_or_version(merged_params, version)
final_params = check_params(merged_params)
// starting pipeline
pipeline_start_message(version, final_params)


// include processes
include { KRAKEN2; EXTRACT_TAXON_SPECIFIC_INFO; COMBINE_KRAKEN_REPORT_FROM_TAXA } from './modules/processes.nf' addParams(final_params)


workflow  {
         reads_ch = channel
                          .fromPath( final_params.reads, checkIfExists: true )
                          .map { file -> tuple(file.simpleName, file) }


         KRAKEN2(reads_ch, final_params.database)

         EXTRACT_TAXON_SPECIFIC_INFO(KRAKEN2.out.kraken_report_ch, final_params.taxon)

         collected_kraken_taxon_ch = EXTRACT_TAXON_SPECIFIC_INFO.out.taxon_kraken_ch.collect( sort: {a, b -> a[0].getBaseName() <=> b[0].getBaseName()} )

         COMBINE_KRAKEN_REPORT_FROM_TAXA(collected_kraken_taxon_ch, final_params.taxon, final_params.sequencing_date)

}


workflow.onComplete {
    complete_message(final_params, workflow, version)
}

workflow.onError {
    error_message(workflow)
}
