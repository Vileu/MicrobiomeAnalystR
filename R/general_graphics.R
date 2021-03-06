##################################
###########3D PCoA/PCA############
##################################

#'Main function to perform PCoA analysis
#'@description This functions creates a 3D PCoA plot from the microbiome data.
#'This is used by the Beta-Diversity analysis.
#'The 3D interactive visualization is on the web.
#'@param mbSetObj Input the name of the mbSetObj.
#'@param ordMeth Character, input the name
#'of the ordination method. "PCoA" for principal coordinate analysis and "NMDS" for 
#'non-metric multidimensional scaling.
#'@param distName Character, input the name of the distance method.
#'@param datatype Character, input "16S" if the data is marker
#'gene data and "metageno" if it is metagenomic data.
#'@param taxrank Character, input the taxonomic
#'level for beta-diversity analysis.
#'@param colopt Character, color the data points by the experimental factor,
#'the taxon abundance of a selected taxa, or alpha diversity.
#'@param variable Character, input the name of the experimental factor.
#'@param taxa Character, if the data points are colored by taxon abundance, 
#'input the name of the selected taxa.
#'@param alphaopt Character, if the data points are colored by alpha-diversity, 
#'input the preferred alpha-diversity measure.
#'@param jsonNm Character, input the name of the json file to output.
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'@import vegan
#'@import RJSONIO

