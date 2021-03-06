#' Calculate Chemical Descriptors using RCDK
#' @param x A dataframe with 3 mandatory column: "Name", "InchIKey", "SMILES".
#' @export getCD
#' @return A dataframe with calculated CD. Some compund can be missing if smiles is incorect or if molecule returns error in CDK
#' @examples
#' \donttest{
#' # RP and HILIC are previusly loaded dataset from excel with
#' # Name, InchIKey, SMILES and Retention Time
#' descs <- getCD(RP)
#' descs <- getCD(HILIC)}

getCD <- function(x,cores=1){
  library(foreach)
  cl <- parallel::makeCluster(cores)
  doParallel::registerDoParallel(cl)

  print(paste0("Converting SMILES..."))

  x$SMILES <- foreach (i=1:nrow(x),.combine=rbind, .packages=c("rcdk")) %dopar% {
    smi <- rcdk::parse.smiles(as.character(unlist(x[i,"SMILES"]))) [[1]]
    smi1 <- rcdk::generate.2d.coordinates(smi)
    smi1 <- rcdk::get.smiles(smi,smiles.flavors(c('CxSmiles')))
    smi1
#    print(paste0(i," of ",nrow(x)))
  }


  # select all possible descriptors
  descNames <- rcdk::get.desc.names(type = "all")
  # select only one descriptors. This helps to remove compounds that makes errors
  descNames1 <- c('org.openscience.cdk.qsar.descriptors.molecular.BCUTDescriptor')

  print(paste0("Checking for compound errors..."))

  # calculate only 1 descriptor for all the molecules
  mols_x <- rcdk::parse.smiles(as.character(unlist(x[1,"SMILES"])))
  descs1_x <- rcdk::eval.desc(mols_x, descNames1)

  descs1_x <- foreach (i=1:nrow(x),.combine=rbind, .packages=c("rcdk")) %dopar% {
    mols1 <- rcdk::parse.smiles(as.character(unlist(x[i,"SMILES"])))
    rcdk::eval.desc(mols1, descNames1)
#    descs1_x[i,] <- rcdk::eval.desc(mols1, descNames1)
#    print(paste0(i," of ",nrow(x)))
  }

  # remove molecules that have NA values with only one descriptor
  x_na <- data.frame(descs1_x,x)

  x_na_rem <- x_na[stats::complete.cases(x_na), ]

  x_na_rem <- x_na_rem [,-c(1:6)]

  # computing the whole descriptos on the good on the clean dataset
  print(paste0("Computing Chemical Descriptors 1 of ",nrow(x_na_rem)," ... Please wait"))

  mols_x1 <- rcdk::parse.smiles(as.character(unlist(x_na_rem[1,"SMILES"])))[[1]]
  rcdk::convert.implicit.to.explicit(mols_x1)
  # leave out "org.openscience.cdk.qsar.descriptors.molecular.LongestAliphaticChainDescriptor
  descs_x_loop <- rcdk::eval.desc(mols_x1, descNames[-20])


  descs_x_loop <- foreach (i=1:nrow(x_na_rem),.combine=rbind,.packages=c("rcdk")) %dopar% {
    mols <- rcdk::parse.smiles(as.character(unlist(x_na_rem[i,"SMILES"])))[[1]]
    rcdk::convert.implicit.to.explicit(mols)
    # leave out "org.openscience.cdk.qsar.descriptors.molecular.LongestAliphaticChainDescriptor"
#    descs_x_loop[i,] <- rcdk::eval.desc(mols, descNames[-20])
     rcdk::eval.desc(mols, descNames[-20])
#    print(paste0(i," of ",nrow(x_na_rem)))
  }
  datadesc <- data.frame(x_na_rem,descs_x_loop)

  parallel::stopCluster(cl)
  return(datadesc)
}

