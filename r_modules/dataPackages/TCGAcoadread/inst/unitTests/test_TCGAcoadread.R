library(RUnit)
library(TCGAcoadread)
library(R.utils)
library(org.Hs.eg.db)
Sys.setlocale("LC_ALL", "C")
  ## to prevent issues with different sort calls (3/3/15)
#--------------------------------------------------------------------------------
printf <- function(...) print(noquote(sprintf(...)))
#--------------------------------------------------------------------------------
runTests <- function()
{
    # first tests are concerned with reading, parsing, and transforming
    # data to -create- a TCGAcoadread data package

  printf("=== test_TCGAcoadread.R, runTests()")
  testConstructor();
  testManifest()
  testCopyNumber()
  testHistoryList()
  testHistoryTable()
  testExpression()
  testMutation() 
  testMethylation() 
  testProteinAbundance() 

    # the following tests address the -use- of this class by client code

  testMatrixAndDataframeAccessors()
  testCanonicalizePatientIDs()
  
} # runTests
#--------------------------------------------------------------------------------
testConstructor <- function()#
{
   printf("--- testConstructor")

   dp <- TCGAcoadread();
   checkEquals(ncol(manifest(dp)), 11)
   checkTrue(nrow(manifest(dp)) >= 8)
   checkTrue(length(matrices(dp)) >= 4)
   expected.matrices <- c("mtx.cn", "mtx.mut", "mtx.prot", "mtx.mrna")
   checkTrue(all(expected.matrices %in% names(matrices(dp))))
   checkTrue(eventCount(history(dp)) > 6000)
   
   
} # testConstructor
#--------------------------------------------------------------------------------
testManifest <- function()
{
   printf("--- testManifest")
   dir <- system.file(package="TCGAcoadread", "extdata")
   checkTrue(file.exists(dir))
   
   file <- file.path(dir, "manifest.tsv")
   checkTrue(file.exists(file))
   
   tbl <- read.table(file, sep="\t", as.is=TRUE)
   checkEquals(ncol(tbl),  11)
   checkTrue(nrow(tbl) >= 8)
   expected.colnames <- c("variable", "class", "category", "subcategory",
                           "entity.count", "feature.count", "entity.type",
                           "feature.type", "minValue", "maxValue", "provenance")

   checkTrue(all(expected.colnames %in% colnames(tbl)))
 
   expected.categories <- c("copy number", "history", "mutations", "protein abundance",
                            "mRNA expression", "geneset")
   checkTrue(all(expected.categories %in% tbl$category))
   expected.rownames <- c("mtx.cn.RData", "events.RData","ptHistory.RData","historyTypes.RData", "tbl.ptHistory.RData",
                          "mtx.mut.RData", "mtx.prot.RData", "mtx.mrna_Agi.RData", "mtx.mrna_Seq.RData","genesets.RData")
   checkTrue(all(expected.rownames %in% rownames(tbl)))

   expected.classes <- c("data.frame", "list", "matrix")
   checkTrue(all(expected.classes %in% tbl$class));
   
   expected.provenance <- c("tcga cBio","tcga gbm and lgg","tcga",                                                               
                            "tcga cBio; one probe per gene- most anti-correlated with expression",
                            "marker.genes.545, tcga.GBM.classifiers, tcga.pancan.mutated" )
   checkTrue(all(expected.provenance %in% tbl$provenance));


   for(i in 1:nrow(tbl)){
      file.name <- rownames(tbl)[i]
      full.name <- file.path(dir, file.name)
      variable.name <- tbl$variable[i]
      checkEquals(load(full.name), variable.name)
        # get a handle on the variable, "x"
      eval(parse(text=sprintf("%s <- %s", "x", variable.name)))
      class <- tbl$class[i]
      category <- tbl$category[i]
      subcategory <- tbl$subcategory[i]
      entity.count <- tbl$entity.count[i]
      feature.count <- tbl$feature.count[i]
      checkEquals(class(x), class)
      if(class %in% c("matrix", "data.frame")){
         checkEquals(entity.count, nrow(x))
         checkEquals(feature.count, ncol(x))
         }
      if(class == "list"){
         checkEquals(entity.count, length(x))
         checkTrue(is.na(feature.count))
         }
      entity.type <- tbl$entity.type[i]
      feature.type <- tbl$feature.type[i]
      minValue <- tbl$minValue[i]
      maxValue <- tbl$maxValue[i]
      if(class == "matrix" && !is.na(minValue)){
         checkEqualsNumeric(min(x, na.rm=T), minValue, tolerance=10e-4)
         checkEqualsNumeric(max(x, na.rm=T), maxValue, tolerance=10e-4)
         }
      } # for i

   TRUE
   
} # testManifest
#----------------------------------------------------------------------------------------------------
testExpression <- function()
{
   printf("--- testExpression")

   dir <- system.file(package="TCGAcoadread", "extdata")
   checkTrue(file.exists(dir))
   file <- file.path(dir, "mtx.mrna_Agi.RData")
   checkTrue(file.exists(file))

   load(file)
   checkTrue(exists("mtx.mrna"))
   checkTrue(is(mtx.mrna, "matrix"))
   checkEquals(class(mtx.mrna[1,1]), "numeric")

   checkEquals(dim(mtx.mrna), c(222, 17212))

     # a reasonable range of expression log2 ratios
   checkEquals(fivenum(mtx.mrna), c(-16.0758, -0.6770, -0.0136,  0.6731, 17.9217))
   
     # all colnames should be recognzied gene symbols.  no isoform suffixes yet
#   checkTrue(all(colnames(mtx.mrna) %in% keys(org.Hs.egSYMBOL2EG)))

     # all rownames should follow "TCGA.02.0014" format.  no multiply-sampled suffixes yet
   regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w\\.[0-9][0-9]$"
   checkEquals(length(grep(regex, rownames(mtx.mrna))), nrow(mtx.mrna))

    file <- file.path(dir, "mtx.mrna_Seq.RData")
    checkTrue(file.exists(file))

    load(file)
    checkTrue(exists("mtx.mrna_Seq"))
    checkTrue(is(mtx.mrna_Seq, "matrix"))
    checkEquals(class(mtx.mrna_Seq[1,1]), "numeric")

    checkEquals(dim(mtx.mrna_Seq), c(365, 20444))

    # a reasonable range of expression log2 ratios
    checkEquals(fivenum(mtx.mrna_Seq), c(-5.8288,-0.5422,-0.1750,0.3700,15252.2394))

    # all colnames should be recognzied gene symbols.  no isoform suffixes yet
    #   checkTrue(all(colnames(mtx.mrna_Seq) %in% keys(org.Hs.egSYMBOL2EG)))

    # all rownames should follow "TCGA.02.0014" format.  no multiply-sampled suffixes yet
    regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w\\.[0-9][0-9]$"
    checkEquals(length(grep(regex, rownames(mtx.mrna_Seq))), nrow(mtx.mrna_Seq))




} # testExpression
#--------------------------------------------------------------------------------
testMutation <- function()
{
   printf("--- testMutation")

   dir <- system.file(package="TCGAcoadread", "extdata")
   checkTrue(file.exists(dir))
   file <- file.path(dir, "mtx.mut.RData")
   checkTrue(file.exists(file))

   load(file)
   checkTrue(exists("mtx.mut"))
   checkTrue(is(mtx.mut, "matrix"))
   checkEquals(dim(mtx.mut), c(223, 14780))

     # all colnames should be recognzied gene symbols.  no isoform suffixes yet
#   checkTrue(all(colnames(mtx.mut) %in% keys(org.Hs.egSYMBOL2EG)))

     # all rownames should follow "TCGA.02.0014" format.  no multiply-sampled suffixes yet
   regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w\\.[0-9][0-9]$"
   checkEquals(length(grep(regex, rownames(mtx.mut))), nrow(mtx.mut))

     # contents should all be character, now factors
     checkTrue(all(unlist(lapply(mtx.mut, function(row){class(row)}), use.names=FALSE) == "character"))
     

} # testMutation
#--------------------------------------------------------------------------------
testCopyNumber <- function()
{
   printf("--- testCopyNumber")

   dir <- system.file(package="TCGAcoadread", "extdata")
   checkTrue(file.exists(dir))
   file <- file.path(dir, "mtx.cn.RData")
   checkTrue(file.exists(file))

   load(file)
   checkTrue(exists("mtx.cn"))
   checkTrue(is(mtx.cn, "matrix"))
   checkEquals(dim(mtx.cn), c(615,22184))

     # all colnames should be recognzied gene symbols.  no isoform suffixes yet
#   checkTrue(all(colnames(mtx.cn) %in% keys(org.Hs.egSYMBOL2EG)))
# this data includes miRNA and other genes

     # all rownames should follow "TCGA.02.0014.01" format
   regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w\\.[0-9][0-9]$"
   checkEquals(length(grep(regex, rownames(mtx.cn))), nrow(mtx.cn))

     # contents should all be integer
   checkTrue(is(mtx.cn[1,1], "integer"))

     # only legit gistic values
   checkEquals(sort(unique(as.integer(mtx.cn))), c(-2, -1, 0, 1, 2))

} # testCopyNumber
#----------------------------------------------------------------------------------------------------
testProteinAbundance <- function()
{
   printf("--- testProteinAbundance")

   dir <- system.file(package="TCGAcoadread", "extdata")
   checkTrue(file.exists(dir))
   file <- file.path(dir, "mtx.prot.RData")
   checkTrue(file.exists(file))

   load(file)
   checkTrue(exists("mtx.prot"))
   checkTrue(is(mtx.prot, "matrix"))
   checkEquals(class(mtx.prot[1,1]), "numeric")

   checkEquals(dim(mtx.prot), c(461, 171))

     # a reasonable range of expression log2 ratios
   checkEquals(fivenum(mtx.prot), c( -6.59943171, -0.62534664, -0.04235672, 0.58666089, 14.26631908))
   
     # all colnames should be recognzied gene symbols.  no isoform suffixes yet
#   checkTrue(all(colnames(mtx.prot) %in% keys(org.Hs.egSYMBOL2EG)))

     # all rownames should follow "TCGA.02.0014" format.  no multiply-sampled suffixes yet
     #regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w\\.[0-9][0-9]$"
   regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w"
   checkEquals(length(grep(regex, rownames(mtx.prot))), nrow(mtx.prot))

} # testExpression
#----------------------------------------------------------------------------------------------------
testMethylation <- function()
{
   printf("--- testMethylation")

   dir <- system.file(package="TCGAcoadread", "extdata")
   checkTrue(file.exists(dir))
   file <- file.path(dir, "mtx.methHM450.RData")
   checkTrue(file.exists(file))

   load(file)
   checkTrue(exists("mtx.meth"))
   checkTrue(is(mtx.meth, "matrix"))
   checkEquals(class(mtx.meth[1,1]), "numeric")

   checkEquals(dim(mtx.meth), c(383, 15915))

     # a reasonable range of expression log2 ratios
   #checkEquals(fivenum(mtx.meth), c(0.00000000, 0.03695173, 0.08300117, 0.44657442, 0.99790393))
   checkEquals(fivenum(mtx.meth), c(0.005459927,0.056351668,0.341157328,0.754421383,0.994947172))
     # all colnames should be recognzied gene symbols.  no isoform suffixes yet
#   checkTrue(all(colnames(mtx.meth) %in% keys(org.Hs.egSYMBOL2EG)))

     # all rownames should follow "TCGA.02.0014" format.  no multiply-sampled suffixes yet
     #regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w\\.[0-9][0-9]$"
   regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w"
   checkEquals(length(grep(regex, rownames(mtx.meth))), nrow(mtx.meth))
   file <- file.path(dir, "mtx.methHM27.RData")
   checkTrue(file.exists(file))
   
   load(file)
   checkTrue(exists("mtx.meth"))
   checkTrue(is(mtx.meth, "matrix"))
   checkEquals(class(mtx.meth[1,1]), "numeric")
   
   checkEquals(dim(mtx.meth), c(233, 1667))
   
   # a reasonable range of expression log2 ratios
   #checkEquals(fivenum(mtx.meth), c(0.00000000, 0.03695173, 0.08300117, 0.44657442, 0.99790393))
   checkEquals(fivenum(mtx.meth), c(0.005000012, 0.035148311, 0.194938356, 0.669760796, 0.994361464))
   # all colnames should be recognzied gene symbols.  no isoform suffixes yet
   #   checkTrue(all(colnames(mtx.meth) %in% keys(org.Hs.egSYMBOL2EG)))
   
   # all rownames should follow "TCGA.02.0014" format.  no multiply-sampled suffixes yet
   #regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w\\.[0-9][0-9]$"
   regex <- "^TCGA\\.\\w\\w\\.\\w\\w\\w\\w"
   checkEquals(length(grep(regex, rownames(mtx.meth))), nrow(mtx.meth))


} # testExpression
#--------------------------------------------------------------------------------
testMatrixAndDataframeAccessors <- function()
{
   printf("--- testMatrixAndDataframeAccessors")
   dp <- TCGAcoadread();
   checkTrue("mtx.cn" %in% names(matrices(dp)))
   samples <- head(entities(dp, "mtx.cn"), n=3)
   checkEquals(samples, c("TCGA.3L.AA1B.01", "TCGA.4N.A93T.01", "TCGA.4T.AA8H.01"))
    

} # testMatrixAndDataframeAccessors
#--------------------------------------------------------------------------------
testHistoryList <- function()
{
   printf("--- testHistoryList")
   dp <- TCGAcoadread();
   checkTrue("history" %in% manifest(dp)$variable)
   ptHistory <- history(dp)
   checkTrue(is(ptHistory, "PatientHistoryClass"))

   events <- geteventList(ptHistory)
   checkEquals(length(events), 6075)
    
   event.counts <- as.list(table(unlist(lapply(events,
                           function(element) element$Name), use.names=FALSE)))
   checkEquals(event.counts,
               list(Absent=84,
                    Background=625,
                    Birth=625,
                    Diagnosis=625,
                    Drug=708,
                    Encounter=625,
                    Pathology=716,
                    Procedure=96,
                    Progression=126,
                    Radiation=56,
                    Status=625,
                    Tests=1164))

} # testHistoryList
#--------------------------------------------------------------------------------
testHistoryTable <- function()
{
   printf("--- testHistoryTable")
   dp <- TCGAcoadread();
   checkTrue("history" %in% manifest(dp)$variable)
   ptHistory <- history(dp)
   checkTrue(is(ptHistory, "PatientHistoryClass"))

   events <- getTable(ptHistory)
   checkEquals(class(events),"data.frame")
   checkEquals(dim(events), c(625, 410))
   checkEquals(colnames(events)[1:10], 
           c("ptID", "ptNum", "study", "Birth.date", "Birth.gender", "Birth.race", "Birth.ethnicity",
             "Drug.date1", "Drug.date2", "Drug.therapyType"))
   checkEquals(unique(events$study), c("TCGAcoad", "TCGAread"))
   checkEquals(as.character(events[1,4]),"09/25/1951")
   checkEquals(as.character(events[1,c("Survival", "AgeDx", "TimeFirstProgression")]), c("349", "22379", "NA"))

} # testHistoryList
#----------------------------------------------------------------------------------------------------
testCanonicalizePatientIDs <- function()
{
   printf("--- testCanonicalizePatientIDs")
   dp <- TCGAcoadread()
   IDs <- names(getPatientList(dp))
   ptIDs <- canonicalizePatientIDs(dp, IDs)
   
   checkTrue(all(grepl("^TCGA\\.\\w\\w\\.\\w\\w\\w\\w$", ptIDs)))

}
#----------------------------------------------------------------------------------------------------
if(!interactive())
   runTests()
