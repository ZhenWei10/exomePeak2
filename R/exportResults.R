#' @title Export the (Differential) Modification Peaks/Sites and their associated Statistics
#' @param sep a \code{\link{SummarizedExomePeak}} object.
#' @param format a \code{character} for the exported format, could be a vector that contains \code{c("CSV", "BED", "RDS")}.
#'
#' \describe{
#'  \item{\strong{\code{CSV}}}{
#'  export a comma separated values (CSV) table with the genomic location and LFC statistics.
#'  }
#'
#'  \item{\strong{\code{BED}}}{
#'  export a BEDGraph file with the score column = -log2(adjusted p value).
#'  }
#'
#'  \item{\strong{\code{RDS}}}{
#'  export the RDS file of the \code{\link{SummarizedExperiment}} object.
#'  }
#' }
#'
#' @param save_dir a \code{character} for the name of the directory being saved; Default \code{= "exomePeak2_output"}.
#'
#' @param cut_off_pvalue a \code{numeric} value for the p value cutoff in the exported result; Default \code{= NULL}.
#'
#' @param cut_off_padj a \code{numeric} value for the adjusted p value cutoff in the exported result; Default \code{= 0.05}.
#'
#' @param cut_off_log2FC a \code{numeric} value for the log2 fold change cutoff of the exported result,
#' only the sites with abs(LFC) larger than this value are kept; Default \code{= 0}.
#'
#' @param min_num_of_positive a \code{numeric} value for the minimum number of reported sites.
#' If the number of remaining sites is less than this number after filtering, additional sites will be reported by the increasing order of the p value to meet this number.
#'
#' @param expected_direction a \code{character} for the expected differential modification direction, could be one in \code{c("hyper", "hypo", "both")}.
#'
#' \describe{
#'  \item{\strong{\code{hyper}}}{
#'  only report the peaks/sites with interactive LFC > 0.
#'  }
#'
#'  \item{\strong{\code{hypo}}}{
#'  only report the peaks/sites with interactive LFC < 0.
#'  }
#'
#'  \item{\strong{\code{both}}}{
#'  report the peaks/sites in both directions.
#'  }
#' }
#'
#' This argument is useful when the treated group involves the perturbation of a known writer or eraser protein; Default "both".
#'
#' @param inhibit_filter a \code{logical} of whether to remove all the filters, this option is useful when quantification on single based site annotation; Default \code{= FALSE}.
#'
#' @param table_style a \code{character} for the style of the CSV table being exported, could be one in \code{c("bed","granges")}.
#'
#' \describe{
#'  \item{\strong{\code{bed}}}{
#'  the genomic locations in the table are represented by BEDgraph style.
#'  }
#'
#'  \item{\strong{\code{granges}}}{
#'  the genomic locations in the table are represented by GRanges style.
#'  }
#' }
#'
#' @param reads_count a \code{logical} of whether to export the reads count for each sample; Default \code{ = TRUE}.
#'
#' @param GC_sizeFactors a \code{logical} of whether to export the GC content correction size factors; Default \code{ = TRUE}.
#'
#' @examples
#'
#' ### Load the example SummarizedExomPeak object
#' f1 = system.file("extdata", "sep_ex_mod.rds", package="exomePeak2")
#'
#' sep <- readRDS(f1)
#'
#' ### Save the modification peaks/sites statistics on the current directory.
#' exportResults(sep)
#'
#' @importFrom rtracklayer export
#' @import GenomicRanges
#'
#' @aliases exportResults
#'
#' @rdname exportResults-methods
#'
#' @return none, a folder will be saved on the disk.
#'
#' @export
#'

