#' @export
#' @importFrom dplyr %>% select group_by summarize arrange distinct top_n distinct count
#' @importFrom stats filter sd
PrepareInputsForClusterLhnData <- function(whichCells, odorDurInMs = 250, numOdors = 36, binStart = 0, binEnd = 3, binSize = 0.1, odorWindow = c(0.5,0.75), doFits = TRUE, fitNumIters = 100000, fitMinIters = 1000, fitDt = 1e-3, fitSlopeRatioToStop = 800, fitNumSlopePoints = 100, plotFits = TRUE, verbose=TRUE, numDelayBootstraps = 10, seed = 0){
############ PART 1 - GRAB THE DATA FROM PHYSPLITDATA

  desc=read.dcf(system.file("DESCRIPTION", package='physplitdata'))
  sha1=unname(desc[,"RemoteSha"])
  desired_sha1="ec3993315ac5d6c7ec0201a6dcba6a6a56636cb8"
  if(!isTRUE(sha1==desired_sha1))
    warning("Installed physplitdata version (",sha1,
            ") differs from desired version (",desired_sha1,").")

    if (numDelayBootstraps>0)
        set.seed(seed);

    dfSubset = subset(physplitdata::PhySplitDB, cell%in%whichCells);
    numCells = nrow(dfSubset);

    df = NULL;
    used = rep(FALSE, numCells);
    for (i in 1:nrow(dfSubset)){
        cell = dfSubset[i,]$cell;
        type = tryCatch({dfSubset[i,]$Anatomy.type}, error = function(e) {NA});
        if (verbose)
            message(sprintf("Processing cell %s, type %s.", cell, type));
        s = physplitdata::Spikes[[as.character(cell)]][[1]];
        if (length(s) == 4){
            odorConf = attr(s, "oddconf");
            channels = odorConf$chan;
            odors   = odorConf$odour;
            duration = unique(odorConf$dur);
            if (length(duration)!= 1){
                if (verbose)
                    message("Duration vector is not scalar, skipping.")
                next;
            }
            ## convert spiketimes list to simplified structure of
            ## list first by odor and then for each of 4 trains
            ## empty trains will be numeric vector length 0
            trains=as.repeatedTrain(s)
            ## now unlist that to get one entry for each odor and trial
            utrains=unlist(trains, recursive=FALSE)
            ## and finally remove the funky spikeTrains class
            utrains= lapply(utrains, unclass)
            tempdf = expand.grid(trial=1:4, odor = names(trains))
            tempdf$spikes=utrains
            tempdf= cbind(tempdf, cell=cell, duration=duration, type=type)
            df=rbind(df, tempdf)
            used[[i]] = TRUE;
        }else{
             if (verbose)
                 print(sprintf("  Expected |s[[1]][[1]]|==4, skipping."));
         }
    }

    if (verbose)
        message(sprintf("%d/%d usable.", sum(used), numCells));

    if (sum(used) != numCells)
        warning("Not all cells were usable.");

############ PART 2 - BIN THE SPIKES
    ## 2.1: Figure out which the top 36 odors are
    if (verbose) message("Determining frequent odors.");
    freqOdors <- (df %>%
                      dplyr::filter(duration==odorDurInMs) %>%
                          select(cell, odor) %>% distinct %>%
                              group_by(odor) %>% count(odor) %>%
                                  arrange(desc(n)) %>% top_n(numOdors,n))$odor;
    if (length(freqOdors) < numOdors)
        stop(sprintf("%d frequent odors required, only %d found.", length(freqOdors), numOdors));
    if (length(freqOdors) > numOdors){
        warning(sprintf("Number of frequent odors %d is greater than desired number of odors %d, taking %d odors.", length(freqOdors), numOdors, numOdors));
        freqOdors = freqOdors[1:numOdors];
    }

    ## 2.2: Figure out which cells have data for all of these odors.
    validCells = (df %>%
                      select(cell, odor, duration) %>%
                          dplyr::filter(duration==odorDurInMs) %>% distinct %>%
                              group_by(cell) %>%
                                  summarize(numOdorsPerCell = sum(odor %in% freqOdors)) %>%
                                      dplyr::filter(numOdorsPerCell >= numOdors))$cell;

    if (length(validCells) != numCells){
        message(sprintf("%d of %d total, (%d remaining) cells had all frequent odors.", length(validCells), numCells, length(unique(df$cell))));
        warning("Number of cells that have all required odors does not equal number of desired cells.");
    }
    else{
        if (verbose)
            message("All cells have the frequent odors.");

    }
    ## 2.3: Grab those
    df = df %>% dplyr::filter((duration == odorDurInMs) & (cell %in% validCells) & (odor %in% freqOdors));

    ## 2.4. Now bin the spikes
    binStarts = seq(binStart, binEnd, by=binSize);
    binStarts = binStarts[binStarts<binEnd];

    BIN_SPIKES = function(df) {
        X = NULL;
        for (i in 1:nrow(df)){
            s = df[[i,"spikes"]];
            b = sapply(binStarts, function (bb) sum(s>=bb & s<bb+binSize))
            X[[i]] = b;
        }
        X
    }

    if (verbose)
        message("Binning spikes.");
    df$binned <- BIN_SPIKES(df);

############ PART 3 - PREPARE THE INPUT AND OUTPUT MATRICES
    tinds   = binStarts;
    numBins = length(tinds);

    x0 = rep(binStarts>=odorWindow[[1]] & binStarts<odorWindow[[2]],4);
    T  = length(x0);

    Ysub   = df %>% dplyr::select(cell,odor,trial,binned);
    cells  = unique(Ysub$cell);
    odors  = unique(Ysub$odor);

    numCells     = length(cells);
    numOdors     = length(odors);

    y = list();
    x = list();
    d = list();
    delay = list();
    delayMu = list();
    delaySd = list();

    nlist = 1;
    for (i in 1:length(cells)){
        for (j in 1:numOdors){
            odorName = as.character(odors[[j]]);
            Yf       = Ysub %>% filter(cell==cells[[i]] & odor==odorName);
            y[[nlist]]   = unlist(Yf$binned);
            if (max(y[[nlist]])==min(y[[nlist]])){
                delay[[nlist]] = 0;
            }else{
                 yy = matrix(y[[nlist]], ncol=4);
                 ym = apply(yy, MARGIN=1, FUN="mean");
                 delay[[nlist]] = EstimateResponseDelayByMomentMatching(ym,x0[1:(length(x0)/4)])$delay;

                 if (numDelayBootstraps == 0){
                     delayMu[[nlist]] = NULL;
                     delaySd[[nlist]] = NULL;
                 }else{
                      trials = matrix(sample(4,size=numDelayBootstraps*4, replace=TRUE),nrow=4);
                      delays = rep(0, numDelayBootstraps);
                      for (ibs in 1:ncol(trials)){
                          ym = apply(yy[,trials[,ibs]], MARGIN=1, FUN="mean");
                          delays[[ibs]] = EstimateResponseDelayByMomentMatching(ym,x0[1:(length(x0)/4)])$delay;
                      }
                      delayMu[[nlist]] = mean(delays);
                      delaySd[[nlist]] = sd(delays);
                  }
            }
            x[[nlist]] = binhf::shift(x0,delay[[nlist]]);
            nlist = nlist + 1
        }
    }
    tstr = sapply(1:T, function (t) sprintf("trial %d bin %d", floor((t-1)/T*4)+1, ((t-1)%%(T/4))+1));
    X = array(as.double(unlist(x)), dim=c(T, numOdors, numCells), dimnames=list(tstr,odors,cells));
    Y = array(unlist(y), dim=c(T, numOdors, numCells), dimnames=list(tstr,odors,cells));
    Ym= apply(array(Y, dim=c(T/4, 4, numOdors, numCells)), MARGIN=c(1,3,4), FUN="mean");
############ PART 4 - FIT THE CELLS
    delay = matrix(delay,ncol=numCells)
    if (!is.null(delaySd)) delaySd = matrix(delaySd,ncol=numCells);
    if (!is.null(delayMu)) delayMu = matrix(delayMu,ncol=numCells);

    Fits = NULL;
    afit = NULL;
    if (doFits){
        afit = array(dim=c(2,numOdors,numCells));
        for (i in 1:numCells){
            if (verbose)
                cat(sprintf("Fitting %s.\n", cells[[i]]));

            Data = list(X=X[,,i], Y=Y[,,i]);
            res = ClusterLhnData(Data, numClusters=1, initMode = "single", numIters=fitNumIters, dt=fitDt, minIters=fitMinIters, slopeRatioToStop = fitSlopeRatioToStop, numSlopePoints=fitNumSlopePoints, verbose=verbose);
            a   = matrix(res$a, nrow=2); ## Drop the singleton dimension.
            afit[,,i] = a;
            Fits[[i]] = list(a = a, al = res$al, v0 = res$v0,l0 =res$l0);

            if (plotFits){
                odorWindowFun = function (whichCell, indOdor, offset) {
                    icell = which(cells == whichCell);
                    iodor = which(dimnames(X)[[2]] == freqOdors[[indOdor]]);
                    ll = apply(matrix(res$Lclust[,iodor,1],ncol=4),1,mean) + offset;
                    tt = (0:(length(ll)-1))*binSize;
                    lines(tt,ll,col=rgb(0,0,0),lwd=2);
                    lines(tt,Ym[,iodor,icell]+offset,col=rgb(0.0,0.75,0.0),lwd=2,lty=1);
                    ## Plot the response onset line:;
                    ## lines(odorWindow[[1]] + delay[[iodor,icell]]*binSize + c(0,0), offset + c(0,4), col="black", lwd=2);
                }
                fileName = sprintf("fitCell_%s", cells[[i]]);

                pdf(file=sprintf("%s.F.pdf",fileName), height=8, width=12);
                par(mfrow=c(1,1), mar=c(4,4,1,1));
                plot(res$F, type="l",xlab="iterations",ylab="objective");
                dev.off();

                suffix = list(list(sprintf("al = %1.3f, v0 = %1.3f, l0 = %1.3f", res$al, res$v0, res$l0)));

                PlotRastersForCells(cells[[i]], odours = odors, fileName = fileName, cex=1, odorWindowFun = odorWindowFun, suffixes = suffix )
            }
        }
    }
    list(X = X, Y = Y, odours = freqOdors, delay = delay,  delaySd = delaySd, delayMu = delayMu, cells=cells, df = df, Fits = Fits, afit = afit);
}