PCoA3D.Anal <- function(mbSetObj, ordMeth, distName, taxrank, colopt, variable, taxa, alphaopt, jsonNm){
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  load_vegan();
  
  variable <<- variable;
  
  if(taxrank=="OTU"){
    taxa_table <- tax_table(mbSetObj$dataSet$proc.phyobj);
    data <- merge_phyloseq(mbSetObj$dataSet$norm.phyobj, taxa_table);
  }else{
    taxa_table <- tax_table(mbSetObj$dataSet$proc.phyobj);
    data <- merge_phyloseq(mbSetObj$dataSet$norm.phyobj, taxa_table);
    #merging at taxonomy levels
    data <- fast_tax_glom_mem(data, taxrank)
    if(is.null(data)){
      AddErrMsg("Errors in projecting to the selected taxanomy level!");
      return(0);
    }
  }
  
  if(colopt=="taxa"){
    if(taxrank=="OTU"){
      data1 <- as.matrix(otu_table(data));
      feat_data <- as.numeric(data1[taxa,]);
    }else{
      nm <- as.character(tax_table(data)[,taxrank]);
      #converting NA values to unassigned
      nm[is.na(nm)] <- "Not_Assigned";
      data1 <- as.matrix(otu_table(data));
      rownames(data1) <- nm;
      #all NA club together
      data1 <- as.matrix(t(sapply(by(data1,rownames(data1),colSums),identity)));
      feat_data <- data1[taxa,];
    }
    sample_data(data)$taxa <- feat_data;
    indx <- which(colnames(sample_data(data))=="taxa");
    colnames(sample_data(data))[indx] <- taxa;
  }else if(colopt=="alphadiv"){
    data1 <- mbSetObj$dataSet$proc.phyobj;
    box <- plot_richness(data1, measures = alphaopt);
    alphaboxdata <- box$data;
    sam_nm <- sample_names(data);
    alphaboxdata <- alphaboxdata[alphaboxdata$samples %in% sam_nm,];
    alphaval <- alphaboxdata$value;
    sample_data(data)$alphaopt <- alphaval;
    indx <- which(colnames(sample_data(data))=="alphaopt");
    colnames(sample_data(data))[indx]<-alphaopt;
  }else{
    data<-data;
  }
  
  datacolby <<- data;
  
  if(distName=="wunifrac"){
    pg_tree <- readRDS("tree.RDS");
    pg_tb <- tax_table(data);
    pg_ot <- otu_table(data);
    pg_sd <- sample_data(data);
    pg_tree <- prune_taxa(taxa_names(pg_ot), pg_tree);
    data <- merge_phyloseq(pg_tb, pg_ot, pg_sd, pg_tree);
    
    if(!is.rooted(phy_tree(data))){
      pick_new_outgroup <- function(tree.unrooted){
        treeDT <- cbind(cbind(data.table(tree.unrooted$edge),data.table(length = tree.unrooted$edge.length))[1:Ntip(tree.unrooted)],
                        data.table(id = tree.unrooted$tip.label));
        new.outgroup <- treeDT[which.max(treeDT$length), ]$id
        return(new.outgroup);
      }
      new.outgroup <- pick_new_outgroup(phy_tree(data));
      phy_tree(data) <- ape::root(phy_tree(data),
                                  outgroup = new.outgroup,
                                  resolve.root=TRUE)
    }
    GP.ord <-ordinate(data,ordMeth,"unifrac",weighted=TRUE);
  } else if (distName=="unifrac"){
    pg_tree <- readRDS("tree.RDS");
    pg_tb <- tax_table(data);
    pg_ot <- otu_table(data);
    pg_sd <- sample_data(data);
    pg_tree <- prune_taxa(taxa_names(pg_ot), pg_tree);
    data <- merge_phyloseq(pg_tb, pg_ot, pg_sd, pg_tree);
    
    if(!is.rooted(phy_tree(data))){
      pick_new_outgroup <- function(tree.unrooted){
        treeDT <- cbind(cbind(data.table(tree.unrooted$edge),data.table(length = tree.unrooted$edge.length))[1:Ntip(tree.unrooted)],
                        data.table(id = tree.unrooted$tip.label));
        new.outgroup <- treeDT[which.max(treeDT$length), ]$id
        return(new.outgroup);
      }
      new.outgroup <- pick_new_outgroup(phy_tree(data));
      phy_tree(data) <- ape::root(phy_tree(data),
                                  outgroup = new.outgroup,
                                  resolve.root=TRUE)
    }
    GP.ord <-ordinate(data,ordMeth,"unifrac",weighted=FALSE);
  }else{
    GP.ord <- ordinate(data,ordMeth,distName);
  }
  
  # obtain variance explained
  sum.pca <- GP.ord;
  imp.pca <- sum.pca$values;
  std.pca <- imp.pca[1,]; # eigen values
  var.pca <- imp.pca[,2]; # variance explained by each PC
  cum.pca <- imp.pca[5,]; # cummulated variance explained
  sum.pca <- append(sum.pca, list(std=std.pca, variance=var.pca, cum.var=cum.pca));
  
  pca3d <- list();
  
  if(ordMeth=="NMDS"){
    pca3d$score$axis <- paste("NMDS", 1:3 , sep="");
    coord<-sum.pca$points;
    write.csv(signif(coord,5), file="pcoa_score.csv");
    list2 <- rep(as.numeric(0),nrow(coord));
    coord <- cbind(coord, list2);
    coords <- data.frame(t(signif(coord[,1:3], 5)));
  }else{
    pca3d$score$axis <- paste("PC", 1:3, " (", 100*round(sum.pca$variance[1:3], 3), "%)", sep="");
    coords <- data.frame(t(signif(sum.pca$vectors[,1:3], 5)));
    write.csv(signif(sum.pca$vectors,5), file="pcoa_score.csv");
  }
  
  colnames(coords) <- NULL;
  pca3d$score$xyz <- coords;
  pca3d$score$name <- sample_names(mbSetObj$dataSet$norm.phyobj);
  col.type <- "factor";
  
  if(colopt=="taxa"){
    cls <- sample_data(data)[[taxa]];
    col.type <- "gradient"
    cols <- ComputeColorGradient(cls);
  }else if(colopt=="alphadiv") {
    cls <- sample_data(data)[[alphaopt]];
    col.type <- "gradient";
    cols <- ComputeColorGradient(cls);
  }else{
    cls <- factor(sample_data(mbSetObj$dataSet$norm.phyobj)[[variable]]);
    # now set color for each group
    cols <- unique(as.numeric(cls)) + 1;
  }
  
  pca3d$score$type <- col.type;
  pca3d$score$facA <- cls;
  rgbcols <- col2rgb(cols);
  cols <- apply(rgbcols, 2, function(x){paste("rgb(", paste(x, collapse=","), ")", sep="")});
  pca3d$score$colors <- cols;
  
  load_rjsonio();
  
  json.obj <- RJSONIO::toJSON(pca3d);
  sink(jsonNm);
  cat(json.obj);
  sink();
  
  return(.set.mbSetObj(mbSetObj));
}

