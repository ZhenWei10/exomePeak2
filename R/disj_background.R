#' @title Find the background of the user provided modification.
#'
#' @param mod_gr A \code{GRanges} object of user provided modification (names are neccessary for the index of the splitting).
#' @param txdb A \code{TxDb} object that define the transcript modification.
#' @param background_bins A Granges object for background bins.
#' @param background_types A logical value, TRUE if the region of 5'UTR and long exons of the transcripts should be dropped in control region; Default TRUE.
#' @param control_width A integer for the minimum width of the control region returned; default 50.
#' @param rename_mod Whether to rename the returned modification sites, default = FALSE.
#' @return A \code{GRangesList} object.
#' The first portion is the exons regions that is not overlapped with \code{annoation}.
#'
#' If the resulting ranges have less number and width compared with what defined in \code{cut_off_num},
#' the exon regions of txdb will be returned as the background.
#'
#' The second portion is the reconstructed provided modification with gene id mod_grated.
#'
#' @import GenomicRanges
#' @import GenomicFeatures
#' @importFrom S4Vectors queryHits subjectHits
#' @keywords internal

disj_background <- function(mod_gr,
                            txdb,
                            background_bins = NULL,
                            background_types = c("Gaussian_mixture", "m6Aseq_prior", "manual", "all"),
                            control_width = 50,
                            rename_mod = FALSE) {

  background_types <- match.arg(background_types)

  exbyug <-
    exons_by_unique_gene(txdb)

  mcols(mod_gr) <- NULL

  mod_gr_tmp <- mod_gr

  ######################################################
  #              Prior background of m6A               #
  ######################################################

  if (background_types == "m6Aseq_prior") {

    utr5 <- unlist(fiveUTRsByTranscript(txdb))

    long_exon <- exons(txdb)

    long_exon <- long_exon[width(long_exon) >= 400]

    mcols(utr5) <- NULL

    mcols(long_exon) <- NULL

    mod_gr_tmp <- c(mod_gr_tmp, utr5, long_exon)

    rm(utr5, long_exon)

    disj_ranges <- disjoin(c(unlist(exbyug) , mod_gr_tmp))

    control_ranges <- subsetByOverlaps(disj_ranges,
                                       mod_gr_tmp,
                                       type = "any",
                                       invert = TRUE)

    control_ranges <- reduce(control_ranges)

  } else {

  ######################################################
  #          Background from subset of bins            #
  ######################################################

    bg_bins_tmp <- reduce(unlist(background_bins))

    mcols(bg_bins_tmp) <- NULL

    disj_ranges <- disjoin(c(bg_bins_tmp,
                             mod_gr_tmp))

    rm(bg_bins_tmp)

    control_ranges <- subsetByOverlaps(disj_ranges,
                                       mod_gr_tmp,
                                       type = "any",
                                       invert = TRUE)

    control_ranges <- reduce(control_ranges)
  }


  ######################################################
  #          Check criteria for background             #
  ######################################################

  control_ranges <-
    control_ranges[width(control_ranges) >= control_width]

    #Annotat the control with gene ids

    control_ranges$gene_id = NA

    fol <- findOverlaps(control_ranges, exbyug)

    control_ranges$gene_id[queryHits(fol)] = names(exbyug)[subjectHits(fol)]

    control_ranges = split(control_ranges,
                           seq_along(control_ranges))

    names(control_ranges) = paste0("control_", names(control_ranges))

  #organize the granges

  mod_gr$gene_id = NA
  fol <- findOverlaps(mod_gr, exbyug)
  mod_gr$gene_id[queryHits(fol)] = names(exbyug)[subjectHits(fol)]
  split_index <- names(mod_gr)
  names(mod_gr) <- NULL
  mod_grl <- split(mod_gr, split_index)

  if(rename_mod == TRUE)  names(mod_grl) <- seq_along(mod_grl)

  names(mod_grl) <- paste0("peak_", names(mod_grl))

  return(c(mod_grl, control_ranges))

}

