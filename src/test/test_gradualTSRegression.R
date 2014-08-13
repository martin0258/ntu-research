# Usage example on SET ratings data
library(nnet)
library(zoo)
set.seed(0)
# Change working directory to "ntu-research/"
# setwd("~/Projects/GitHub/ntu-research/")
source("src/lib/windowing.R")
source("src/lib/mape.R")
source("src/adaboostR2.R")
source("src/trAdaboostR2.R")
source("src/gradualTSRegression.R")

# Read ratings
ratings <- read.csv("data/Chinese_Drama_Ratings_AnotherFormat.csv",
                    fileEncoding="utf-8")
# Final output (ratings & features)
data <- ratings
# Read features and combine with ratings
source("src/getFeature.R")
featureFiles <- c("data/Chinese_Drama_Opinion.csv",
                  "data/Chinese_Drama_GoogleTrend.csv",
                  "data/Chinese_Drama_FB.csv")
for (featureFile in featureFiles) {
  feature <- read.csv(featureFile, fileEncoding="utf-8")
  # left join automatically by common variables
  data <- merge(data, feature, sort=F, all.x=TRUE)
}

# sort (for easy view)
attach(data)
data <- data[order(Drama, Episode),]
detach(data)

dramas <- split(data, factor(data[, "Drama"]))

# Handle missing values
dramas_tmp <- list() # used to keep dramas that have more than one case
for (idx in 1:length(dramas)) {
  # Sort by episode and replace missing values of ratings by interpolation
  attach(dramas[[idx]])
  dramas[[idx]] <- dramas[[idx]][order(Episode),]
  detach(dramas[[idx]])
  dramas[[idx]][3] <- na.approx(dramas[[idx]][3])

  # Only keep complete cases (without any missing value)
  dramas[[idx]] <- dramas[[idx]][complete.cases(dramas[[idx]]),]

  # Keep dramas that have more than one case
  if (nrow(dramas[[idx]]) > 0) {
    new_idx <- length(dramas_tmp) + 1
    dramas_tmp[[new_idx]] <- dramas[[idx]]
    names(dramas_tmp)[new_idx] <- names(dramas)[idx]
  }
}
dramas <- dramas_tmp

results <- list()
for (idx in 1:length(dramas)) {
  dramaName <- names(dramas)[idx]
  colnames(dramas[[idx]])[3] <- dramaName

  # Skip drama whose data is not enough (e.g., "Second Life")
  # If it is not skipped, gradualTSRegression() will fail.
  if (nrow(dramas[[idx]][dramaName]) < 6) {
    next
  }

  target_feature <- dramas[[idx]][, -c(1, 2, 3)]

  # Model: nnet
  result <- gradualTSRegression(dramas[[idx]][dramaName], target_feature,
                                predictor=nnet, size=3, linout=T, trace=F,
                                rang=0.1, decay=1e-1, maxit=100)
  # Model: nnet + adaboostR2
  result2 <- gradualTSRegression(dramas[[idx]][dramaName], target_feature,
                                 predictor=adaboostR2, base_predictor=nnet,
                                 size=3, linout=T, trace=F,
                                 rang=0.1, decay=1e-1, maxit=100)

  # Combine multiple sources into one data set:
  #   - Apply windowing transformation to each drama
  #   - Bind data.
  window_len <- 4
  src_indices <- 1:length(dramas)
  src_indices <- src_indices[-idx]
  src_data <- c()  # An empty data frame?
  for (src_idx in src_indices) {
    # Form windowing data
    src_drama_name <- names(dramas)[src_idx]
    colnames(dramas[[src_idx]])[3] <- src_drama_name
    src_drama <- dramas[[src_idx]][src_drama_name]
    w_data <- windowing(src_drama, window_len)

    # Add time period as a feature into windowing data
    num_cases <- nrow(w_data)
    time_periods <- seq(window_len, num_cases + window_len - 1)
    w_data <- cbind(time_periods, w_data)

    # Add other features into windowing data
    features <- tail(dramas[[src_idx]][, -c(1, 2, 3)], num_cases)
    w_data <- cbind(features, w_data)

    # Bind windowing data
    src_data <- rbind(w_data, src_data)
  }
  src_data <- data.frame(src_data)

  # Model: nnet + trAdaBoostR2
  result3 <- gradualTSRegression(dramas[[idx]][dramaName], target_feature,
                                 source_data=src_data,
                                 predictor=trAdaboostR2,
                                 num_predictors=50,
                                 verbose=F,
                                 base_predictor=nnet,
                                 size=3, linout=T, trace=F,
                                 rang=0.1, decay=1e-1, maxit=100)

  results[[idx]] <- result3

  # Plot result
  plot(ts(result["TestError"]), main=dramaName, xlab="Episode", ylab="MAPE", col="red")
  lines(ts(result["TrainError"]), col="darkred")
  lines(ts(result2["TestError"]), col="blue")
  lines(ts(result2["TrainError"]), col="darkblue")
  lines(ts(result3["TestError"]), col="green")
  lines(ts(result3["TrainError"]), col="darkgreen")
  result_mape <- mape(result["Prediction"], result[dramaName])
  result2_mape <- mape(result2["Prediction"], result[dramaName])
  result3_mape <- mape(result3["Prediction"], result[dramaName])
  result_mape_display <- sprintf("nnet: %.3f", result_mape)
  result2_mape_display <- sprintf("nnet+adaboostR2: %.3f", result2_mape)
  result3_mape_display <- sprintf("nnet+trAdaboostR2: %.3f", result3_mape)
  plot_legend <- c(result_mape_display,
                   result2_mape_display,
                   result3_mape_display,
                   "red: nnet",
                   "blue: nnet+adaboostR2",
                   "green: nnet+trAdaboostR2",
                   "dark: train error")
  legend("topleft", legend=plot_legend, cex=0.7)
}