#'Function to plot tree graphics for dendogram.
#'@description This functions creates dendogram tree plots.
#'@param mbSetObj Input the name of the mbSetObj.
#'@param plotNm Character, input the name of the plot.
#'@param distnm Character, input the name of the selected
#'distance measure. "bray" for Bray-Curtis Index, "jsd" for
#'Jensen-Shannon Divergence, "jaccard" for Jaccard Index, 
#'"unifrac" for Unweighted Unifrac Distance, and "wunifrac" for weighted
#'unifrac distance.
#'@param clstDist Character, input the name of the
#'selected clustering algorithm. "ward" for Ward, "average" for Average, 
#'"complete" for Complete, and "single" for Single.
#'@param metadata Character, input the name of the experimental factor.
#'@param datatype Character, "16S" if marker gene data and 
#'"metageno" if shotgun metagenomic data.
#'@param colorOpts Character, "default" or "viridis".
#'@param taxrank Character, input the taxonomic level to perform
#'classification. For instance, "OTU-level" to use OTUs.
#'@param format Character, by default the plot is .png format.
#'@param dpi The dots per inch. Numeric, by default it is set to 72.
#'@param width Width of the plot. Numeric, by default it is set to NA.
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'@import ape
#'@import viridis
PlotTreeGraph <- function(mbSetObj, plotNm, distnm, clstDist, metadata, taxrank, colorOpts, format="png", dpi=72, width=NA){
  
  load_ape()
  load_viridis()
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  set.seed(2805619);
  plotNm <- paste(plotNm,".", format, sep="");
  variable<<-metadata;
  
  data <- mbSetObj$dataSet$norm.phyobj;
  
  if(mbSetObj$module.type=="mdp"){
    mbSetObj$dataSet$taxa_table <- tax_table(mbSetObj$dataSet$proc.phyobj);
    data <- merge_phyloseq(data,mbSetObj$dataSet$taxa_table);
  }else{
    data <- data;
  }
  
  #using by default names for shotgun data
  if(mbSetObj$module.type=="sdp"){
    taxrank<-"OTU";
  }
  
  if(taxrank!="OTU"){
    #merging at taxonomy levels
    data<-fast_tax_glom_mem(data,taxrank);
    if(is.null(data)){
      AddErrMsg("Errors in projecting to the selected taxanomy level!");
      return(0);
    }
  }
  
  hc.cls <-as.factor(sample_data(data)[[variable]]);
  
  # must call distance within the phyloslim package
  if(distnm == "unifrac" | distnm == "wunifrac"){
    pg_tree <- readRDS("tree.RDS");
    pg_tb <- tax_table(data);
    pg_ot <- otu_table(data);
    pg_sd <- sample_data(data);
    pg_tree <- prune_taxa(taxa_names(pg_ot), pg_tree);
    data <- merge_phyloseq(pg_tb, pg_ot, pg_sd, pg_tree);
    
    if(!is.rooted(phy_tree(data))){
      pick_new_outgroup <- function(tree.unrooted){
        treeDT <-
          cbind(cbind(
            data.table(tree.unrooted$edge),
            data.table(length = tree.unrooted$edge.length))[1:Ntip(tree.unrooted)],
            data.table(id = tree.unrooted$tip.label));
        new.outgroup <- treeDT[which.max(treeDT$length), ]$id
        return(new.outgroup);
      }
      new.outgroup <- pick_new_outgroup(phy_tree(data));
      phy_tree(data) <- ape::root(phy_tree(data),
                                  outgroup = new.outgroup,
                                  resolve.root=TRUE)
    }
    dist.mat<-distance(data,distnm,type = "samples")
  } else {
    dist.mat<-distance(data,distnm,type = "samples")
  }
  
  # build the tree
  hc_tree<-hclust(dist.mat, method=clstDist);
  mbSetObj$imgSet$tree<-plotNm;
  
  if(is.na(width)){
    w <- minH <- 650;
    myH <- nsamples(data)*16 + 150;
    
    if(myH < minH){
      myH <- minH;
    }
    w <- round(w/72,2);
    h <- round(myH/72,2);
  }
  
  Cairo::Cairo(file=plotNm, unit="in", dpi=dpi, width=w, height=h, type=format, bg="white");
  par(mar=c(4,2,2,10));
  clusDendro <- as.dendrogram(hc_tree);
  
  if(colorOpts == "default"){
    cols <- GetColorSchema(mbSetObj);
  }else{
    
    claslbl <- as.factor(sample_data(mbSetObj$dataSet$norm.phyobj)[[variable]]);
    grp.num <- length(levels(claslbl));
    
    if(colorOpts == "viridis"){
      cols <- viridis::viridis(grp.num)
    }else if(colorOpts == "plasma"){
      cols <- viridis::plasma(grp.num)
    }else if(colorOpts == "cividis"){
      cols <- viridis::cividis(grp.num)
    }
    
    lvs <- levels(claslbl);
    colors <- vector(mode="character", length=length(mbSetObj$analSet$cls));
    
    for(i in 1:length(lvs)){
      colors[claslbl == lvs[i]] <- cols[i];
    }
    
    cols <- colors
  }
  
  names(cols) <- sample_names(data);
  labelColors <- cols[hc_tree$order];
  
  colLab <- function(n){
    if(is.leaf(n)) {
      a <- attributes(n);
      labCol <- labelColors[a$label];
      attr(n, "nodePar") <-
        if(is.list(a$nodePar)){
          c(a$nodePar,lab.col = labCol,pch=NA)
        }else{
          list(lab.col = labCol,pch=NA)
        }
    }
    n
  }
  
  clusDendro<-dendrapply(clusDendro, colLab);
  plot(clusDendro,horiz=T,axes=T);
  par(cex=1);
  legend.nm <- unique(as.character(hc.cls));
  legend.nm <-gsub("\\.", " ",legend.nm)
  legend("topleft", legend = legend.nm, pch=15, col=unique(cols), bty = "n");
  dev.off();
  mbSetObj$analSet$tree<-hc_tree;
  mbSetObj$analSet$tree.dist<-distnm;
  mbSetObj$analSet$tree.clust<-clstDist;
  mbSetObj$analSet$tree.taxalvl<-taxrank;
  return(.set.mbSetObj(mbSetObj))
}

