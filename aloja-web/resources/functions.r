
# Josep Ll. Berral-García
# ALOJA-BSC-MSR hadoop.bsc.es
# 2014-12-11
# Function library for ALOJA-ML

library(stringr);
library(RWeka);
library(devtools);
library(scales);
library(reshape);
library(nnet);
library(session);

set.seed(1234567890);

source('/vagrant/aloja-web/resources/models.r');
source('/vagrant/aloja-web/resources/searchalgs.r');
source('/vagrant/aloja-web/resources/searchrules.r');
source('/vagrant/aloja-web/resources/precision.r');

###############################################################################
# Read datasets and prepare them for usage                                    #
###############################################################################

aloja_get_data <- function (fread, cds = FALSE, hds = FALSE, fproc = NULL)
{
	ds <- read.table(fread,header=T,sep=",");

	if ("End.time" %in% colnames(ds))
	{
		aux <- strptime(ds[,"End.time"],format="%Y%m%d%H%M%S");
		ds[,"End.time"] <- NULL;
	} else {
		aux <- rep(0,nrow(ds));
	}
	names_temp <- colnames(ds);
	ds <- cbind(ds,aux);
	colnames(ds) <- c(names_temp,"End.time");

	if (!("Running.Cost.." %in% colnames(ds)))
	{
		names_temp <- colnames(ds);
		ds <- cbind(ds,rep(0,nrow(ds)));
		colnames(ds) <- c(names_temp,"Running.Cost..");
	}
	
	retval <- ds[,!(colnames(ds) %in% c("X","Exec.Conf","Histogram","PARAVER"))];

	if (!is.null(fproc))
	{
		ds_sub <- ds[,c("Exe.Time","Running.Cost..","Net","Disk","Maps","IO.SFac","Rep","IO.FBuf","Comp","Blk.size","Cluster","End.time")];

		ds_ext <- ds;
		if (cds)
		{
			split <- str_split_fixed(ds[,"Exec.Conf"], "/", 2);
			exec_conf <- str_split_fixed(split[,1], "_", 13);
			aux <- strptime(paste(exec_conf[,1],exec_conf[,2],sep=""),format="%Y%m%d%H%M%S");
			exec_conf <- exec_conf[,-c(1,2)];
			exec_conf <- cbind(matrix(as.character(aux)),exec_conf);
			colnames(exec_conf) <- paste("Conf.",c("Time","Conf","Net","Disk","B","Maps","IO.SFac","Rep","IO.FBuf","Comp","Blk.size","Cluster"),sep="")
			bench_conf <- str_split_fixed(split[,2], "_", 2);
			colnames(bench_conf) <- c("Conf.Benchmark","Conf.Options");
			ds_ext <- cbind(ds_ext,exec_conf,bench_conf);
		}

		if (hds)
		{
			split <- str_split_fixed(ds[,"Histogram"], "/", 2);
			histogram <- str_split_fixed(split[,1], "_", 13);
			colnames(histogram) <- paste("Hist.",c("Date","Time","Conf","Net","Disk","B","Maps","IO.SFac","Rep","IO.FBuf","Comp","Blk.size","Cluster"),sep="")
			bench_hist <- str_split_fixed(split[,2], "_", 2);
			colnames(bench_conf) <- c("Hist.Benchmark","Hist.Options");
			ds_ext <- cbind(ds_ext,histogram,bench_hist);
		}

		write.table(retval,file=paste(fproc,"-pro.csv",sep=""),sep=",",row.names=F);
		write.table(ds_sub,file=paste(fproc,"-sub.csv",sep=""),sep=",",row.names=F);
		if (cds || hds) write.table(ds_ext,file=paste(fproc,"-ext.csv",sep=""),sep=",",row.names=F);
	}

	retval;
}

###############################################################################
# Print summaries for each benchmark                                          #
###############################################################################

aloja_print_summaries <- function (ds, sname = NULL, vin = NULL, ms = 10, fprint = NULL, fwidth = 1000, html = 0)
{
	if (!is.integer(html)) html <- as.integer(html);

	if (!is.null(fprint))
	{
		sink(file=paste(fprint,'-summary.data',sep=""),append=FALSE,type="output");
		aux_tmp <- getOption("width");
		options(width=fwidth);
	}

	if (is.null(vin)) vin <- colnames(ds);

	if (is.null(sname))
	{
		sry1 <- summary(ds[,vin],maxsum=ms);
		if (html == 1)
		{
			cat("<div class='levelhead'>Summary for Selected Data</div>");
			cat(aloja_print_summary_html(sry1));
		}
		if (html == 0)
		{
			cat("Summary for Selected Data","\n");
			print(sry1);
		}

	} else	{
		for (name in levels(ds[,sname]))
		{
			sry1 <- summary(ds[ds[,sname]==name,vin],maxsum=ms);
			if (html == 1)
			{
				cat("<div class='levelhead'>Summary per",sname,name,"</div>");
				cat(aloja_print_summary_html(sry1));
			}
			if (html == 0)
			{
				cat("\n","Summary per",sname,name,"\n");
				print(sry1);
			}
		}
	}

	if (!is.null(fprint))
	{
		sink(NULL);
		options(width=aux_tmp);
	}
}

aloja_print_individual_summaries <- function (ds, rval = NULL, cval = NULL, joined = 1, vin = NULL, ms = 10, fprint = NULL, fwidth = 1000, html = 0)
{
	if (!is.integer(html)) html <- as.integer(html);

	if (!is.null(fprint))
	{
		sink(file=paste(fprint,'-summary.data',sep=""),append=FALSE,type="output");
		aux_tmp <- getOption("width");
		options(width=fwidth);
	}

	if (is.null(vin)) vin <- colnames(ds);

	if (!is.null(rval))
	{
		if (joined == 1)
		{
			sry1 <- summary(ds[ds[,cval] %in% rval,vin],maxsum=ms);
			if (html == 1)
			{
				cat("<div class='levelhead'>Summary for",cval,rval,"</div>");
				cat(aloja_print_summary_html(sry1));
			}
			if (html == 0)
			{
				cat("\n","Summary for",cval,rval,"\n");
				print(sry1);
			}
		} else {
			for(i in rval)
			{
				sry1 <- summary(ds[ds[,cval]==i,vin],maxsum=ms);
				if (html == 1)
				{
					cat("<div class='levelhead'>Summary for",cval,i,"</div>");
					cat(aloja_print_summary_html(sry1));
				}
				if (html == 0)
				{
					cat("\n","Summary for",cval,i,"\n");
					print(sry1);
				}
			}
		}
	} else {
		for(i in levels(ds[,cval]))
		{
			sry1 <- summary(ds[ds[,cval]==i,vin],maxsum=ms);
			if (html == 1)
			{
				cat("<div class='levelhead'>Summary for",cval,i,"</div>");
				cat(aloja_print_summary_html(sry1));
			}
			if (html == 0)
			{
				cat("\n","Summary for",cval,i,"\n");
				print(sry1);
			}
		}
	}

	if (!is.null(fprint))
	{
		sink(NULL);
		options(width=aux_tmp);
	}
}

aloja_print_summary_json <- function (ds)
{
	strout <- NULL;
	df <- as.data.frame(ds);
	for (i in levels(df$Var2))
	{
		strinfo <- paste(as.character(df[df$Var2 == i & !is.na(df$Freq),"Freq"]),collapse=",");
		strinfo <- gsub(":", "=", strinfo);
		straux <- paste("[",i," : {",strinfo,"}]",sep="");
		straux <- gsub("\\s", "", straux);
		strout <- paste(strout,straux,sep=',');
	}
	strout <- substring(strout, 2);
	strout;
}

aloja_print_summary_html <- function (ds)
{
	strout <- "";
	df <- as.data.frame(ds);
	for (i in levels(df$Var2))
	{
		strinfo <- paste(as.character(df[df$Var2 == i & !is.na(df$Freq),"Freq"]),collapse="</td></tr><tr><td>");
		strinfo <- gsub(":", "</td><td>", strinfo);
		strinfo <- gsub("\\s", "", strinfo);
		iaux <- gsub("\\s", "", i);
		straux <- paste("<table class='summarytable'><tr><td class='level'>",iaux,"</td></tr><tr><td>","<table class='leveltable'><tr><td>",strinfo,"</td></tr></table>","</td></tr></table>",sep="");
		strout <- paste(strout,straux,sep='');
	}
	strout <- paste("<div class='benchtable'>",strout,"</div><br/>",sep='');
	strout;
}

aloja_crossvariables <- function (ds, pnglabel = "cross", jfactor = 0)
{
	numaux <- sapply(data.frame(ds), is.numeric);

	system("mkdir -p temp");
	for (var1 in 1:(ncol(ds)-1))
	{
		if (numaux[var1])
		{
			auxdata1 <- ds[,var1];
		} else {
			auxdata1 <- match(as.factor(ds[,var1]),levels(as.factor(ds[,var1])));
		}
		auxlabel1 <- colnames(ds)[var1];

		for (var2 in (var1 + 1):ncol(ds))
		{
			if (numaux[var2])
			{
				auxdata2 <- ds[,var2];
			} else {
				auxdata2 <- match(as.factor(ds[,var2]),levels(as.factor(ds[,var2])));
			}
			auxlabel2 <- colnames(ds)[var2];

			auxframe <- na.omit(data.frame(auxdata1, auxdata2));
			png(paste("temp/",pnglabel,"-",var1,"-",var2,".png",sep=""),width=1000,height=500);
				if (!numaux[var2]) par(oma=c(0,0,0,2));
				plot(jitter(auxframe[,1],factor=jfactor),jitter(auxframe[,2],factor=jfactor),xlim=c(min(auxframe[,1]),max(auxframe[,1])),ylim=c(min(auxframe[,2]),max(auxframe[,2])), xlab=auxlabel1, ylab=auxlabel2);
				if (!numaux[var1]) axis(3, at=seq(1,length(levels(as.factor(ds[,var1])))), labels=levels(as.factor(ds[,var1])), las=2);
				if (!numaux[var2]) axis(4, at=seq(1,length(levels(as.factor(ds[,var2])))), labels=levels(as.factor(ds[,var2])), las=2);
			dev.off();
		}		
	}
}

###############################################################################
# ANOVA of current variables                                                  #
###############################################################################

aloja_anova <- function (ds)
{
	anova_1 <- list();
	anova_1[["alpha"]] <- 0.05;
	anova_1[["N"]] <- NULL;
	anova_1[["K"]] <- NULL;
	anova_1[["gmean"]] <- NULL;
	anova_1[["ssb"]] <- 0;
	anova_1[["ssw"]] <- 0;
	anova_1[["mse"]] <- NULL;
	anova_1[["f"]] <- NULL;

	bmks <- list();
	anova_1[["means"]] <- list();
	anova_1[["stdevs"]] <- list();

	for (i in levels(ds[,"Benchmark"]))
	{
		bmks[[i]] <- ds[ds[,"Benchmark"]==i,c("Exe.Time","Net","Disk","Maps","IO.SFac","Rep","IO.FBuf","Comp","Blk.size","Cluster")];
		anova_1$means[[i]] <- mean(bmks[[i]][,"Exe.Time"]);
		anova_1$stdevs[[i]] <- sd(bmks[[i]][,"Exe.Time"]);
	}
	anova_1$gmean <- mean(rapply(anova_1$means,function(x) x));

	for (i in levels(ds[,"Benchmark"]))
	{
		anova_1$ssb <- anova_1$ssb + (length(bmks[[i]][,"Exe.Time"]) * (anova_1$means[[i]] - anova_1$gmean)^2);
	}

	anova_1$N <- nrow(ds);
	anova_1$K <- length(levels(ds[,"Benchmark"]));
	for (i in 1:anova_1$N)
	{
		anova_1$ssw <- anova_1$ssw + (ds[i,"Exe.Time"] - anova_1$means[[ds[i,"Benchmark"]]])^2;
	}
	anova_1$mse <- anova_1$ssw / (anova_1$N - anova_1$K);
	anova_1$f <- (anova_1$ssb / (anova_1$K - 1)) / anova_1$mse;
	anova_1$critical <- qf(1-anova_1$alpha, anova_1$K-1, anova_1$N-1);

	print (c("Means are equal: ",anova_1$f < anova_1$critical));

	anova_1;
}

###############################################################################
# Dataset splitting functions                                                 #
###############################################################################