setMethod("exportResults",
          "SummarizedExomePeak",
          function(sep,
                   format = c("CSV", "BED", "RDS"),
                   table_style = c("bed", "granges"),
                   save_dir = "exomePeak2_output",
                   cut_off_pvalue = NULL,
                   cut_off_padj = 0.1,
                   cut_off_log2FC = 0,
                   min_num_of_positive = 100,
                   expected_direction = c("both", "hyper", "hypo"),
                   inhibit_filter = FALSE,
                   reads_count = TRUE,
                   GC_sizeFactors = TRUE) {

            #Check the input
            stopifnot(cut_off_pvalue <= 1 & cut_off_pvalue >= 0)
            stopifnot(cut_off_log2FC >= 0)
            stopifnot(all(format %in% c("CSV", "BED", "RDS")))
            table_style <- match.arg(table_style)
            expected_direction <- match.arg(expected_direction)

            #Create the saving directory
            if (!dir.exists(save_dir)) {
              dir.create(save_dir)
            }

            #Create the folder for the additional information
            if (!dir.exists(file.path(save_dir,"ADDInfo"))) {
              dir.create(file.path(save_dir,"ADDInfo"))
            }

            #Decide the file names
            if (!any(grepl("Diff",colnames(exomePeak2Results( sep ))))) {
              file_name <- "Mod"
            } else{
              file_name <- "DiffMod"
            }

            #Check if the users have calculated the log2FCs and their associated p-values
            if (nrow(exomePeak2Results(sep)) == 0) {
              if (any(sep$design_Treatment)) {
                sep <- glmDM(sep)
              } else{
                sep <- glmM(sep)
              }
            }

            #Generate row index for the exported modification in SummarizedExomePeak
            if (inhibit_filter) {

              #Do not filter the rows on modification
              index_keep <- T

            } else {

            if (!any(grepl("Diff",colnames(exomePeak2Results( sep ))))) {

              #Decide the filter on modification
              decision_mod <- decision_deseq2(
                Inf_RES = exomePeak2Results(sep),
                log2FC_cut = cut_off_log2FC,
                P_cut = cut_off_pvalue,
                Padj_cut = cut_off_padj,
                Min_mod = min(min_num_of_positive, nrow(exomePeak2Results(sep)))
              )

              #P.S. If no sites are reported, export all the p values that are not NA
              index_keep <-
                which(
                  (exomePeak2Results(sep)[[decision_mod$Cut_By_expected]] <= decision_mod$Cut_Val_expected) &
                    (exomePeak2Results(sep)$log2FoldChange > cut_off_log2FC)
                )

            } else {

              #Decide the filter on differential modification

              decision_dm <- decision_deseq2(
                Inf_RES = exomePeak2Results(sep),
                log2FC_cut = cut_off_log2FC,
                P_cut = cut_off_pvalue,
                Padj_cut = cut_off_padj,
                Min_mod = min_num_of_positive,
                Exp_dir = expected_direction
              )

              if (expected_direction == "both") {
                indx_es <-
                  (abs(exomePeak2Results(sep)$log2FoldChange) > cut_off_log2FC)
              } else {
                if (expected_direction == "hyper") {
                  indx_es <- (exomePeak2Results(sep)$log2FoldChange > cut_off_log2FC)
                } else {
                  indx_es <- (exomePeak2Results(sep)$log2FoldChange < -1 * cut_off_log2FC)
                }
              }

              index_keep <-
                which(exomePeak2Results(sep)[[decision_dm$Cut_By_expected]] < decision_dm$Cut_Val_expected & indx_es)


              if (length(index_keep) == min_num_of_positive) {
                warning(paste0("The number of significantly differentially modified sites < ",min_num_of_positive,", the insignificantly differentially modified sites are reported to reach the minimum site number of ",min_num_of_positive,"; to report the differential modification status on all modification sites, please set 'inhibit_filter = TRUE.'\n"))
              }
            }
            }

            #Subset the SummarizedExomePeak object according to user defined filters
            sep <- sep[grepl("peak_", rownames(sep)),][index_keep,]

            exomePeak2Results(sep) <- exomePeak2Results(sep)[grepl("peak_", rownames(sep)),][index_keep,]
            
            sep <- sort_sep(sep)
            
            id_num <- as.numeric(gsub("^.*_", "", rownames(sep)))

            id_index <- order(id_num)

            sep <- sep[id_index,]

            exomePeak2Results(sep) <- exomePeak2Results(sep)[id_index,]
            
            sep <- sort_sep(sep)

            rownames(sep) <- paste0("peak_", rep(seq_along(id_num), table(id_num[id_index])))

            rm(id_num, id_index)

            if (any(format == "RDS")) saveRDS(sep, file.path(save_dir, paste0(file_name, ".rds")))

            result_grl <- rowRanges(sep)

            result_stat <- exomePeak2Results(sep)

            #Correct the names in the resulting files
            result_gr <- unlist(result_grl)
            result_gr$gene_id <- gsub("\\.[0-9]*$", "", result_gr$gene_id)
            rownames(result_stat) = NULL

            #Generate the GRangesList file that is ready to export
            indx_split <- names(result_gr)
            names(result_gr) <- NULL
            result_gr$gene_id[is.na(result_gr$gene_id)] <- " "
            result_grl <- split(result_gr, indx_split)
            #reorder the list
            result_grl <- result_grl[order(as.numeric(gsub("^.*_", "", names(result_grl))))]
            mcols(result_grl) <- result_stat
            rm(result_gr,result_stat,indx_split)

            id_num <- as.numeric(gsub("^.*_", "", names(result_grl)))
            id_index <- order(id_num)
            renamed_id <- paste0("peak_", rep(seq_along(id_num), table(id_num[id_index])))
            result_grl <- result_grl[id_index,]
            names(result_grl) <- renamed_id

            #Generate the tables according to the style choices
                if (table_style == "granges") {
                  result_df <- as.data.frame(result_grl)
                  result_df <-
                    result_df[, colnames(result_df) != "group"]
                  colnames(result_df)[colnames(result_df) == "group_name"] = "peak_name"
                  colnames_range_info <- colnames(result_df)
                  result_df <-
                    cbind(result_df, as.data.frame(mcols(result_grl))[rep(seq_along(result_grl), elementNROWS(result_grl)),])
                  site_widths <- sum(width(result_grl[rep(seq_along(result_grl), elementNROWS(result_grl))]))

                } else {

                  scores <- -1 * log2(mcols(result_grl)$padj)
                  scores[is.na(scores)] <- 0
                  mcols(result_grl)$score <- scores

                  export(
                    object = result_grl,
                    con = file.path(save_dir, paste0(file_name, ".bed")),
                    format = "BED"
                  )

                  result_df <- read.table(file.path(save_dir, paste0(file_name, ".bed")),
                               header = F,
                               sep = "\t")

                  colnames(result_df) <- c(
                    "chr",
                    "chromStart",
                    "chromEnd",
                    "name",
                    "score",
                    "strand",
                    "thickStart",
                    "thickEnd",
                    "itemRgb",
                    "blockCount",
                    "blockSizes",
                    "blockStarts"
                  )

                  result_df$geneID <- vapply( result_grl, function(x) x$gene_id[1] , character(1))

                  colnames_range_info <- colnames(result_df)

                  mcols(result_grl) <- mcols(result_grl)[,!colnames(mcols(result_grl)) %in% "score"]

                  site_widths <- sum(width(result_grl))

                  result_df <- cbind(result_df , as.data.frame(mcols(result_grl)))

                }


            #Retrieve the index for columns
            indx_range_info <- colnames(result_df) %in% colnames_range_info
            indx_reads_count <- grepl("ReadsCount",colnames(result_df))
            indx_major_stat <- colnames(result_df) %in% c("log2FoldChange","pvalue","padj")

            #Export the estimates and statistics of all GLM design
            write.csv(
              result_df[,!(indx_reads_count|indx_major_stat|indx_range_info)],
              file = file.path(save_dir, "ADDInfo", "ADDInfo_GLM_allDesigns.csv")
            )

            #Report a matrix of RPKM
            rpkm_df <- result_df[,indx_reads_count]
            rpkm_df <- t(t((rpkm_df/(site_widths/1e3)))/colSums(rpkm_df))
            colnames(rpkm_df) <- gsub("ReadsCount","RPKM",colnames(rpkm_df))

            write.csv(
              rpkm_df,
              file = file.path(save_dir, "ADDInfo", "ADDInfo_RPKM.csv")
            )

            if (!any(grepl("Diff", colnames(exomePeak2Results(sep))))){

              result_df <- result_df[,indx_range_info|indx_reads_count|indx_major_stat]

            } else {

              result_df <- result_df[,indx_range_info|indx_reads_count|indx_major_stat|colnames(result_df) %in% c("log2fcMod.Control.MLE","log2fcMod.Treated.MLE")]

              colnames( result_df )[colnames(result_df) %in% c("log2fcMod.Control.MLE",
                                                             "log2fcMod.Treated.MLE",
                                                             "log2FoldChange")] <- c("ModLog2FC_control",
                                                                                     "ModLog2FC_treated",
                                                                                     "DiffModLog2FC")
            }

            if (any(format == "CSV")) write.csv(x = result_df,
                                                file = file.path(save_dir,
                                                                 paste0(file_name, ".csv")),
                                                row.names = FALSE
                                                )

                scores <- -1 * log2(mcols(result_grl)$padj)

                scores[is.na(scores)] <- 0

                mcols(result_grl)$score <- scores

          if (any(format == "BED")) export(
                  object = result_grl,
                  con = file.path(save_dir, paste0(file_name, ".bed")),
                  format = "BED"
                )

          if (reads_count) write.csv(x = assays(sep)[[1]],
                                     file = file.path(save_dir,"ADDInfo","ADDInfo_ReadsCount.csv")
                                     )


          if (!is.null(GCsizeFactors(sep))&
                       GC_sizeFactors) write.csv(
                                          x = assays(sep)[[2]],
                                          file = file.path(save_dir,"ADDInfo","ADDInfo_SizeFactors.csv")
                                          )

message(paste0("Result files have been saved in the directory: '", file.path(save_dir)), "'.")

})