#######################################
###########DE(feature boxplot)#########
#######################################

#'Function to create box plots of important features
#'@description This functions plots box plots of a selected feature.
#'@param mbSetObj Input the name of the mbSetObj.
#'@param boxplotName Character, input the name of the 
#'box plot.
#'@param feat Character, input the name of the selected 
#'feature.
#'@param format Character, by default the plot format
#'is "png".
#'@param dpi Dots per inch. Numeric, by default
#'it is set to 72.
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'@import grid
#'@import gridExtra
PlotBoxData <- function(mbSetObj, boxplotName, feat, format="png", dpi=72){
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  load_ggplot();
  load_grid();
  load_gridExtra();
  
  variable <-  mbSetObj$analSet$var.type 
  
  sample_table <- sample_data(mbSetObj$dataSet$proc.phyobj, errorIfNULL=TRUE);
  
  if(is.null(variable)){
    variable <- colnames(sample_table)[1];
  }
  
  data <- mbSetObj$analSet$boxdata;
  a <- data[,feat];
  ind <- which(a=="0");
  a[ind] <- 0.1;
  data$log_feat <- log(a);
  boxplotName = paste(boxplotName,".",format, sep="");
  Cairo::Cairo(file=boxplotName,width=720, height=360, type=format, bg="white",dpi=dpi);
  
  box=ggplot(data,aes(x=data$class, y = data[,feat])) + stat_boxplot(geom ='errorbar') + 
    geom_boxplot(aes(fill=class), outlier.shape = NA) + geom_jitter() + theme_bw() + labs(y="Abundance", x=variable) +
    ggtitle("Filtered Count") + theme(plot.title = element_text(hjust=0.5), legend.position="none");
  
  box1=ggplot(data,aes(x=data$class, y = data$log_feat)) + stat_boxplot(geom ='errorbar') + 
    geom_boxplot(aes(fill=class), outlier.shape = NA) + geom_jitter() + theme_bw() + labs(y="", x=variable, fill=variable) +
    ggtitle("Log-transformed Count") + theme(plot.title = element_text(hjust=0.5));
  
  grid.arrange(ggplotGrob(box), ggplotGrob(box1),ncol=2,nrow=1,top=feat);
  dev.off();
  return(.set.mbSetObj(mbSetObj))
}

###############################
###########Heatmap#############
###############################

#'Main function to plot heatmap.
#'@description This functions plots a heatmap from the mbSetObj.
#'@param mbSetObj Input the name of the mbSetObj.
#'@param plotNm Character, input the name
#'of the plot.
#'@param smplDist Input the distance measure. "euclidean" for
#'Euclidean distance, "correlation" for Pearson, and "minkowski"
#'for Minkowski.
#'@param clstDist Character, input the name of the
#'selected clustering algorithm. "ward" for Ward, "average" for Average, 
#'"complete" for Complete, and "single" for Single.
#'@param palette Set the colors of the heatmap. By default it 
#'is set to "bwm", blue, white, to red. Use "gbr" for green, black, red, use
#'"heat" for red to yellow, "topo" for blue to yellow, "gray" for 
#'white to black, and "byr" for blue, yellow, red.
#'@param metadata Character, input the name of the experimental factor 
#'to cluster samples by.
#'@param taxrank Character, input the taxonomic level to perform
#'classification. For instance, "OTU-level" to use OTUs.
#'@param viewOpt Character, "overview" to view an overview
#'of the heatmap, and "detail" to iew a detailed view of the
#'heatmap (< 1500 features).
#'@param doclust Logicial, default set to "F".
#'@param format Character, input the preferred
#'format of the plot. By default it is set to "png".
#'@param showfeatname Logical, "T" to show feature names and 
#'"F" to not.
#'@param appendnm Logical, "T" to prepend higher taxon names.
#'@param rowV Logical, default set to "F".
#'@param colV Logical, default set to "T".
#'@param var.inx Default set to NA.
#'@paraboxdatam border Logical, show cell borders, default set to "T".
#'@param width Numeric, input the width of the plot. By
#'default it is set to NA.
#'@param dpi Numeric, input the dots per inch. By default
#'it is set to 72.
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'@import pheatmap
#'@import viridis