aloja_split_dataset <- function (ds, vin, vout, tsplit, vsplit)
{
	retval <- list();

	aux <- ds[,c("ID",vout,vin)];
	retval[["dataset"]] <- aux;

	samples <- min(nrow(aux)*tsplit,nrow(aux)-1);
	selected <- sample(1:nrow(aux),samples);
	ttaux <- aux[selected,];
	ntaux <- aux[-selected,];

	retval[["tselected"]] <- selected;
	retval[["testset"]] <- ttaux;

	samples <- min(nrow(ntaux)*vsplit,nrow(ntaux)-1);
	selected <- sample(1:nrow(ntaux),samples);
	traux <- ntaux[selected,];
	tvaux <- ntaux[-selected,];

	retval[["rselected"]] <- selected;
	retval[["trainset"]] <- traux;
	retval[["validset"]] <- tvaux;

	retval;
}

aloja_load_splits <- function (vin, vout, ttaux, traux, tvaux)
{
	retval <- list();

	# Re-Factorization of Data
	retval[["dataset"]] <- aloja_dbind(aloja_dbind(ttaux[,c("ID",vout,vin)],traux[,c("ID",vout,vin)]),tvaux[,c("ID",vout,vin)]);

	retval[["testset"]] <- retval$dataset[retval$dataset[,"ID"] %in% ttaux[,"ID"],];
	retval[["trainset"]] <- retval$dataset[retval$dataset[,"ID"] %in% traux[,"ID"],];
	retval[["validset"]] <- retval$dataset[retval$dataset[,"ID"] %in% tvaux[,"ID"],];

	retval[["tselected"]] <- rownames(retval$testset);
	retval[["rselected"]] <- rownames(retval$trainset);

	retval;
}

aloja_load_testsplit <- function (ds, vin, vout, ttaux, vsplit, exclusion = 0)
{
	retval <- list();

	aux <- ds[,c("ID",vout,vin)];

	if (exclusion==1) ntaux <- aux[!(aux[,"ID"] %in% ttaux[,"ID"]),];
	if (exclusion==0) ntaux <- aux;

	samples <- min(nrow(ntaux)*vsplit,nrow(ntaux)-1);
	selected <- sample(1:nrow(ntaux),samples);
	traux <- ntaux[selected,];
	tvaux <- ntaux[-selected,];

	# Re-Factorization of Data
	retval[["dataset"]] <- aloja_dbind(aloja_dbind(ttaux,traux),tvaux);

	retval[["testset"]] <- retval$dataset[retval$dataset[,"ID"] %in% ttaux[,"ID"],];
	retval[["trainset"]] <- retval$dataset[retval$dataset[,"ID"] %in% traux[,"ID"],];
	retval[["validset"]] <- retval$dataset[retval$dataset[,"ID"] %in% tvaux[,"ID"],];

	retval[["tselected"]] <- rownames(retval$testset);
	retval[["rselected"]] <- rownames(retval$trainset);

	retval;
}

aloja_datafile_load <- function (ds = NULL, vin, vout, ttfile, trfile = NULL, tvfile = NULL, vsplit = 0.66, exclusion = 0)
{
	retval <- list();

	ttaux <- read.table(ttfile,header=T,sep=",")[,c("ID",vout,vin)];

	if (!is.null(trfile) & !is.null(tvfile))
	{
		traux <- read.table(trfile,header=T,sep=",")[,c("ID",vout,vin)];
		tvaux <- read.table(tvfile,header=T,sep=",")[,c("ID",vout,vin)];
	} else {
		aux <- ds[,c("ID",vout,vin)];

		if (exclusion==1) ntaux <- aux[!(aux[,"ID"] %in% ttaux[,"ID"]),];
		if (exclusion==0) ntaux <- aux;

		samples <- min(nrow(ntaux)*vsplit,nrow(ntaux)-1);
		selected <- sample(1:nrow(ntaux),samples);
		traux <- ntaux[selected,];
		tvaux <- ntaux[-selected,];
	}

	# Re-Factorization of Data
	retval[["dataset"]] <- aloja_dbind(aloja_dbind(ttaux,traux),tvaux);

	retval[["testset"]] <- retval$dataset[retval$dataset[,"ID"] %in% ttaux[,"ID"],];
	retval[["trainset"]] <- retval$dataset[retval$dataset[,"ID"] %in% traux[,"ID"],];
	retval[["validset"]] <- retval$dataset[retval$dataset[,"ID"] %in% tvaux[,"ID"],];

	retval[["tselected"]] <- rownames(retval$testset);
	retval[["rselected"]] <- rownames(retval$trainset);

	retval;
}

aloja_load_datasets <- function (ds = NULL, vin, vout, tsplit = NULL, vsplit = NULL, ttaux = NULL, ntaux = NULL, traux = NULL, tvaux = NULL, ttfile = NULL, trfile = NULL, tvfile = NULL)
{
	rt <- NULL;

	if (!is.null(ttfile)) {
		rt <- aloja_datafile_load(ds, vin, vout, ttfile, trfile, tvfile, vsplit);
	} else if (!is.null(ttaux) & !is.null(traux) & !is.null(tvaux)) {
		rt <- aloja_load_splits(vin, vout, ttaux,traux,tvaux);
	} else if (!is.null(ttaux) & is.null(tvaux) & is.null(traux))	{
		rt <- aloja_load_testsplit(ds,vin,vout,ttaux,vsplit);
	} else {
		rt <- aloja_split_dataset(ds,vin,vout,tsplit,vsplit);
	}

	rt;
}

###############################################################################
# Operations and transformation functions                                     #
###############################################################################

aloja_binarize_ds <- function (table_1)
{
	numaux <- sapply(data.frame(table_1), is.numeric);

	binaux <- table_1[,numaux];
	classaux <- table_1[,!numaux];

	if (length(classaux) > 0)
	{
		for (k in 1:length(classaux))
		{
			v <- vector();
			for (i in 1:length(levels(classaux[,k]))) v[levels(classaux[,k])[i]] <- i;

			m <- matrix(0,nrow=length(classaux[,k]),ncol=length(levels(classaux[,k])));
			for (i in 1:length(classaux[,k])) m[i,v[classaux[i,k]]] <- 1;
			colnames(m) <- levels(classaux[,k]);

			binaux <- cbind(binaux,m);
		}
	}
	binaux;
}

aloja_binarize_mixsets <- function (vin, vout, traux = NULL, ntaux = NULL, tvaux = NULL, ttaux = NULL)
{
	retval <- list();

	if (!is.null(traux) && !all(sapply(colnames(traux),function(x) is.numeric(traux[,x])))) traux <- aloja_binarize_ds(traux[,c("ID",vout,vin)]);
	if (!is.null(ntaux) && !all(sapply(colnames(ntaux),function(x) is.numeric(ntaux[,x])))) ntaux <- aloja_binarize_ds(ntaux[,c("ID",vout,vin)]);
	if (!is.null(tvaux) && !all(sapply(colnames(tvaux),function(x) is.numeric(tvaux[,x])))) tvaux <- aloja_binarize_ds(tvaux[,c("ID",vout,vin)]);
	if (!is.null(ttaux) && !all(sapply(colnames(ttaux),function(x) is.numeric(ttaux[,x])))) ttaux <- aloja_binarize_ds(ttaux[,c("ID",vout,vin)]);

	if (!is.null(traux) & !is.null(tvaux) & !is.null(ttaux))
	{
		auxallnames <- unique(c(colnames(traux),colnames(ttaux),colnames(tvaux)));

		for (name in setdiff(auxallnames,colnames(tvaux)))
		{
			auxnames <- colnames(tvaux);
			tvaux <- cbind(tvaux,rep(0,nrow(tvaux))); 
			colnames(tvaux) <- c(auxnames,name);
		}

		for (name in setdiff(auxallnames,colnames(ttaux)))
		{
			auxnames <- colnames(ttaux);
			ttaux <- cbind(ttaux,rep(0,nrow(ttaux))); 
			colnames(ttaux) <- c(auxnames,name);
		}

		for (name in setdiff(auxallnames,colnames(traux)))
		{
			auxnames <- colnames(traux);
			traux <- cbind(traux,rep(0,nrow(traux))); 
			colnames(traux) <- c(auxnames,name);
		}
	}

	if (!is.null(ttaux) & !is.null(ntaux))
	{
		auxallnames <- unique(c(colnames(ntaux),colnames(ttaux)));

		for(name in setdiff(auxallnames,colnames(ntaux)))
		{
			auxnames <- colnames(ntaux);
			ntaux <- cbind(ntaux,rep(0,nrow(ntaux))); 
			colnames(ntaux) <- c(auxnames,name);
		}

		for(name in setdiff(auxallnames,colnames(ttaux)))
		{
			auxnames <- colnames(ttaux);
			ttaux <- cbind(ttaux,rep(0,nrow(ttaux))); 
			colnames(ttaux) <- c(auxnames,name);
		}
	}

	retval[["trset"]] <- traux;
	retval[["ntset"]] <- ntaux;
	retval[["tvset"]] <- tvaux;
	retval[["ttset"]] <- ttaux;
	retval;
}

aloja_binarize_instance <- function (instance, vin, vout, datamodel = NULL, datamodel_file = NULL, as.string = 0)
{
	if (is.null(datamodel)) datamodel <- aloja_get_data(datamodel_file);

	datamodel <- datamodel[,!(colnames(datamodel) %in% c("ID",vout))];

	datainst <- t(as.data.frame(instance));
	colnames(datainst) <- vin;

	for (name_1 in colnames(datamodel))
	{
		if (name_1 %in% colnames(datainst))
		{
			datamodel[1,name_1] <-datainst[1,name_1];
		} else {
			datamodel[1,name_1] <- 0;
			for (name_2 in colnames(datainst))
			{
				if (!is.na(datainst[,name_2]) && datainst[,name_2] == name_1) datamodel[1,name_1] <- 1;
			}
		}
	}

	if (as.string != 0) { paste(datamodel[1,],collapse=","); } else { datamodel[1,]; }
}

aloja_debinarize_ds <- function (dsbin, vin, ds_ref)
{
	dsdbin <- ds_ref[0,vin];
	for (i in 1:nrow(dsbin))
	{
		daux <- aloja_debinarize_instance(ds_ref,vin,dsbin[i,]);
		dsdbin <- rbind(dsdbin,daux);
	}
	dsdbin;
}

aloja_debinarize_instance <- function (ds, vin, binstance)
{
	dsdbin <- ds[0,vin];									# DS headers, attributes and levels
	levs1 <- sapply(colnames(dsdbin),function(x) levels(ds[,x]));				# Levels

	instance <- NULL;
	for (i in names(levs1))
	{

		if (is.null(levs1[[i]]))
		{
			instance <- c(instance,ceiling(binstance[i]));
		} else {
			values <- binstance[levs1[[i]]];
			if (length(levs1[[i]]) == 1 && values == 1)
			{
				candidate <- levs1[[i]];					# R -> Derp, derp, derp, derp...
			} else if (sum(values) == 0) {
				candidate <- NA;
			} else {
				candidate <- names(values[which(values==max(values))])[1];	# By default, in a draw, we pick the 1st
			}
			instance <- c(instance,candidate); 
		}
	}
	dsdbin[1,] <- data.frame(t(instance),stringsAsFactors=FALSE);

	for (j in colnames(dsdbin)) class(dsdbin[,j]) <- class(ds[0,j]);
	dsdbin;
}

###############################################################################
# Learning methods                                                            #
###############################################################################