PlotHeatmap<-function(mbSetObj, plotNm, smplDist, clstDist, palette, metadata,
                      taxrank, viewOpt, doclust, format="png", showfeatname,
                      appendnm, rowV=F, colV=T, var.inx=NA, border=T, width=NA, dpi=72){
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  load_pheatmap();
  load_rcolorbrewer();
  load_viridis();
  
  set.seed(2805614);
  #used for color pallete
  variable <<- metadata;
  data <- mbSetObj$dataSet$norm.phyobj;
  
  if(mbSetObj$module.type=="mdp"){
    mbSetObj$dataSet$taxa_table <- tax_table(mbSetObj$dataSet$proc.phyobj);
    data <- merge_phyloseq(data, mbSetObj$dataSet$taxa_table);
  }else{
    taxrank <- "OTU";
  }
  
  #if more than 1500 features will be present;subset to most abundant=>1500 features.
  #OTUs already in unique names;
  if(ntaxa(data)>1500){
    data = prune_taxa(names(sort(taxa_sums(data), TRUE))[1:1500], data);
    viewOpt == "overview";
  }
  
  if(taxrank=="OTU"){
    data1 <- as.matrix(otu_table(data));
    rownames(data1) <- taxa_names(data);
  }else{
    #merging at taxonomy levels
    data <- fast_tax_glom_mem(data,taxrank);
    if(is.null(data)){
      AddErrMsg("Errors in projecting to the selected taxanomy level!");
      return(0);
    }
    nm <- as.character(tax_table(data)[,taxrank]);
    y <- which(is.na(nm)==TRUE);
    #converting NA values to unassigned
    nm[y] <- "Not_Assigned";
    data1 <- as.matrix(otu_table(data));
    
    if(appendnm=="T"){
      all_nm <- colnames(tax_table(data));
      hg_nmindx <- which(all_nm==taxrank)-1;
      
      if(hg_nmindx!=0){
        nma <- as.character(tax_table(data)[,hg_nmindx]);
        y1 <- which(is.na(nma)==TRUE);
        nma[y1] <- "Not_Assigned";
        nm <- paste0(nma,"_",nm);
        ind <- which(nm=="Not_Assigned_Not_Assigned");
        nm[ind] <- "Not_Assigned";
        nm <- gsub("_Not_Assigned", "",nm, perl = TRUE);
      }
    }
    
    rownames(data1) <- nm;
    #all NA club together
    data1 <- (t(sapply(by(data1,rownames(data1),colSums),identity)));
    nm <- rownames(data1);
  }
  
  # arrange samples on the basis of slected experimental factor and using the same for annotation also
  annotation <- data.frame(sample_data(data));
  
  ind <- which(colnames(annotation)!=metadata && colnames(annotation)!="sample_id");
  
  if(length(ind)>0){
    ind1 <- ind[1];
    annotation <- annotation[order(annotation[,metadata],annotation[,ind1]),];
  }else{
    annotation <- annotation[order(annotation[,metadata]),];
  }
  
  # remove those columns that all values are unique (continuous or non-factors)
  #uniq.inx <- apply(annotation, 2, function(x){length(unique(x)) == length(x)});
  #there is an additional column sample_id which need to be removed first
  # get only good meta-data
  good.inx <- GetDiscreteInx(annotation);
  if(sum(good.inx)>0){
    annotation <- annotation[,good.inx, drop=FALSE];
    sam.ord <- rownames(annotation);
    data1 <- data1[,sam.ord];
  }else{
    annotation <- NA;
  }
  
  # set up colors for heatmap
  if(palette=="gbr"){
    colors <- grDevices::colorRampPalette(c("green", "black", "red"), space="rgb")(256);
  }else if(palette == "heat"){
    colors <- grDevices::heat.colors(256);
  }else if(palette == "topo"){
    colors <- grDevices::topo.colors(256);
  }else if(palette == "gray"){
    colors <- grDevices::colorRampPalette(c("grey90", "grey10"), space="rgb")(256);
  }else if(palette == "byr"){
    colors <- rev(grDevices::colorRampPalette(RColorBrewer::brewer.pal(10, "RdYlBu"))(256));
  }else if(palette == "viridis") {
    colors <- rev(viridis::viridis(10))
  }else if(palette == "plasma") {
    colors <- rev(viridis::plasma(10))
  }else {
    colors <- rev(grDevices::colorRampPalette(RColorBrewer::brewer.pal(10, "RdBu"))(256));
  }
  
  if(showfeatname=="T"){
    showfeatname<-T;
    min.margin <- 360;
  } else {
    showfeatname<-F;
    min.margin <- 200;
  }
  
  #setting the size of plot
  if(is.na(width)){
    minW <- 800;
    myW <- ncol(data1)*20 + min.margin;
    if(myW < minW){
      myW <- minW;
    }
    w <- round(myW/72,2);
  }
  
  myH <- nrow(data1)*20 + 180;
  h <- round(myH/72,2);
  
  if(viewOpt == "overview"){
    if(is.na(width)){
      if(w >9.3){
        w <- 9.3;
      }
    }
    if(h > w){
      h <- w;
    }
  }
  
  if(border){
    border.col<-"grey60";
  }else{
    border.col <- NA;
  }
  
  plotNm = paste(plotNm, ".", format, sep="");
  mbSetObj$imgSet$heatmap<-plotNm;
  
  if(format=="pdf"){
    grDevices::pdf(file = plotNm, width=w, height=h, bg="white", onefile=FALSE);
  }else{
    Cairo::Cairo(file = plotNm, unit="in", dpi=dpi, width=w, height=h, type=format, bg="white");
  }
  
  # set up color schema for samples
  if(palette== "gray"){
    cols <- GetColorSchema(mbSetObj, T);
    uniq.cols <- unique(cols);
  }else{
    cols <- GetColorSchema(mbSetObj, F);
    uniq.cols <- unique(cols);
  }
  
  if(doclust=="T"){
    rowV<-T;
  }
  
  pheatmap::pheatmap(data1,
                     annotation=annotation,
                     fontsize=8, fontsize_row=8,
                     clustering_distance_rows = smplDist,
                     clustering_distance_cols = smplDist,
                     clustering_method = clstDist,
                     show_rownames = showfeatname,
                     border_color = border.col,
                     cluster_rows = colV,
                     cluster_cols = rowV,
                     scale= "row",
                     color = colors
  );
  
  dev.off();
  
  # storing for Report Generation
  mbSetObj$analSet$heatmap<-data1;
  mbSetObj$analSet$heatmap.dist<-smplDist;
  mbSetObj$analSet$heatmap.clust<-clstDist;
  mbSetObj$analSet$heat.taxalvl<-taxrank;
  return(.set.mbSetObj(mbSetObj))
}

#'Function to get color palette for graphics.
#'@description This function is called to create a color palette
#'based on the number of groups. It returns a vector of color
#'hex codes based on the number of groups.
#'@param mbSetObj Input the name of the mbSetObj.
#'@param grayscale Logical, default set to F.
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
GetColorSchema <- function(mbSetObj, grayscale=F){
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  # test if total group number is over 9
  claslbl <- as.factor(sample_data(mbSetObj$dataSet$norm.phyobj)[[variable]]);
  grp.num <- length(levels(claslbl));
  
  if(grayscale){
    dist.cols <- grDevices::colorRampPalette(c("grey90", "grey30"))(grp.num);
    lvs <- levels(claslbl);
    colors <- vector(mode="character", length=length(claslbl));
    
    for(i in 1:length(lvs)){
      colors[mbSetObj$analSet$cls == lvs[i]] <- dist.cols[i];
    }
  }else if(grp.num > 9){
    pal12 = c("#A6CEE3", "#1F78B4", "#B2DF8A", "#33A02C", "#FB9A99",
              "#E31A1C", "#FDBF6F", "#FF7F00", "#CAB2D6", "#6A3D9A",
              "#FFFF99", "#B15928");
    dist.cols <- grDevices::colorRampPalette(pal12)(grp.num);
    lvs <- levels(claslbl);
    colors <- vector(mode="character", length=length(mbSetObj$analSet$cls));
    
    for(i in 1:length(lvs)){
      colors[claslbl == lvs[i]] <- dist.cols[i];
    }
  }else{
    if(exists("colVec") && !any(colVec =="#NA") ){
      cols <- vector(mode="character", length=length(claslbl));
      clsVec <- as.character(claslbl);
      grpnms <- names(colVec);
      
      for(i in 1:length(grpnms)){
        cols[clsVec == grpnms[i]] <- colVec[i];
      }
      colors <- cols;
    }else{
      colors <- as.numeric(claslbl)+1;
    }
  }
  return (colors);
}