aloja_nnet <-  function (ds, vin, vout, tsplit = 0.25, vsplit = 0.66, rmols = TRUE, pngval = NULL, pngtest = NULL, saveall = NULL, ttaux = NULL, ntaux = NULL, traux = NULL, tvaux = NULL, sigma = 3, ttfile = NULL, trfile = NULL, tvfile = NULL, decay = 5e-4, neurons = 3, maxit = 1000, prange = NULL, quiet = 0)
{
	# Fix parameter class in case of CLI string input
	if (!is.null(prange)) prange <- as.numeric(prange);
	if (!is.numeric(tsplit)) tsplit <- as.numeric(tsplit);
	if (!is.numeric(vsplit)) vsplit <- as.numeric(vsplit);
	if (!is.integer(sigma)) sigma <- as.integer(sigma);
	if (!is.null(decay)) decay <- as.numeric(decay);
	if (!is.integer(neurons)) neurons <- as.integer(neurons);
	if (!is.integer(maxit)) maxit <- as.integer(maxit);

	# Binarization of variables
	if (is.null(ds))
	{
		auxset <- aloja_binarize_mixsets(vin,vout,traux=traux,ntaux=ntaux,tvaux=tvaux,ttaux=ttaux);
		vinorig <- vin;
		vin <- unique(c(colnames(auxset$trset),colnames(auxset$tvset),colnames(auxset$ttset)));
	} else {
		dsbaux <- aloja_binarize_ds(ds[,c(vout,vin)]);
		vinorig <- vin;
		vin <- colnames(dsbaux[!(colnames(dsbaux) %in% vout)]);
	}

	# Load and split datasets
	dsid <- NULL;
	if (!is.null(ds))
	{
		dsid <- cbind(ds[,"ID"],dsbaux);
		colnames(dsid) <- c("ID",vout,vin);
		auxset <- list();
		auxset$trset <- NULL;
		auxset$tvset <- NULL;
		auxset$ttset <- NULL;
		auxset$ntset <- NULL;
	}
	rt <- aloja_load_datasets (dsid,vin,vout,tsplit,vsplit,auxset$ttset,auxset$ntset,auxset$trset,auxset$tvset,ttfile,trfile,tvfile);

	# Remove outliers (leap of faith, as vout may not be normal) (Minimum 100 instances to compute outliers)
	if (rmols)
	{
		if (nrow(rt$trainset) > 100)
		{
			rt[["olstrain"]] <- rt$trainset[rt$trainset[,vout] > mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
			rt$trainset <- rt$trainset[rt$trainset[,vout] <= mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
		}
		if (nrow(rt$validset) > 100)
		{
			rt[["olsvalid"]] <- rt$validset[rt$validset[,vout] > mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
			rt$validset <- rt$validset[rt$validset[,vout] <= mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
		}
	}

	# Normalize values
	trauxnorm <- NULL;
	tvauxnorm <- NULL;
	ttauxnorm <- NULL;
	rt[["maxout"]] <- NULL;
	rt[["minout"]] <- NULL;
	for (i in c(vout,vin))
	{
		divisor <- max(c(rt$trainset[,i],rt$validset[,i])); if (divisor == 0) divisor = 1e-15;
		trauxnorm <- cbind(trauxnorm, (rt$trainset[,i]-min(c(rt$trainset[,i],rt$validset[,i])))/divisor);
		tvauxnorm <- cbind(tvauxnorm, (rt$validset[,i]-min(c(rt$trainset[,i],rt$validset[,i])))/divisor);
		ttauxnorm <- cbind(ttauxnorm, (rt$testset[,i]-min(c(rt$trainset[,i],rt$validset[,i])))/divisor); # Same Norm (tr,tv) as not seen before
		rt[["maxout"]] <- c(rt[["maxout"]],divisor);
		rt[["minout"]] <- c(rt[["minout"]],min(c(rt$trainset[,i],rt$validset[,i])));
		trauxnorm[is.na(trauxnorm)] <- 0;
		tvauxnorm[is.na(tvauxnorm)] <- 0;
		ttauxnorm[is.na(ttauxnorm)] <- 0;
	}
	rt[["normtrainset"]] <- trauxnorm;
	rt[["normvalidset"]] <- tvauxnorm;
	rt[["normtestset"]] <- ttauxnorm;
	colnames(rt$normtrainset) <- c(vout,vin);
	colnames(rt$normvalidset) <- c(vout,vin);
	colnames(rt$normtestset) <- c(vout,vin);
	rt[["maxout"]] <- matrix(rt[["maxout"]]);
	rt[["minout"]] <- matrix(rt[["minout"]]);
	rownames(rt[["maxout"]]) <- c(vout,vin);
	rownames(rt[["minout"]]) <- c(vout,vin);

	rt[["ds_original"]] <- ds[,c("ID",vout,vinorig)];
	rt[["varin"]] <- vin;
	rt[["varout"]] <- vout;
	
	# Training and Validation
	rt[["model"]] <- nnet(y=rt$normtrainset[,vout],x=rt$normtrainset[,vin],size=neurons,decay=decay,maxit=maxit);
	rt[["predtrain"]] <- rt$model$fitted.values;
	rt[["predval"]] <- predict(rt$model,newdata=rt$normvalidset[,vin]);
	if (!is.null(prange))
	{
		rt$predtrain[rt$predtrain < prange[1]] <- prange[1];
		rt$predtrain[rt$predtrain > prange[2]] <- prange[2];
		rt$predval[rt$predval < prange[1]] <- prange[1];
		rt$predval[rt$predval > prange[2]] <- prange[2];
	}
	rt[["maeval"]] <- mean(abs(rt$predval*rt$maxout[vout,1]+rt$minout[vout,1] - rt$validset[,vout]));
	rt[["raeval"]] <- mean(abs((rt$predval*rt$maxout[vout,1]+rt$minout[vout,1] - rt$validset[,vout])/rt$validset[,vout]));
	
	if (!is.null(pngval))
	{
		png(paste(pngval,".png",sep=""),width=500,height=500);
		plot(rt$predval,rt$normvalidset[,vout],main=paste("NN 32-5-1, decay",decay,"maxit",maxit));
		abline(0,1);
		dev.off();
	}

	# Testing and evaluation
	rt[["predtest"]] <- predict(rt$model,newdata=rt$normtestset[,vin]);
	if (!is.null(prange))
	{
		rt$predtest[rt$predtest < prange[1]] <- prange[1];
		rt$predtest[rt$predtest > prange[2]] <- prange[2];
	}
	rt[["maetest"]] <- mean(abs(rt$predtest*rt$maxout[vout,1]+rt$minout[vout,1] - rt$testset[,vout])) ;
	rt[["raetest"]] <- mean(abs((rt$predtest*rt$maxout[vout,1]+rt$minout[vout,1] - rt$testset[,vout])/rt$testset[,vout]));

	if (!is.null(pngtest))
	{
		png(paste(pngtest,".png",sep=""),width=1000,height=500);
		par(mfrow=c(1,2));
		plot(rt$predval,rt$normvalidset[,vout],main=paste("NN 32-5-1, decay",decay,"maxit",maxit));
		abline(0,1);
		plot(rt$predtest,rt$normtestset[,vout],main=paste("NN 32-5-1, decay",decay,"maxit",maxit));
		abline(0,1);
		dev.off();
	}
	#plot.nnet(rt$model);
	#plot.nnet(rt$model$wts,rt$model$n);

	if (quiet == 0) print(c(rt$maeval,rt$raeval));
	if (quiet == 0) print(c(rt$maetest,rt$raetest));

	# Debinarize datasets
	rt$trainset <- aloja_debinarize_ds(rt$trainset,colnames(rt$ds_original),rt$ds_original);
	rt$validset <- aloja_debinarize_ds(rt$validset,colnames(rt$ds_original),rt$ds_original);
	rt$testset <- aloja_debinarize_ds(rt$testset,colnames(rt$ds_original),rt$ds_original);

	if (!is.null(saveall))
	{
		aloja_save_model(rt$model,tagname=saveall);
		aloja_save_object(rt,tagname=saveall);
		aloja_save_predictions(rt$dataset,rt$ds_original,rt$trainset,rt$predtrain*rt$maxout[vout,1]+rt$minout[vout,1],rt$validset,rt$predval*rt$maxout[vout,1]+rt$minout[vout,1],rt$testset,rt$predtest*rt$maxout[vout,1]+rt$minout[vout,1],testname=saveall);
	}

	rt;
}

aloja_linreg <- function (ds, vin, vout, tsplit = 0.25, vsplit = 0.66, rmols = TRUE, pngval = NULL, pngtest = NULL, saveall = NULL, ttaux = NULL, ntaux = NULL, traux = NULL, tvaux = NULL, sigma = 3, ttfile = NULL, trfile = NULL, tvfile = NULL, ppoly = 1, prange = NULL, quiet = 0)
{
	# Fix parameter class in case of CLI string input
	if (!is.null(prange)) prange <- as.numeric(prange);
	if (!is.numeric(tsplit)) tsplit <- as.numeric(tsplit);
	if (!is.numeric(vsplit)) vsplit <- as.numeric(vsplit);
	if (!is.integer(sigma)) sigma <- as.integer(sigma);
	if (!is.integer(ppoly)) ppoly <- as.integer(ppoly);

	# Prevent prediction startle because of singularities
	options(warn=-1);

	# Binarization of variables
	if (is.null(ds))
	{
		auxset <- aloja_binarize_mixsets(vin,vout,traux=traux,ntaux=ntaux,tvaux=tvaux,ttaux=ttaux);
		vinorig <- vin;
		vin <- unique(c(colnames(auxset$trset),colnames(auxset$tvset),colnames(auxset$ttset)));
	} else {
		dsbaux <- aloja_binarize_ds(ds[,c(vout,vin)]);
		vinorig <- vin;
		vin <- colnames(dsbaux[!(colnames(dsbaux) %in% vout)]);
	}

	# Load and split datasets
	dsid <- NULL;
	if (!is.null(ds))
	{
		dsid <- cbind(ds[,"ID"],dsbaux);
		colnames(dsid) <- c("ID",vout,vin);
		auxset <- list();
		auxset$trset <- NULL;
		auxset$tvset <- NULL;
		auxset$ttset <- NULL;
		auxset$ntset <- NULL;
	}
	rt <- aloja_load_datasets (dsid,vin,vout,tsplit,vsplit,auxset$ttaux,auxset$ntaux,auxset$traux,auxset$tvaux,ttfile,trfile,tvfile);
	rt[["ds_original"]] <- ds[,c("ID",vout,vinorig)];
	rt[["varin"]] <- vin;
	rt[["varout"]] <- vout;

	# Remove outliers (leap of faith, as vout may not be normal) (Minimum 100 instances to compute outliers)
	if (rmols)
	{
		if (nrow(rt$trainset) > 100)
		{
			rt[["olstrain"]] <- rt$trainset[rt$trainset[,vout] > mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
			rt$trainset <- rt$trainset[rt$trainset[,vout] <= mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
		}
		if (nrow(rt$validset) > 100)
		{
			rt[["olsvalid"]] <- rt$validset[rt$validset[,vout] > mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
			rt$validset <- rt$validset[rt$validset[,vout] <= mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
		}
	}

	if (ppoly > 3 || ppoly < 1)
	{
		if (ppoly > 3) ppoly <- 3;
		if (ppoly < 1) ppoly <- 1;
		print(paste("[WARNING] Parameter ppoly not in [1,3]. ppoly=",ppoly," will be used instead",sep=""));
	}
	rt[["ppoly"]] <- ppoly;

	# Training and Validation
	if (ppoly == 1) rt[["model"]] <- lm(formula=rt$trainset[,vout] ~ ., data=data.frame(rt$trainset[,vin]));
	if (ppoly == 2) rt[["model"]] <- lm(formula=rt$trainset[,vout] ~ . + (.)^2, data=data.frame(rt$trainset[,vin]));
	if (ppoly == 3) rt[["model"]] <- lm(formula=rt$trainset[,vout] ~ . + (.)^2 + (.)^3, data=data.frame(rt$trainset[,vin]));
	rt[["predtrain"]] <- rt$model$fitted.values;
	rt[["predval"]] <- predict(rt$model,newdata=data.frame(rt$validset));
	if (!is.null(prange))
	{
		rt$predtrain[rt$predtrain < prange[1]] <- prange[1];
		rt$predtrain[rt$predtrain > prange[2]] <- prange[2];
		rt$predval[rt$predval < prange[1]] <- prange[1];
		rt$predval[rt$predval > prange[2]] <- prange[2];
	}
	rt[["maeval"]] <- mean(abs(rt$predval - rt$validset[,vout]));
	rt[["raeval"]] <- mean(abs((rt$predval - rt$validset[,vout])/rt$validset[,vout]));

	if (!is.null(pngval))
	{
		png(paste(pngval,".png",sep=""),width=500,height=500);
		plot(rt$predval,rt$validset[,vout],main=paste("Polynomial Regression power =",ppoly));
		abline(0,1);
		dev.off();
	}

	# Testing and evaluation
	rt[["predtest"]] <- predict(rt$model,newdata=data.frame(rt$testset));
	if (!is.null(prange))
	{
		rt$predtest[rt$predtest < prange[1]] <- prange[1];
		rt$predtest[rt$predtest > prange[2]] <- prange[2];
	}
	rt[["maetest"]] <- mean(abs(rt$predtest - rt$testset[,vout]));
	rt[["raetest"]] <- mean(abs((rt$predtest - rt$testset[,vout])/rt$testset[,vout]));

	if (!is.null(pngtest))
	{
		png(paste(pngtest,".png",sep=""),width=1000,height=500);
		par(mfrow=c(1,2));
		plot(rt$predval,rt$validset[,vout],main=paste("Polynomial Regression power =",ppoly));
		abline(0,1);
		plot(rt$predtest,rt$testset[,vout],main=paste("Test Polynomial Regression power =",ppoly));
		abline(0,1);
		dev.off();
	}

	if (quiet == 0) print(c(rt$maeval,rt$raeval));
	if (quiet == 0) print(c(rt$maetest,rt$raetest));

	# Debinarize datasets
	rt$trainset <- aloja_debinarize_ds(rt$trainset,colnames(rt$ds_original),rt$ds_original);
	rt$validset <- aloja_debinarize_ds(rt$validset,colnames(rt$ds_original),rt$ds_original);
	rt$testset <- aloja_debinarize_ds(rt$testset,colnames(rt$ds_original),rt$ds_original);

	if (!is.null(saveall))
	{
		aloja_save_model(rt$model,tagname=saveall);
		aloja_save_object(rt,tagname=saveall);
		aloja_save_predictions(rt$dataset,rt$ds_original,rt$trainset,rt$predtrain,rt$validset,rt$predval,rt$testset,rt$predtest,testname=saveall);
	}

	rt;
}

aloja_nneighbors <- function (ds, vin, vout, tsplit = 0.25, vsplit = 0.66, rmols = TRUE, pngval = NULL, pngtest = NULL, saveall = NULL, ttaux = NULL, ntaux = NULL, traux = NULL, tvaux = NULL, sigma = 3, ttfile = NULL, trfile = NULL, tvfile = NULL, kparam = NULL, iparam = TRUE, quiet = 0)
{
	# Fix parameter class in case of CLI string input
	if (!is.numeric(tsplit)) tsplit <- as.numeric(tsplit);
	if (!is.numeric(vsplit)) vsplit <- as.numeric(vsplit);
	if (!is.integer(sigma)) sigma <- as.integer(sigma);
	if (!is.integer(kparam) && !is.null(kparam)) kparam <- as.integer(kparam);

	# Load and split datasets
	rt <- aloja_load_datasets (ds,vin,vout,tsplit,vsplit,ttaux,ntaux,traux,tvaux,ttfile,trfile,tvfile);
	rt[["ds_original"]] <- ds[,c("ID",vout,vin)];
	rt[["varin"]] <- vin;
	rt[["varout"]] <- vout;

	# Remove outliers (leap of faith, as vout may not be normal) (Minimum 100 instances to compute outliers)
	if (rmols)
	{
		if (nrow(rt$trainset) > 100)
		{
			rt[["olstrain"]] <- rt$trainset[rt$trainset[,vout] > mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
			rt$trainset <- rt$trainset[rt$trainset[,vout] <= mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
		}
		if (nrow(rt$validset) > 100)
		{
			rt[["olsvalid"]] <- rt$validset[rt$validset[,vout] > mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
			rt$validset <- rt$validset[rt$validset[,vout] <= mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
		}
	}

	rt[["kparam"]] <- kparam;
	rt[["iparam"]] <- iparam;

	# Training and Validation
	if (is.null(kparam))
	{
		rt[["selected_model"]] <- aloja_knn_select(vout, vin, rt$trainset, rt$validset, c("1","2","3","5","10","25","50","100"), iparam, quiet);
		kparam <- rt$selected_model$kmin;
	}
	rt[["model"]] <- IBk(formula=rt$trainset[,vout] ~ . , data = rt$trainset[,vin], control = Weka_control(K = kparam, I = iparam));
	#evaluate_Weka_classifier(rt[["model"]], numFolds = 10);
	rt[["predtrain"]] <- rt$model$predictions;
	rt[["predval"]] <- predict(rt$model,newdata=rt$validset);
	rt[["maeval"]] <- mean(abs(rt$predval - rt$validset[,vout]));
	rt[["raeval"]] <- mean(abs((rt$predval - rt$validset[,vout])/rt$validset[,vout]));

	if (!is.null(pngval))
	{
		png(paste(pngval,".png",sep=""),width=1000,height=500);
		par(mfrow=c(1,2));
		plot(rt$predval,rt$validset[,vout],main=paste("K-NN K =",kparam,ifelse(iparam,"Weight = Inv.Dist.","")));
		abline(0,1);
		if (!is.null(rt$selected_model))
		{
			plot(rt$selected_model$trmae,ylim=c(min(c(rt$selected_model$trmae,rt$selected_model$tvmae)),max(rt$selected_model$trmae,rt$selected_model$tvmae)),main="Error vs K");
			points(rt$selected_model$tvmae,col="red");
			legend("topleft",pch=1,c("trmae","tvmae"),col=c("black","red"));
		}
		dev.off();
	}

	# Testing and evaluation
	rt[["predtest"]] <- predict(rt$model,newdata=rt$testset);
	rt[["maetest"]] <- mean(abs(rt$predtest - rt$testset[,vout]));
	rt[["raetest"]] <- mean(abs((rt$predtest - rt$testset[,vout])/rt$testset[,vout]));

	if (!is.null(pngtest))
	{
		png(paste(pngtest,".png",sep=""),width=1000,height=500);
		par(mfrow=c(1,2));
		plot(rt$predval,rt$validset[,vout],main=paste("Best Validation k-NN K =",kparam));
		abline(0,1);
		plot(rt$predtest,rt$testset[,vout],main=paste("Test k-NN K =",kparam));
		abline(0,1);
		dev.off();
	}

	if (quiet == 0) print(c(rt$maeval,rt$raeval));
	if (quiet == 0) print(c(rt$maetest,rt$raetest));

	if (!is.null(saveall))
	{
		aloja_save_model(rt$model,tagname=saveall,is.weka=TRUE);
		aloja_save_object(rt,tagname=saveall);
		aloja_save_predictions(rt$dataset,rt$ds_original,rt$trainset,rt$predtrain,rt$validset,rt$predval,rt$testset,rt$predtest,testname=saveall);
	}

	rt;
}

aloja_regtree <- function (ds, vin, vout, tsplit = 0.25, vsplit = 0.66, rmols = TRUE, pngval = NULL, pngtest = NULL, saveall = NULL, ttaux = NULL, ntaux = NULL, traux = NULL, tvaux = NULL, sigma = 3, ttfile = NULL, trfile = NULL, tvfile = NULL, mparam = NULL, exsel = NULL, prange = NULL, weka.tree = 1, quiet = 0)
{
	# Fix parameter class in case of CLI string input
	if (!is.null(prange)) prange <- as.numeric(prange);
	if (!is.numeric(tsplit)) tsplit <- as.numeric(tsplit);
	if (!is.numeric(vsplit)) vsplit <- as.numeric(vsplit);
	if (!is.integer(sigma)) sigma <- as.integer(sigma);
	if (!is.integer(mparam) && !is.null(mparam)) mparam <- as.integer(mparam);
	if (!is.integer(quiet)) quiet <- as.integer(quiet);
	if (!is.integer(weka.tree)) weka.tree <- as.integer(weka.tree);

	if (weka.tree == 0)
	{
		# Prevent prediction startle because of singularities
		options(warn=-1);

		# Binarization of variables
		dsbaux <- aloja_binarize_ds(ds[,c(vout,vin)]);
		auxset <- aloja_binarize_mixsets(vin,vout,traux=traux,ntaux=ntaux,tvaux=tvaux,ttaux=ttaux);
		vinorig <- vin;
		vin <- colnames(dsbaux[!(colnames(dsbaux) %in% vout)]);
	}

	# Load and split datasets
	if (weka.tree == 0)
	{
		dsid <- cbind(ds[,"ID"],dsbaux);
		colnames(dsid) <- c("ID",vout,vin);
		rt <- aloja_load_datasets (dsid,vin,vout,tsplit,vsplit,auxset$ttaux,auxset$ntaux,auxset$traux,auxset$tvaux,ttfile,trfile,tvfile);
		rt[["ds_original"]] <- ds[,c("ID",vout,vinorig)];	
	} else {
		rt <- aloja_load_datasets (ds,vin,vout,tsplit,vsplit,ttaux,ntaux,traux,tvaux,ttfile,trfile,tvfile);
		rt[["ds_original"]] <- ds[,c("ID",vout,vin)];	
	}
	rt[["varin"]] <- vin;
	rt[["varout"]] <- vout;

	# Example selection from a threshold, balancing outputs
	if (!is.null(exsel))
	{
		ntaux <- rbind(rt$trainset,rt$validset);
		upperaux <- ntaux[ntaux[,vout] > exsel,];
		loweraux <- ntaux[ntaux[,vout] <= exsel,];

		uppersel <- sample(1:nrow(upperaux),nrow(upperaux)*vsplit);
		lowersel <- sample(1:nrow(loweraux),nrow(loweraux)*vsplit);

		rt$trainset <- rbind(upperaux[uppersel,],loweraux[lowersel,]);
		rt$validset <- rbind(upperaux[-uppersel,],loweraux[-lowersel,]);
	}

	# Remove outliers (leap of faith, as vout may not be normal) (Minimum 100 instances to compute outliers)
	if (rmols)
	{
		if (nrow(rt$trainset) > 100)
		{
			rt[["olstrain"]] <- rt$trainset[rt$trainset[,vout] > mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
			rt$trainset <- rt$trainset[rt$trainset[,vout] <= mean(rt$trainset[,vout]) + sigma * sd(rt$trainset[,vout]),];
		}
		if (nrow(rt$validset) > 100)
		{
			rt[["olsvalid"]] <- rt$validset[rt$validset[,vout] > mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
			rt$validset <- rt$validset[rt$validset[,vout] <= mean(rt$validset[,vout]) + sigma * sd(rt$validset[,vout]),];
		}
	}

	# Training and Validation
	if (is.null(mparam))
	{
		rt[["selected_model"]] <- aloja_m5p_select(vout, vin, rt$trainset, rt$validset, c("1","2","5","10","25","50","75","100","150","200"),weka.tree=weka.tree,quiet=quiet);
		mparam <- rt$selected_model$mmin;
	}
	if (weka.tree == 0)
	{
		rt[["model"]] <- qrt.tree(formula=vout~.,dataset=data.frame(rt$trainset[,c(vout,vin)]),m=mparam)
		rt[["predtrain"]] <- rt$model$fitted.values;
		rt[["predval"]] <- qrt.predict(model=rt$model,newdata=data.frame(rt$validset[,c(vout,vin)]));
	} else {
		rt[["model"]] <- M5P(formula=rt$trainset[,vout] ~ .,data=data.frame(rt$trainset[,vin]), control = Weka_control(M = mparam));
		rt[["predtrain"]] <- rt$model$predictions;
		rt[["predval"]] <- predict(rt$model,newdata=data.frame(rt$validset));
	}
	if (!is.null(prange))
	{
		rt$predtrain[rt$predtrain < prange[1]] <- prange[1];
		rt$predtrain[rt$predtrain > prange[2]] <- prange[2];
		rt$predval[rt$predval < prange[1]] <- prange[1];
		rt$predval[rt$predval > prange[2]] <- prange[2];
	}
	rt[["maeval"]] <- mean(abs(rt$predval - rt$validset[,vout]));
	rt[["raeval"]] <- mean(abs((rt$predval - rt$validset[,vout])/rt$validset[,vout]));

	if (!is.null(pngval))
	{
		png(paste(pngval,".png",sep=""),width=1000,height=500);
		par(mfrow=c(1,2));
		plot(rt$predval,rt$validset[,vout],main=paste("Best Validation M5P M = ",mparam));
		abline(0,1);
		if (!is.null(rt$selected_model))
		{
			plot(rt$selected_model$trmae,ylim=c(min(c(rt$selected_model$trmae,rt$selected_model$tvmae)),max(rt$selected_model$trmae,rt$selected_model$tvmae)),main="Error vs M");
			points(rt$selected_model$tvmae,col="red");
			legend("topleft",pch=1,c("trmae","tvmae"),col=c("black","red"));
		}
		dev.off();
	}

	# Testing and evaluation
	if (weka.tree == 0)
	{
		rt[["predtest"]] <- qrt.predict(model=rt$model,newdata=data.frame(rt$testset[,c(vout,vin)]));
	} else {
		rt[["predtest"]] <- predict(rt$model,newdata=data.frame(rt$testset));
	}
	if (!is.null(prange))
	{
		rt$predtest[rt$predtest < prange[1]] <- prange[1];
		rt$predtest[rt$predtest > prange[2]] <- prange[2];
	}
	rt[["maetest"]] <- mean(abs(rt$predtest - rt$testset[,vout]));
	rt[["raetest"]] <- mean(abs((rt$predtest - rt$testset[,vout])/rt$testset[,vout]));

	if (!is.null(pngtest))
	{
		png(paste(pngtest,".png",sep=""),width=1000,height=500);
		par(mfrow=c(1,2));
		plot(rt$predval,rt$validset[,vout],main=paste("Best Validation M5P M = ",rt$selected_model$mmin));
		abline(0,1);
		plot(rt$predtest,rt$testset[,vout],main=paste("Test M5P M = ",rt$selected_model$mmin));
		abline(0,1);
		dev.off();
	}

	if (quiet == 0) print(c(rt$maeval,rt$raeval));
	if (quiet == 0) print(c(rt$maetest,rt$raetest));

	if (!is.null(saveall))
	{
		if (weka.tree == 0)
		{
			aloja_save_model(rt$model,tagname=saveall);
		} else {
			aloja_save_model(rt$model,tagname=saveall,is.weka=TRUE);
		}
		aloja_save_object(rt,tagname=saveall);
		aloja_save_predictions(rt$dataset,rt$ds_original,rt$trainset,rt$predtrain,rt$validset,rt$predval,rt$testset,rt$predtest,testname=saveall);
	}

	rt;
}

###############################################################################
# Predicting methods                                                          #
###############################################################################

wrapper_predict_dataset <- function(idx,learned_model,vin,ds)
{
	dummy <- "Initialize this environment, you R fucking moron!";
	pred_aux <- aloja_predict_individual_instance (vin=vin,learned_model=learned_model,inst_predict=ds[idx,]);
	return (pred_aux);
}

wrapper_predict_individual_instance <- function(idx,learned_model,vin,instances)
{
	dummy <- "Initialize this environment, you R fucking moron!";
	pred_aux <- aloja_predict_individual_instance (vin=vin,learned_model=learned_model,inst_predict=instances[idx,]);
	laux <- c(paste(sapply(instances[idx,],function(x) as.character(x)),collapse=","),pred_aux);
	return (laux);
}

aloja_predict_dataset <- function (learned_model, vin, ds = NULL, data_file = NULL, sfCPU = 1)
{
	if (!is.integer(sfCPU)) sfCPU <- as.integer(sfCPU);

	retval <- NULL;
	if (is.null(ds) && is.null(data_file))
	{
		retval;
	}

	vin <- sub(' ','.',vin);

	if (!is.null(data_file))
	{
		fileset <- read.table(file=data_file,header=T,sep=",");
		daux <- aloja_dbind(learned_model$ds_original[,vin],fileset[,vin]);
		ds <- daux[nrow(learned_model$ds_original):nrow(daux),];
	} else {
		ds <- ds[,vin];
	}

	if ("snowfall" %in% installed.packages() && sfCPU > 1)
	{
		library(snowfall);
		sfInit(parallel=TRUE, cpus=sfCPU);
		sfExport(list=c("vin","ds","learned_model","aloja_predict_individual_instance"),local=TRUE);
		fyr <- sfLapply(1:nrow(ds), wrapper_predict_dataset,learned_model=learned_model,vin=vin,ds=ds);
		sfStop();
		retval <- unlist(fyr);
	} else {
		for (i in 1:nrow(ds))
		{
			pred_aux <- aloja_predict_individual_instance (learned_model, vin, ds[i,]);
			retval <- c(retval, pred_aux);
		}
	}
	retval;
}

aloja_unfold_expression <- function (expression, vin, reference_model)
{
	plist <- list();
	for (i in 1:length(expression))
	{
		if (expression[i]=="*")
		{
			if (vin[i] %in% colnames(reference_model$dataset))
			{
				caux <- reference_model$dataset[,vin[i]];
			} else {
				caux <- reference_model$ds_original[,vin[i]]; # When Vars are binarized but instance is not.
			}
			if (class(caux)=="factor") plist[[i]] <- levels(caux);
			if (class(caux) %in% c("integer","numeric"))
			{
				#print(paste("[WARNING] * in",i,"is integer. Unique values from learned_model dataset will be used.",sep=" "));
				plist[[i]] <- unique(caux);
			}

		} else if (grepl('[|]',expression[i]) == TRUE)
		{
			plist[[i]] <- strsplit(expression[i],split='\\|')[[1]];
		} else
		{
			plist[[i]] <- expression[i];
		}
	}
	instances <- expand.grid(plist);
	colnames(instances) <- vin;

	for(cname in vin)
	{
		if (class(reference_model$ds_original[,cname])=="integer") instances[,cname] <- as.integer(as.character(instances[,cname]));
		if (class(reference_model$ds_original[,cname])=="numeric") instances[,cname] <- as.numeric(as.character(instances[,cname]));
		if (class(reference_model$ds_original[,cname])=="factor") instances[,cname] <- as.character(instances[,cname]);
	}

	instances;
}

aloja_predict_instance <- function (learned_model, vin, inst_predict, sorted = NULL, sfCPU = 1, saveall = NULL)
{
	if (!is.integer(sfCPU)) sfCPU <- as.integer(sfCPU);
	retval <- NULL;

	if (length(grep(pattern="\\||\\*",inst_predict)) > 0)
	{
		instances <- aloja_unfold_expression(inst_predict,vin,learned_model);

		laux <- list();
		if ("snowfall" %in% installed.packages() && sfCPU > 1)
		{
			library(snowfall);
			sfInit(parallel=TRUE, cpus=sfCPU);
			sfExport(list=c("instances","learned_model","vin","aloja_predict_individual_instance"),local=TRUE);
			laux <- sfLapply(1:nrow(instances), wrapper_predict_individual_instance,learned_model=learned_model,vin=vin,instances=instances);
			sfStop();
		} else {
			for (i in 1:nrow(instances))
			{
				pred_aux <- aloja_predict_individual_instance (learned_model, vin, instances[i,]);
				laux[[i]] <- c(paste(sapply(instances[i,],function(x) as.character(x)),collapse=","),pred_aux);
			}
		}
		daux <- t(as.data.frame(laux));
		daux <- data.frame(Instance=as.character(daux[,1]),Prediction=as.numeric(daux[,2]),stringsAsFactors=FALSE);
		if (is.null(sorted) || !(sorted %in% c("asc","desc")))
		{
			retval <- daux;
		} else {
			retval <- daux[order(daux[,"Prediction"],decreasing=(sorted=="desc")),];
		}

	} else {
		pred_aux <- aloja_predict_individual_instance (learned_model, vin, inst_predict);
		laux <- c(paste(sapply(inst_predict,function(x) as.character(x)),collapse=","),pred_aux);
		daux <- t(as.data.frame(laux));
		retval <- data.frame(Instance=as.character(daux[,1]),Prediction=as.numeric(daux[,2]),stringsAsFactors=FALSE);
	}

	if (!is.null(saveall))
	{
		write.table(retval, file = paste(saveall,"-predictions.data",sep=""), sep = ",", row.names=FALSE);
		write.table(retval, file = paste(saveall,"-stdout.data",sep=""), sep = " ", row.names=TRUE);

		aux <- do.call(rbind,strsplit(retval$Instance,","));
		aux <- cbind(aux,retval$Prediction);
		aux <- cbind(seq(1:nrow(aux)),aux);
		colnames(aux) <- c("ID",vin,learned_model$varout);
		write.table(aux, file = paste(saveall,"-dataset.data",sep=""), sep = ",", row.names=FALSE);
	}
	retval;
}

aloja_predict_individual_instance <- function (learned_model, vin, inst_predict)
{
	ds <- learned_model$dataset;
	model_aux <- learned_model$model;

	inst_aux <- inst_predict;
	if (!is.data.frame(inst_aux))
	{
		inst_aux <- t(as.matrix(inst_aux));
		colnames(inst_aux) <- vin;
	}

	datamodel <- ds[1,learned_model$varin];
	if (class(model_aux)[1]=="list" || class(model_aux)[1]=="lm" || class(model_aux)[1]=="nnet")
	{
		for (name_1 in colnames(datamodel))
		{
			if (name_1 %in% colnames(inst_aux))
			{
				value_aux <- inst_aux[1,name_1];
				class(value_aux) <- class(datamodel[1,name_1]);

				if (class(model_aux)[1]=="nnet")
				{
					value_aux <- (value_aux - learned_model$minout[name_1,]) / learned_model$maxout[name_1,];
				}
				datamodel[1,name_1] <- value_aux;

			} else {
				datamodel[1,name_1] <- 0;
				for (name_2 in colnames(inst_aux))
				{
					if (!is.na(inst_aux[,name_2]) && inst_aux[,name_2] == name_1) datamodel[1,name_1] <- 1;
				}
			}
		}
	} else {
		for (name_1 in colnames(datamodel))
		{
			if (class(datamodel[1,name_1]) == "factor")
			{
				datamodel[1,name_1] <- factor(inst_aux[1,name_1],levels=levels(datamodel[,name_1]));
			} else {
				var_aux <- inst_aux[1,name_1];
				class(var_aux) <- class(datamodel[1,name_1]);
				datamodel[1,name_1] <- var_aux;
			}
		}
	}

	options(warn=-1);

	if (class(model_aux)[1]=="list")
	{
		retval <- qrt.predict(model=model_aux,newdata=data.frame(datamodel));
	} else {
		retval <- predict(model_aux,newdata=data.frame(datamodel));
	}
	if (class(model_aux)[1]=="nnet")
	{
		retval <- (retval * learned_model$maxout[learned_model$varout,]) + learned_model$minout[learned_model$varout,];
	}
	as.vector(retval);
}

###############################################################################
# Fine-tunning parameters for Learning Algorithms                             #
###############################################################################

aloja_m5p_select <- function (vout, vin, traux, tvaux, mintervals, weka.tree = 0, quiet = 1)
{
	trmae <- NULL;
	tvmae <- NULL;
	mmin <- 0;
	mminmae <- 9e+15;
	off_threshold <- 1e-4;
	for (i in mintervals)
	{
		if (weka.tree == 0)
		{
			ml <- qrt.tree(formula=vout~.,dataset=data.frame(traux[,c(vout,vin)]),m=i);
			trmae <- c(trmae, ml$mae);
		} else {
			ml <- M5P(formula=traux[,vout] ~ .,data=data.frame(traux[,vin]), control = Weka_control(M = i));
			mae <- mean(abs(ml$predictions - traux[,vout]));
			trmae <- c(trmae,mae);
		}

		if (weka.tree == 0)
		{
			prediction <- qrt.predict(model=ml,newdata=data.frame(tvaux[,c(vout,vin)]));
		} else {
			prediction <- predict(ml,newdata=data.frame(tvaux));
		}
		mae <- mean(abs(prediction - tvaux[,vout]));
		tvmae <- c(tvmae,mae);

		if (mae < mminmae - off_threshold) { mmin <- i; mminmae <- mae; }
		if (quiet == 0) print(paste("[INFO]",i,mae,mmin,mminmae));
	}
	if (quiet == 0) print (paste("Selected M:",mmin));	

	retval <- list();
	retval[["trmae"]] <- trmae;
	retval[["tvmae"]] <- tvmae;
	retval[["mmin"]] <- mmin;
	retval[["mintervals"]] <- mintervals;
	
	retval;
}

aloja_knn_select <- function (vout, vin, traux, tvaux, kintervals, iparam, quiet = 1)
{
	trmae <- NULL;
	tvmae <- NULL;
	kmin <- 0;
	kminmae <- 9e+15;
	off_threshold <- 1e-4;
	for (i in kintervals)
	{
		ml <- IBk(formula=traux[,vout] ~ .,data=data.frame(traux[,vin]), control = Weka_control(K = i, I = iparam));
		mae <- mean(abs(ml$predictions - traux[,vout]));
		trmae <- c(trmae,mae);

		prediction <- predict(ml,newdata=data.frame(tvaux));
		mae <- mean(abs(prediction - tvaux[,vout]));
		tvmae <- c(tvmae,mae);

		if (mae < kminmae - off_threshold) { kmin <- i; kminmae <- mae; }
	}
	if (quiet == 0) print (paste("Selected K:",kmin));	

	retval <- list();
	retval[["trmae"]] <- trmae;
	retval[["tvmae"]] <- tvmae;
	retval[["kmin"]] <- kmin;
	retval[["kintervals"]] <- kintervals;
	retval[["inverse"]] <- iparam;
	
	retval;
}

###############################################################################
# Outlier Detection Mechanisms                                                #
###############################################################################

wrapper_outlier_dataset <- function(idx,ds,vin,vout,auxjoin,auxjoin_s,thres1,hdistance)
{
	auxout <- 1;
	auxcause <- paste("Resolution:",idx,"- - 1",sep=" ");

	# Check for identical configurations
	idconfs <- which(apply(auxjoin_s,1,function(x) all(x==ds[idx,vin])));
	if (length(idconfs) > 0)
	{
		auxerrs <- c(auxjoin[idconfs,vout] - auxjoin[idconfs,"Pred"]);
		length1 <- length(auxerrs[auxerrs <= thres1]);
		length2 <- length(auxerrs)/2;
		if (length1 > length2)
		{
			auxout <- 2;
			auxcause <- paste("Resolution:",idx,length1,length2,auxout,"by Identical",sep=" ");
		}
	}
	if (auxout < 2 && hdistance > 0)
	{
		# Check for similar configurations (Hamming distance 'hdistance')
		idconfs <- which(apply(auxjoin_s[,vin],1,function(x) sum(x!=ds[idx,vin])) <= hdistance);
		if (length(idconfs) > 0)
		{
			auxerrs <- c(auxjoin[idconfs,vout] - auxjoin[idconfs,"Pred"]);
			length1 <- length(auxerrs[auxerrs <= thres1]);
			length2 <- length(auxerrs)/2;
			if (length1 > length2)
			{
				auxout <- 2;
				auxcause <- paste("Resolution:",idx,length1,length2,auxout,"by Neighbours",sep=" ");
			}
		}
	}
	retval <- list();
	retval$cause <- auxcause;
	retval$resolution <- auxout;
	return(retval);
}

aloja_outlier_dataset <- function (learned_model, vin, vout, ds = NULL, sigma = 3, hdistance = 3, saveall = NULL, sfCPU = 1)
{
	if (!is.integer(sigma)) sigma <- as.integer(sigma);
	if (!is.integer(hdistance)) hdistance <- as.integer(hdistance);
	if (!is.integer(sfCPU)) sfCPU <- as.integer(sfCPU);

	retval <- list();
	retval[["resolutions"]] <- NULL;
	retval[["cause"]] <- NULL;
	retval[["learned_model"]] <- learned_model;
	retval[["vin"]] <- vin;
	retval[["vout"]] <- vout;
	retval[["sigma"]] <- sigma;
	retval[["hdistance"]] <- hdistance;

	# If no DS, validate against itself
	if (is.null(ds)) ds <- learned_model$ds_original;

	retval[["dataset"]] <- ds;
	retval[["predictions"]] <- aloja_predict_dataset(learned_model,vin,ds=ds,sfCPU=sfCPU);

	# Compilation of datasets
	if (all(vin %in% learned_model$varin))
	{
		id_pred <- rbind(learned_model$trainset,learned_model$validset,learned_model$testset);
		id_pred <- cbind(id_pred,c(learned_model$predtrain,learned_model$predval,learned_model$predtest));
		colnames(id_pred) <- c(colnames(learned_model$trainset),"Pred");
		auxjoin <- id_pred;
	} else {
		paux <- rbind(as.matrix(learned_model$predtrain),as.matrix(learned_model$predval),as.matrix(learned_model$predtest));
		rownames(paux) <- c(rownames(learned_model$trainset),rownames(learned_model$validset),rownames(learned_model$testset));
		a <- paux[order(as.numeric(rownames(paux))),];
		b <- merge(learned_model$ds_original,as.matrix(a),by="row.names",all.x=TRUE);
		colnames(b) <- c("Row.names",colnames(learned_model$ds_original),"Pred");
		auxjoin <- b[,c("ID",vout,vin,"Pred")];
	}

	# Compilation of errors (learning)
	trerr <- learned_model$trainset[,vout] - learned_model$predtrain;
	tverr <- learned_model$validset[,vout] - learned_model$predval;
	tterr <- learned_model$testset[,vout] - learned_model$predtest;
	stdev_err <- sd(c(trerr,tverr,tterr));
	mean_err <- mean(c(trerr,tverr,tterr));

	# Vectorization and Pre-calculation [Optimization]
	thres1 <- mean_err + (stdev_err * sigma);
	ifelse("ID" %in% colnames(ds),iaux <- as.numeric(ds[,"ID"]), iaux <- rep(0,nrow(ds))); 
	raux <- as.numeric(ds[,vout]);
	paux <- retval$predictions;
	cond1 <- abs(paux-raux) > thres1;
	auxjoin_s <- apply(auxjoin[,vin],2,function(x) sub("^\\s+","",x));

	retval$resolutions <- data.frame(rep(0,nrow(ds)),paux,raux,apply(ds[,vin],1,function(x) paste(as.character(x),collapse=":")),iaux);
	colnames(retval$resolutions) <- c("Resolution","Model","Observed",paste(vin,collapse=":"),"ID");

	# Check the far points for outliers
	if ("snowfall" %in% installed.packages() && sfCPU > 1)
	{
		library(snowfall);
		sfInit(parallel=TRUE, cpus=sfCPU);
		sfExport(list=c("ds","vin","vout","auxjoin","auxjoin_s","thres1","hdistance"),local=TRUE);
		rets <- sfLapply((1:length(paux))[cond1], wrapper_outlier_dataset,ds=ds,vin=vin,vout=vout,auxjoin=auxjoin,auxjoin_s=auxjoin_s,thres1=thres1,hdistance=hdistance);
		sfStop();
		retval$resolutions[cond1,"Resolution"] <- sapply(1:length(rets),function(x) rets[[x]]$resolution);
		retval$cause <- sapply(1:length(rets),function(x) rets[[x]]$cause);
	} else {
		for (i in (1:length(paux))[cond1])
		{
			auxout <- 1;
			auxcause <- paste("Resolution:",i,"- - 1",sep=" ");

			# Check for identical configurations
			idconfs <- which(apply(auxjoin_s,1,function(x) all(x==ds[i,vin])));
			if (length(idconfs) > 0)
			{
				auxerrs <- c(auxjoin[idconfs,vout] - auxjoin[idconfs,"Pred"]);
				length1 <- length(auxerrs[auxerrs <= thres1]);
				length2 <- length(auxerrs)/2;
				if (length1 > length2)
				{
					auxout <- 2;
					auxcause <- paste("Resolution:",i,length1,length2,auxout,"by Identical",sep=" ");
				}
			}
			if (auxout < 2 && hdistance > 0)
			{
				# Check for similar configurations (Hamming distance 'hdistance')
				idconfs <- which(apply(auxjoin_s[,vin],1,function(x) sum(x!=ds[i,vin])) <= hdistance);
				if (length(idconfs) > 0)
				{
					auxerrs <- c(auxjoin[idconfs,vout] - auxjoin[idconfs,"Pred"]);
					length1 <- length(auxerrs[auxerrs <= thres1]);
					length2 <- length(auxerrs)/2;
					if (length1 > length2)
					{
						auxout <- 2;
						auxcause <- paste("Resolution:",i,length1,length2,auxout,"by Neighbours",sep=" ");
					}
				}
			}
			retval$cause <- c(retval$cause,auxcause);
			retval$resolutions[i,"Resolution"] <- auxout;
		}
	}

	if (!is.null(saveall))
	{
		aloja_save_object(retval,tagname=saveall);
		write.table(x=retval$cause,file=paste(saveall,"-cause.csv",sep=""),row.names=FALSE,col.names=FALSE);
		write.table(x=retval$resolutions,file=paste(saveall,"-resolutions.csv",sep=""),row.names=FALSE,sep=",");
	}

	retval;
}

aloja_outlier_instance <- function (learned_model, vin, vout, instance, observed, display = 0, sfCPU = 1)
{
	if (!is.integer(display)) display <- as.integer(display);

	if (length(grep(pattern="\\||\\*",instance)) > 0)
	{
		instances <- aloja_unfold_expression(instance,vin,learned_model);
		comp_dataset <- cbind(instances,observed);
	} else {
		comp_dataset <- data.frame(cbind(t(instance),observed),stringsAsFactors=FALSE);
	}
	colnames(comp_dataset) <- c(vin,vout);

	result <- aloja_outlier_dataset (learned_model,vin,vout,ds=comp_dataset,sfCPU=sfCPU);

	retval <- NULL;
	if (display == 0) retval <- result;
	if (display == 1) retval <- as.vector(result$resolutions);
	if (display == 2) retval <- as.vector(c(result$resolutions,result$cause));

	retval
}

###############################################################################
# Principal Component Analysis methods                                        #
###############################################################################

aloja_pca <- function (ds, vin, vout, pngpca = NULL, saveall = NULL)
{
	vinaux <- vin;

	dsbin <- aloja_binarize_ds(ds[,c(vout,vin)]);
	vin <- colnames(dsbin[,-1]);

	pc <- princomp(dsbin[,vin]);
	pc[["dataset"]] <- cbind(dataset[,"ID"],dsbin);
	colnames(pc$dataset) <- c("ID",colnames(dsbin));
	pc[["pcaset"]] <- cbind(dataset[,"ID"],dsbin[,vout],pc$scores);
	colnames(pc$pcaset) <- c("ID",vout,colnames(pc$scores));

	pc[["vin_orig"]] <- vinaux;
	pc[["vin"]] <- vin;
	pc[["vout"]] <- vout;

	if (!is.null(pngpca))
	{
		system("mkdir -p temp");
		for (var1 in 1:(length(pc$scores[1,])-1))
		{
			for (var2 in (var1 + 1):ncol(pc$scores))
			{
				png(paste("temp/",pngpca,"-",var1,"-",var2,".png",sep=""),width=1000,height=500);
					plot(1, type="n", xlim=c(min(pc$scores[,var1]),max(pc$scores[,var1])),ylim=c(min(pc$scores[,var2]),max(pc$scores[,var2])), xlab="", ylab="");
					points(jitter(pc$scores[dsbin[,vout]>3000,var1],factor=0.6),jitter(pc$scores[dsbin[,vout]>3000,var2],factor=0.6),col="red");
					points(jitter(pc$scores[dsbin[,vout]>2000 & dsbin[,vout]<3000,var1],factor=0.6),jitter(pc$scores[dsbin[,vout]>2000 & dsbin[,vout]<3000,var2],factor=0.6),col="blue");
					points(jitter(pc$scores[dsbin[,vout]>1000 & dsbin[,vout]<2000,var1],factor=0.6),jitter(pc$scores[dsbin[,vout]>1000 & dsbin[,vout]<2000,var2],factor=0.6),col="green");
					points(jitter(pc$scores[dsbin[,vout]<1000,var1],factor=0.6),jitter(pc$scores[dsbin[,vout]<1000,var2],factor=0.6),col="black");
				dev.off();
			}
		}
	}

	if (!is.null(saveall))
	{
		write.table(pc$dataset, file = paste(saveall,"-dataset.csv",sep=""), sep = ",", row.names=FALSE);
		write.table(pc$pcaset, file = paste(saveall,"-transformed.csv",sep=""), sep = ",", row.names=FALSE);
		aloja_save_object(pc,tagname=saveall);
	}

	pc;
}

aloja_transform_data <- function (ds, pca_obj = NULL, pca_name = NULL, saveall = NULL)
{
	retval <- NULL;
	
	if (is.null(pca_name) && is.null(pca_obj))
	{
		print("[WARNING] No PCA object or file introduced");
		retval;
	}

	if (!is.null(pca_name))	pca_obj <- aloja_load_object(pca_name);

	dsbaux <- aloja_binarize_ds(ds[,pca_obj$vin_orig]);
	vin <- colnames(dsbaux);

	retval[["dataset"]] <- dsbaux;
	retval[["vin"]] <- vin;
	retval[["pca"]] <- pca_obj;

	dspca <- predict(pca_obj,dsbaux);
	retval[["pcaset"]] <- dspca;	

	if (!is.null(saveall))
	{
		write.table(dspca, file = paste(saveall,"-transformed.csv",sep=""), sep = ",", row.names=FALSE);
	}

	retval;
}

aloja_transform_instance <- function (inst_transform, pca_obj = NULL, pca_name = NULL, verbose = 0)
{
	if (!is.integer(verbose)) verbose <- as.integer(verbose);

	retval <- NULL;
	
	if (is.null(pca_name) && is.null(pca_obj))
	{
		print("[WARNING] No PCA object or file introduced");
		retval;
	}

	if (!is.null(pca_name)) pca_obj <- aloja_load_object(pca_name);

	datamodel <- pca_obj$dataset[1,pca_obj$vin];
	for (name_1 in colnames(datamodel))
	{
		if (name_1 %in% pca_obj$vin_orig)
		{
			var_aux <- inst_transform[which(pca_obj$vin_orig==name_1)];
			class(var_aux) <- class(datamodel[1,name_1]);
			datamodel[1,name_1] <- var_aux;
		} else {
			if (length(which(inst_transform==name_1)) >= 1)
			{
				datamodel[1,name_1] <- 1;
			} else {
				datamodel[1,name_1] <- 0;
			}
		}
	}
	vin <- colnames(datamodel);

	retval[["instance"]] <- datamodel;
	retval[["vin"]] <- vin;
	retval[["pca"]] <- pca_obj;

	dspca <- predict(pca_obj,datamodel);
	retval[["pcainst"]] <- dspca;

	if (verbose == 2)
	{
		retval;
	} else if (verbose == 1) {
		retval$pcainst;
	} else {
		paste(retval$pcainst,collapse=",");
	}
}


aloja_dataset_collapse <- function (ds, vin, vout, dimension1, dimension2, dimname1, dimname2, model_obj = NULL, model_name = NULL, saveall = NULL, preds = "after")
{
	retval <- list();

	dsid <- ds[,"ID"];
	ds <- ds[,c(vout,vin)];

	dsaux <- cbind(ds[,vout],apply(as.matrix(ds[,dimension1]),1,paste,collapse=":"),apply(as.matrix(ds[,dimension2]),1,paste,collapse=":"));
	colnames(dsaux) <- c(vout,dimname1,dimname2);

	maux <- matrix(NA,length(levels(as.factor(dsaux[,dimname1]))),length(levels(as.factor(dsaux[,dimname2]))));
	colnames(maux) <- levels(as.factor(dsaux[,dimname2]));
	rownames(maux) <- levels(as.factor(dsaux[,dimname1]));

	midaux <- matrix(NA,length(levels(as.factor(dsaux[,dimname1]))),length(levels(as.factor(dsaux[,dimname2]))));
	colnames(midaux) <- levels(as.factor(dsaux[,dimname2]));
	rownames(midaux) <- levels(as.factor(dsaux[,dimname1]));

	for (i in 1:nrow(dsaux))
	{
		dim1_aux <- dsaux[i,dimname1];
		dim2_aux <- dsaux[i,dimname2];

		midaux[dim1_aux,dim2_aux] <- ifelse(!is.na(midaux[dim1_aux,dim2_aux]),c(midaux[dim1_aux,dim2_aux], dsid[i]),dsid[i]);
		len_aux <- length(midaux[dim1_aux,dim2_aux]);

		prev_val <- ifelse(!is.na(maux[dim1_aux,dim2_aux]),as.numeric(maux[dim1_aux,dim2_aux]),0);
		maux[dim1_aux,dim2_aux] <- (prev_val * (len_aux-1) + as.numeric(dsaux[i,vout])) / len_aux;
	}

	if (!is.null(model_name)) model_obj <- aloja_load_object(model_name);

	# IMPORTANT - NA filling is done AFTER aggregation, so estimated values DO NOT affect aggregation
	if ((preds == "after") && !is.null(model_obj) && all(c(model_obj$varin %in% c(dimension1,dimension2),c(dimension1,dimension2) %in% model_obj$varin)))
	{
		for (i in 1:length(maux))
		{
			if (is.na(maux[i]))
			{
				row_aux <- ((i-1) %% nrow(maux)) + 1;
				col_aux <- ((i-1) %/% nrow(maux)) + 1;

				dim1_aux <- rownames(maux)[row_aux];
				dim2_aux <- colnames(maux)[col_aux];

				inst_aux <- c(strsplit(dim1_aux,split=":")[[1]],strsplit(dim2_aux,split=":")[[1]]);

				maux[i] <- aloja_predict_instance (model_obj,c(dimension1,dimension2),inst_aux);
			}
		}
	}

	# IMPORTANT - NA filling is done simulating values BEFORE aggregation, so estimated values DO affect aggregation
	if ((preds != "after") && !is.null(model_obj))
	{
		for (i in 1:length(maux))
		{
			if (is.na(maux[i]))
			{
				row_aux <- ((i-1) %% nrow(maux)) + 1;
				col_aux <- ((i-1) %/% nrow(maux)) + 1;

				dim1_aux <- rownames(maux)[row_aux];
				dim2_aux <- colnames(maux)[col_aux];

				split1 <- strsplit(dim1_aux,split=":")[[1]];
				split2 <- strsplit(dim2_aux,split=":")[[1]];

				inst_aux <- NULL;
				for (j in 1:length(model_obj$varin))
				{
					if (model_obj$varin[j] %in% dimension1) inst_aux <- c(inst_aux,sub("^\\s+",'',split1[which(dimension1 == model_obj$varin[j])]));
					if (model_obj$varin[j] %in% dimension2) inst_aux <- c(inst_aux,sub("^\\s+",'',split2[which(dimension2 == model_obj$varin[j])]));
					if (!(model_obj$varin[j] %in% c(dimension1,dimension2))) inst_aux <- c(inst_aux,'*');
				}

				piaux <- aloja_predict_instance (model_obj,vin,inst_aux);
				maux[i] <- mean(piaux[,"Prediction"]);
			}
		}
	}

	retval[["matrix"]] <- maux;
	retval[["IDs"]] <- midaux;
	retval[["collapsed"]] <- dimension2;

	if (!is.null(saveall))
	{
		write.table(retval$matrix,file=paste(saveall,"-matrix.csv",sep=""),sep=",",row.names=TRUE);
		write.table(retval$IDs,file=paste(saveall,"-ids.csv",sep=""),sep=",",row.names=TRUE);
		aloja_save_object(retval,tagname=saveall);
	}

	retval;
}

aloja_dataset_collapse_expand <- function (ds, vin, vout, dimension1, dimension2, dimname1, dimname2, inst_general, model_obj = NULL, model_name = NULL, saveall = NULL)
{
	retval <- list();

	datacol_obj <- aloja_dataset_collapse (ds,vin,vout,dimension1,dimension2,dimname1,dimname2);

	if (!is.null(model_name)) model_obj <- aloja_load_object(model_name);
	predicted_obj <- aloja_predict_instance(model_obj,vin,inst_general,sorted=TRUE);

	pmat <- cbind(predicted_obj[,"Prediction"],str_split_fixed(predicted_obj[,"Instance"], ",",length(vin)));
	colnames(pmat) <- c(vout,vin);

	dsaux <- cbind(pmat[,vout],apply(as.matrix(pmat[,dimension1]),1,paste,collapse=":"),apply(as.matrix(pmat[,dimension2]),1,paste,collapse=":"));
	colnames(dsaux) <- c(vout,dimname1,dimname2);

	maux <- matrix(NA,length(levels(as.factor(dsaux[,dimname1]))),length(levels(as.factor(dsaux[,dimname2]))));
	colnames(maux) <- levels(as.factor(dsaux[,dimname2]));
	rownames(maux) <- levels(as.factor(dsaux[,dimname1]));

	midaux <- matrix(NA,length(levels(as.factor(dsaux[,dimname1]))),length(levels(as.factor(dsaux[,dimname2]))));
	colnames(midaux) <- levels(as.factor(dsaux[,dimname2]));
	rownames(midaux) <- levels(as.factor(dsaux[,dimname1]));

	for (i in 1:nrow(dsaux))
	{
		dim1_aux <- dsaux[i,dimname1];
		dim2_aux <- dsaux[i,dimname2];

		midaux[dim1_aux,dim2_aux] <- ifelse(!is.na(midaux[dim1_aux,dim2_aux]),c(midaux[dim1_aux,dim2_aux], i),i);
		len_aux <- length(midaux[dim1_aux,dim2_aux]);

		prev_val <- ifelse(!is.na(maux[dim1_aux,dim2_aux]),as.numeric(maux[dim1_aux,dim2_aux]),0);
		maux[dim1_aux,dim2_aux] <- (prev_val * (len_aux-1) + as.numeric(dsaux[i,vout])) / len_aux;
	}

	cmaux <- matrix(NA,length(levels(as.factor(dsaux[,dimname1]))),length(levels(as.factor(dsaux[,dimname2]))));
	colnames(cmaux) <- levels(as.factor(dsaux[,dimname2]));
	rownames(cmaux) <- levels(as.factor(dsaux[,dimname1]));

	cmidaux <- matrix(NA,length(levels(as.factor(dsaux[,dimname1]))),length(levels(as.factor(dsaux[,dimname2]))));
	colnames(cmidaux) <- levels(as.factor(dsaux[,dimname2]));
	rownames(cmidaux) <- levels(as.factor(dsaux[,dimname1]));

	for (i in 1:nrow(dsaux))
	{
		dim1_aux <- dsaux[i,dimname1];
		dim2_aux <- dsaux[i,dimname2];

		cmaux[dim1_aux,dim2_aux] <- maux[dim1_aux,dim2_aux];
		cmidaux[dim1_aux,dim2_aux] <- 'NA';

		if (dim1_aux %in% rownames(datacol_obj$matrix) && dim2_aux %in% colnames(datacol_obj$matrix))
		{
			if (!is.na(datacol_obj$matrix[dim1_aux,dim2_aux]))
			{
				cmaux[dim1_aux,dim2_aux] <- datacol_obj$matrix[dim1_aux,dim2_aux];
				cmidaux[dim1_aux,dim2_aux] <- datacol_obj$IDs[dim1_aux,dim2_aux];
			}
		} 
	}

	retval[["matrix"]] <- datacol_obj$matrix;
	retval[["pmatrix"]] <- maux;
	retval[["cmatrix"]] <- cmaux;
	retval[["IDs"]] <- datacol_obj$IDs;
	retval[["cIDs"]] <- cmidaux;
	retval[["collapsed"]] <- dimension2;

	if (!is.null(saveall))
	{
		write.table(retval$matrix,file=paste(saveall,"-matrix.csv",sep=""),sep=",",row.names=TRUE);
		write.table(retval$IDs,file=paste(saveall,"-ids.csv",sep=""),sep=",",row.names=TRUE);
		write.table(retval$pmatrix,file=paste(saveall,"-pmatrix.csv",sep=""),sep=",",row.names=TRUE);
		write.table(retval$cmatrix,file=paste(saveall,"-cmatrix.csv",sep=""),sep=",",row.names=TRUE);
		write.table(retval$cIDs,file=paste(saveall,"-cids.csv",sep=""),sep=",",row.names=TRUE);
		aloja_save_object(retval,tagname=saveall);
	}

	retval;
}

aloja_dataset_clustering <- function (datamatrix, k = 3, learned_model = NULL)
{
	if (class(datamatrix) == "character")
	{
		maux <- as.matrix(read.csv(file=datamatrix, header=TRUE, sep=",", check.names=FALSE));
	} else {
		maux <- datamatrix;
	}

	if (!is.null(learned_model) && all(c(learned_model$varin %in% c(dimension1,dimension2),c(dimension1,dimension2) %in% learned_model$varin)))
	{
		for (i in 1:length(maux))
		{
			if (is.na(maux[i]))
			{
				row_aux <- ((i-1) %% nrow(maux)) + 1;
				col_aux <- ((i-1) %/% nrow(maux)) + 1;

				dim1_aux <- rownames(maux)[row_aux];
				dim2_aux <- colnames(maux)[col_aux];

				inst_aux <- c(dim1_aux,strsplit(dim2_aux,split=":")[[1]]);

				maux[i] <- aloja_predict_instance (learned_model,c(dimension1,dimension2),inst_aux);
			}
		}
	} else {
		maux[is.na(maux)] <- 0;
	}
	retval <- kmeans(maux, k);

	retval;
}

###############################################################################
# Example selection methods                                                   #
###############################################################################

aloja_minimal_instances <- function (learned_model, quiet = 0, kmax = 200, step = 10, saveall = NULL)
{
	if (!is.integer(kmax)) kmax <- as.integer(kmax);
	if (!is.integer(step)) step <- as.integer(step);
	if (!is.integer(quiet)) quiet <- as.integer(quiet);

	retval <- list();
	ds <- learned_model$ds_original;
	vout <- learned_model$varout;
	vin <- colnames(learned_model$ds_original)[!(colnames(learned_model$ds_original) %in% c("ID",vout))];

	# Binarization
	dsbin <- aloja_binarize_ds(rbind(learned_model$trainset,learned_model$validset));
	vbin <- colnames(dsbin)[!(colnames(dsbin) %in% c("ID",vout))];

	# Iteration over Clustering
	best.rae <- 9E15;
	retval[["centers"]] <- retval[["raes"]] <- retval[["datasets"]] <- retval[["sizes"]] <- list();
	retval[["best.k"]] <- count <- 0;
	for (k in seq(10,min(kmax,nrow(dsbin)),by=step))
	{
		count <- count + 1;

		# Center Retrieval
		kcaux <- kmeans(dsbin[,c(vbin,vout)], k);

		# De-binarization of Data
		levs1 <- sapply(vin,function(x) levels(ds[,x])); # Levels
		dsdbin <- ds[0,];				 # DS headers, attributes and levels

		weights <- NULL;
		for (j in 1:nrow(kcaux$centers))
		{
			instance <- NULL;
			for (i in names(levs1))
			{

				if (is.null(levs1[[i]]))
				{
					instance <- c(instance,ceiling(kcaux$centers[j,i]));
				} else {
					values <- kcaux$centers[j,levs1[[i]]];
					if (length(levs1[[i]]) == 1 && values == 1)
					{
						candidate <- levs1[[i]];				# R -> Derp, derp, derp, derp...
					} else {
						candidate <- names(which(values==max(values)))[1];	# By default, in a draw, we pick the 1st
					}
					instance <- c(instance,candidate); 
				}
			}
			instance <- c(j,kcaux$centers[j,vout],instance);
			dsdbin[j,] <- data.frame(t(instance),stringsAsFactors=FALSE);
			weights <- c(weights,length(which(kcaux$cluster==j)));
		}
		for (j in colnames(dsdbin)) class(dsdbin[,j]) <- class(ds[0,j]);

		# Testing and comparing
		if ("M5P" %in% class(learned_model$model)) model_new <- aloja_regtree(dsdbin,vin=vin,vout=vout,ttaux=learned_model$testset,vsplit=0.99,quiet=1); # By default, the vsplit is 0.9 training and 0.1 validation
		if ("qrt" %in% class(learned_model$model)) model_new <- aloja_regtree(dsdbin,vin=vin,vout=vout,ttaux=learned_model$testset,vsplit=0.99,quiet=1,weka.tree=0);
		if ("IBk" %in% class(learned_model$model)) model_new <- aloja_nneighbors(dsdbin,vin=vin,vout=vout,ttaux=learned_model$testset,vsplit=0.99,quiet=1);
		if ("nnet" %in% class(learned_model$model)) model_new <- aloja_nnet(dsdbin,vin=vin,vout=vout,ttaux=learned_model$testset,vsplit=0.99,quiet=1);
		if ("lm" %in% class(learned_model$model)) model_new <- aloja_linreg(dsdbin,vin=vin,vout=vout,ttaux=learned_model$testset,vsplit=0.99,quiet=1);

		if (quiet == 0) print(paste(k,model_new$raetest,retval$best.k,best.rae,sep=" "));

		if (best.rae > model_new$raetest)
		{
			best.rae <- model_new$raetest;
			retval$best.k <- k;
		}

		# Save iteration
		retval$centers[[count]] <- kcaux;
		retval$raes[[count]] <- model_new$raetest;
		retval$datasets[[count]] <- dsdbin;
		retval$sizes[[count]] <- weights;
	}

	if (!is.null(saveall))
	{
		write(sapply(retval$sizes,function(x) paste(x,collapse=",")),file=paste(saveall,"-sizes.csv",sep=""));
		write.table(data.frame(K=sapply(retval$datasets,function(x) nrow(x)),RAE=unlist(retval$raes)),file=paste(saveall,"-raes.csv",sep=""),sep=",",row.names=FALSE,col.names=FALSE);
		for (i in 1:count) write.table(retval$datasets[[i]],file=paste(saveall,"-dsk",nrow(retval$datasets[[i]]),".csv",sep=""),sep=",",row.names=FALSE, quote=FALSE);
		aloja_save_object(retval,tagname=saveall);
	}

	retval;
}

###############################################################################
# Characterization methods                                                    #
###############################################################################

aloja_check_similarity <- function (ds_new, ds_gral, vin, vout, var.base, gmodel = NULL, lmodel = NULL, alpha = 0.05)
{
	retval <- list();

	anova1 <- list();
	for (i in levels(ds_gral[,var.base]))
	{
		if (!is.null(gmodel)) model_aux <- gmodel;
		if (!is.null(lmodel[[i]])) model_aux <- lmodel[[i]];
		if (is.null(model_aux))
		{
			print(paste("[ERROR] No suitable model found"));
			NULL;
		}

		ds_aux <- ds_new;
		ds_aux[,var.base] <- i;
		paux1 <- aloja_predict_dataset(learned_model=model_aux,vin=varin,ds=ds_aux[,vin]);
		paux2 <- aloja_predict_dataset(learned_model=model_aux,vin=varin,ds=ds_gral[ds_gral[,var.base]==i,vin]);

		perr1 <- paux1 - ds_aux[,vout];
		perr2 <- paux2 - ds_gral[ds_gral[,var.base]==i,vout];
	
		perry <- c(perr1,perr2);
		group <- rep(1:2,c(length(perr1),length(perr2)));
		daux = data.frame(y = perry, group = factor(group));
		anova1[[i]] <- anova(lm(perry~group,daux));
	}

	result <- t(sapply(lapply(anova1,function(x) x$"Pr(>F)"[1]),unlist));
	retval[["kind"]] <- "Prediction";
	retval[["anova"]] <- anova1;
	retval[["result"]] <- result;

	if (max(result) > alpha)
	{
		retval[["cluster"]] <- colnames(result)[which.max(result)];
		retval[["significance"]] <- max(result);
	}
	retval;
}

aloja_check_cluster <- function (kcluster, bmk.vector) # FIXME - Problema de distàncies amb 2 bmks només
{
	retval <- list();

	distances <- NULL;
	gen_distances <- NULL;
	for (i in 1:nrow(kcluster$centers))
	{
		distances <- c(distances,(sum((kcluster$centers[i,] - bmk.vector$matrix[1,])^2))^(1/2));

		for (j in i:nrow(kcluster$centers))
		{
			if (j == i) next;
			gen_distances <- c(gen_distances,(sum((kcluster$centers[i,] - kcluster$centers[j,])^2))^(1/2));
		}
	}

	retval[["kind"]] <- "Cluster";
	retval[["full.distances"]] <- gen_distances;
	retval[["distances"]] <- distances;

	if (max(gen_distances) > min(distances))
	{
		retval[["cluster"]] <- colnames(result)[which(kcluster$cluster == which.min(distances))];
		retval[["min.distance"]] <- min(distances);
	}
	retval;
}

aloja_best_configurations <- function (bvectors = NULL, bvec_name = NULL)
{
	if (is.null(bvectors) && is.null(bvec_name))
	{
		print("[WARNING] No Vector Matrix object or file introduced");
		NULL;
	}

	if (!is.null(bvec_name)) bvectors <- aloja_load_object(bvec_name);

	result <- data.frame(Config=character(),Variance=numeric(),Benchmarks=integer(),Missing=character(),stringsAsFactors=FALSE);
	for(i in 1:ncol(bvectors$matrix))
	{
		vaux <- var(bvectors$matrix[,i],na.rm=TRUE);
		raux <- is.na(bvectors$matrix[,i]);
		result <- rbind(result,data.frame(Config=colnames(bvectors$matrix)[i],Variance=vaux,Benchmarks=length(raux[raux==FALSE]),Missing=paste(names(raux[raux==TRUE]),collapse=",")));
	}

	colnames(result)[1] <- paste(bvectors$collapsed,collapse=":");
	result[order(-result[,2], -result[,3]),];
}

###############################################################################
# Save the datasets and created models                                        #
###############################################################################

aloja_save_predictions <- function (ds, dsorig, trdata, trpred, tvdata, tvpred, ttdata, ttpred, testname = "default")
{
	traux <- cbind(trdata,trpred);
	tvaux <- cbind(tvdata,tvpred);
	ttaux <- cbind(ttdata,ttpred);

	colnames(traux) <- c(colnames(trdata),"Pred.Exe.Time");
	colnames(tvaux) <- c(colnames(tvdata),"Pred.Exe.Time");
	colnames(ttaux) <- c(colnames(ttdata),"Pred.Exe.Time");

	write.table(ds, file = paste(testname,"-ds.csv",sep=""), sep = ",", row.names=FALSE);
	write.table(dsorig, file = paste(testname,"-dsorig.csv",sep=""), sep = ",", row.names=FALSE);

	write.table(traux, file = paste(testname,"-tr.csv",sep=""), sep = ",", row.names=FALSE);
	write.table(tvaux, file = paste(testname,"-tv.csv",sep=""), sep = ",", row.names=FALSE);
	write.table(ttaux, file = paste(testname,"-tt.csv",sep=""), sep = ",", row.names=FALSE);
}

aloja_save_datasets <- function (traux_0, tvaux_0, ttaux_0, name_0, algor_0)
{
	write.table(tvaux_0, file = paste(algor_0,"-",name_0,"-tv.csv",sep=""), sep = ",");
	write.table(traux_0, file = paste(algor_0,"-",name_0,"-tr.csv",sep=""), sep = ",");
	write.table(ttaux_0, file = paste(algor_0,"-",name_0,"-tt.csv",sep=""), sep = ",");
}

aloja_save_model <- function (model_0, tagname = "default", is.weka = FALSE)
{
	if (is.weka) rJava::.jcache(model_0$classifier);
	saveRDS(model_0,file=paste(tagname,"-model.dat",sep=""));
}

aloja_save_object <- function (object_1, tagname = "default", is.weka = FALSE)
{
	if (!is.null(object_1$model) && is.weka) rJava::.jcache(object_1$model$classifier);
	saveRDS(object_1,file=paste(tagname,"-object.rds",sep=""));
}

aloja_load_model <- function (tagname = "default", is.weka = FALSE)
{
	model_1 <- readRDS(paste(tagname,"-model.dat",sep=""));
	##if (is.weka) rJava::.jstrVal(model_1$classifier);
	model_1;
}

aloja_load_object <- function (tagname = "default", is.weka = FALSE)
{
	object_1 <- readRDS(paste(tagname,"-object.rds",sep=""));
	##if (!is.null(object_1$model) && is.weka) rJava::.jstrVal(object_1model$classifier);
	object_1;
}

aloja_save_status <- function ()
{
	save.session("RData");
	savehistory("Rhistory");
	system(paste("tar cvzf rsession-",Sys.Date(),".tar.gz RData Rhistory",sep=""));
	system("rm RData Rhistory");
}

###############################################################################
# R hacks and operators                                                       #
###############################################################################

':=' <- function(lhs, rhs)
{
	frame <- parent.frame();
	lhs <- as.list(substitute(lhs));
	if (length(lhs) > 1)
		lhs <- lhs[-1];
	if (length(lhs) == 1)
	{
		do.call(`=`, list(lhs[[1]], rhs), envir=frame);
		return(invisible(NULL));
	}
	if (is.function(rhs) || is(rhs, 'formula'))
		rhs <- list(rhs);
	if (length(lhs) > length(rhs))
		rhs <- c(rhs, rep(list(NULL), length(lhs) - length(rhs)));
	for (i in 1:length(lhs))
		do.call(`=`, list(lhs[[i]], rhs[[i]]), envir=frame);
	return(invisible(NULL));
}

aloja_dbind <- function (dataframe_1, dataframe_2)
{
	retval <- data.frame(rep(0,nrow(dataframe_1) + nrow(dataframe_2)));
	cnames <- NULL;
	for (name_1 in colnames(dataframe_1))
	{
		vec_aux <- NULL;
		if (name_1 %in% colnames(dataframe_2))
		{
			cnames <- c(cnames,name_1);
			if (class(dataframe_1[,name_1]) == "factor" || class(dataframe_2[,name_1]) == "factor")
			{
				vec_aux <- c(as.character(dataframe_1[,name_1]),as.character(dataframe_2[,name_1]));
				vec_aux <- as.factor(vec_aux);
			} else if (class(dataframe_1[,name_1]) == "integer" || class(dataframe_2[,name_1]) == "integer") {
				vec_aux <- as.integer(c(dataframe_1[,name_1],dataframe_2[,name_1]));
			} else {
				vec_aux <- c(dataframe_1[,name_1],dataframe_2[,name_1]);
			}
			retval <- data.frame(retval,vec_aux);
		}
	}
	retval <- retval[,-1];
	colnames(retval) <- cnames;
	retval;
}

shannon.entropy <- function(p)
{
	if (min(p) < 0 || sum(p) <= 0) return(NA);
	p.norm <- p[p > 0]/sum(p);
	-sum(log2(p.norm)*p.norm);
}