#'Function to create box plots of important features
#'@description This functions plots box plots of a selected feature.
#'@param mbSetObj Input the name of the mbSetObj.
#'@param boxplotName Character, input the name of the 
#'box plot.
#'@param feat Character, input the name of the selected 
#'feature.
#'@param format Character, by default the plot format
#'is "png".
#'@param dpi Dots per inch. Numeric, by default
#'it is set to 72.
#'@parm colorPal Character, input the name of the preferred color palette.
#'Use "default" for the RColor brewer Set1 palette, "virdis" for the viridis color palette, and
#'"dark" for the RColor brewer Dark2 palette.
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
#'@import grid
#'@import gridExtra
PlotBoxDataCorr<-function(mbSetObj, boxplotName, feat, format="png", dpi=72, colorPal = "dark"){
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  load_ggplot();
  load_grid();
  load_gridExtra();
  
  variable <-  mbSetObj$analSet$var.typecor 
  
  data <- mbSetObj$analSet$boxdatacor;
  a <- data[,feat];
  ind <- which(a=="0");
  a[ind] <- 0.1;
  data$log_feat <- log(a);
  boxplotName = paste(boxplotName,".",format, sep="");
  
  numGrps <- length(levels(data$class))
  
  if(numGrps == 2){
    width <- 325
  }else if(numGrps < 4){
    width <- 350
  }else if(numGrps < 6){
    width <- 375
  }else{
    width <- 400
  }
  
  Cairo::Cairo(file=boxplotName, width=width, height=300, type=format, bg="white", dpi=dpi);
  
  box <- ggplot(data, aes(x=data$class, y = data$log_feat, fill=as.factor(class))) + stat_boxplot(geom ='errorbar') + 
    geom_boxplot(outlier.shape = NA) + geom_jitter() + theme_bw() + labs(y="Log-transformed Counts\n", x=paste0("\n",variable), fill=variable) +
    ggtitle(feat) + theme(plot.title = element_text(hjust=0.5, size=13, face="bold"), axis.title=element_text(size=11), legend.title=element_text(size=11), axis.text=element_text(size=10));
  #remove grid
  box <- box + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank(), panel.background = element_blank(), panel.border = element_rect(colour = "#787878", fill=NA, size=0.5))
  
  if(colorPal == "viridis"){
    box <- box + scale_fill_viridis_d()
  }else if(colorPal == "set1"){
    box <- box + scale_fill_brewer(palette="Set1")
  }else if(colorPal == "dark"){
    box <- box + scale_fill_brewer(palette="Dark2")
  }
  
  print(box)
  dev.off();
  return(.set.mbSetObj(mbSetObj))
}

#' Perform Partial Correlation Analysis
#' @description Function to perform and plot
#' partial correlations between all taxonomic features,
#' the outcome, and selected confounders.
#' NOTE: All metadata must be numeric
#' @param mbSetObj Input the name of the mbSetObj.
#' @param taxa.lvl Character, input the taxonomic level
#' to perform partial correlation analysis.
#' @param variable Character, input the selected variable.
#' @param alg Use "kendall" or "spearman" for non-parametric and 
#' "pearson" for parametric.
#' @export
#' @import ppcor
PerformPartialCorr <- function(mbSetObj, taxa.lvl="Phylum", variable=NA, alg = "pearson", pval.cutoff = 0.05){
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  load_ppcor()
  load_viridis()
  
  # retrieve sample info
  metadata <- data.frame(sample_data(mbSet$dataSet$proc.phyobj), check.names=F, stringsAsFactors = FALSE);
  confounders <- mbSetObj$dataSet$confs
  
  # get list of confounders to consider
  if(length(confounders)==0){
    current.msg <<- "No confounders inputted!"
    return(0);
  }
  
  #check that confounders do not include variable
  check <- variable %in% confounders
  
  if(check){
    current.msg <<- "Invalid confounders! Variable included."
    return(0)
  }
  
  check2 <- "NA" %in% confounders
  
  if(check2){
    current.msg <<- "NA included as a confounder!"
    return(0)
  }
  
  # create list of confounders
  meta.subset <- metadata[, confounders]
  
  if(class(meta.subset) == "data.frame"){
    meta.subset <- data.frame(apply(meta.subset, 2, function(x) as.numeric(as.character(x))))
    meta.subset <- as.list(meta.subset)
  }else{
    meta.subset <- as.numeric(meta.subset)
    meta.subset <- as.list(as.data.frame(meta.subset))
  }
  
  # check variable is numeric
  var <- metadata[,variable]
  
  if(class(levels(var))=="character"){
    var <- as.numeric(var)
  }
  
  # now get otu data
  if(taxa.lvl=="OTU"){
    taxa_table <- tax_table(mbSetObj$dataSet$proc.phyobj);
    data <- merge_phyloseq(mbSetObj$dataSet$norm.phyobj, taxa_table);
    data1 <- as.matrix(otu_table(data));
  }else{
    #get otu table
    taxa_table <- tax_table(mbSetObj$dataSet$proc.phyobj);
    data <- merge_phyloseq(mbSetObj$dataSet$norm.phyobj, taxa_table);
    #merging at taxonomy levels
    data <- fast_tax_glom_first(data,taxa.lvl);
    nm <- as.character(tax_table(data)[,taxa.lvl]);
    #converting NA values to unassigned
    nm[is.na(nm)] <- "Not_Assigned";
    data1 <- as.matrix(otu_table(data));
    rownames(data1) <- nm;
    #all NA club together
    data1 <- as.matrix(t(sapply(by(data1, rownames(data1), colSums), identity)));
  }
  
  otu.table <- t(data1);
  mbSetObj$analSet$abund_data <- otu.table;
  
  #replace 0s and NAs with small number
  otu.table[otu.table==0|is.na(otu.table)] <- .00001
  
  #more than 1 imp.feat, convert to named list of vectors then perform partial correlation
  if(class(otu.table)=="numeric"){
    otu.subset <- otu.table
    # first calculate corr
    cor.result <- cor.test(otu.subset, var, method=alg)
    cor.results <- data.frame(cor_pval=cor.result$p.value, cor_est=cor.result$estimate)
    # calculate pcorr
    pcor.results <- ppcor::pcor.test(otu.subset, var, meta.subset, method = alg)
    pcor.results <- cbind(cor.results, pcor.results)
  }else{
    otu.subset <- lapply(seq_len(ncol(otu.table)), function(i) otu.table[,i])
    
    # first calculate corr
    cor.results <- do.call(rbind, lapply(otu.subset, function(x){
      cor.result <- cor.test(x, var, method = alg);
      data.frame(cor_pval=cor.result$p.value, cor_est=cor.result$estimate)}))  
    row.names(cor.results) <- colnames(otu.table)
    
    # calculate pcorr
    pcor.fun <- function(feats){ ppcor::pcor.test(feats, var, meta.subset, method = alg) }
    pcor.results <- do.call("rbind", lapply(otu.subset, pcor.fun))
    pcor.results <- cbind(cor.results, pcor.results)
  }
  
  #order results by p.value
  row.names(pcor.results) <- colnames(otu.table)
  resTable <- as.data.frame(pcor.results)
  ord.inx <- order(resTable$p.value);
  resTable <- resTable[ord.inx, , drop=FALSE];
  write.csv(resTable, "partial_corr.csv", row.names = TRUE);
  resTable$taxarank = row.names(pcor.results)
  
  if(.on.public.web){
    .set.mbSetObj(mbSetObj)
    return(1);
  }else{
    return(.set.mbSetObj(mbSetObj))
  }
}

#'Function to update confounders used for partial correlation
#'@description This function updates which confounders will be
#'used to calculate partial correlation.
#'@param mbSetObj Input the name of the mbSetObj.
#'@author Jeff Xia \email{jeff.xia@mcgill.ca}
#'McGill University, Canada
#'License: GNU GPL (>= 2)
#'@export
UpdateConfItems <- function(mbSetObj){
  
  mbSetObj <- .get.mbSetObj(mbSetObj);
  
  if(!exists("conf.vec")){
    current.msg <<- "Cannot find the current list of available metadata!";
    return (0);
  }
  
  #double check validity of metadata
  metadata <- colnames(mbSetObj$dataSet$sample_data)
  check <- metadata[(which(metadata %in% conf.vec))]
  mbSetObj$dataSet$confs <- check
  
  current.msg <<- "Successfully updated selected confounders!";
  
  if(.on.public.web){
    .set.mbSetObj(mbSetObj)
    return(1);
  }else{
    return(.set.mbSetObj(mbSetObj))
  }
}

CleanTaxaNames <- function(mbSetObj, names){

  mbSetObj <- .get.mbSetObj(mbSetObj);
  # first get taxa type
  type <- mbSetObj$dataSet$taxa_type
  
  if(type=="QIIME"){
    new <- gsub("D.*__", "", names)
  }else if(type=="Greengenes"){
    new <- gsub(".*__", "", names)
  }else{
    new <- names
  }
  return(new)
}

