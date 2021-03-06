# Test AdaBoost.R2 with 1D sinusoidal dataset with Gaussian noise.
# Ref: http://scikit-learn.org/stable/auto_examples/ensemble/plot_adaboost_regression.html

library(rpart)
library(hydroGOF)
library(lattice)
# Please manually set working dir to project root first
source("src/adaboostR2.R")

set.seed(1)

start_time <- proc.time()

# create the data set
num_cases <- 100
x <- seq(from=0, to=6, length.out=num_cases)
y <- sin(x) + sin(6 * x) + rnorm(num_cases, mean=0, sd=0.1)
data <- data.frame(x, y)

# split data set into training (subtrain + validation) and testing
# subtrain and validation data is for parameter tuning
test_ratio <- 0.2
test_num_cases <- floor(test_ratio * num_cases)

val_ratio <- 0.2
val_num_cases <- floor(val_ratio * num_cases)

test_val_idx <- sample(num_cases, test_num_cases + val_num_cases)
test_idx <- head(test_val_idx, test_num_cases)
val_idx <- tail(test_val_idx, val_num_cases)

test_data <- data[test_idx, ]
train_data <- data[-test_idx, ]
subtrain_data <- data[-test_val_idx, ]
val_data <- data[val_idx, ]

# Note: The key to get good performance here is to set minsplit small enough!!
# train regression tree
r_control <- rpart.control(minsplit=2, maxdepth=4)
rp <- rpart(y~., train_data, control=r_control)
# predict on validation
prediction_rp <- predict(rp, test_data['x'])

# train AdaBoost.R2 with regression tree
ada_rp <- adaboostR2(y~., subtrain_data, val_data,
                     num_predictors=60, verbose=TRUE,
                     base_predictor=rpart,
                     control=r_control)
# predict on test
prediction_ada_rp <- predict(ada_rp, test_data['x'])

# plot errors over iterations (TOFIX: blank image)
# TOFIX: blank image when sourcing script, have to type print(p) in console
# dev.off()  # http://stackoverflow.com/a/20627536
# p <- xyplot(ts(ada_rp$errors), superpose=T, type='o', lwd=2,
#             main='Errors over iterations', xlab='Iteration', ylab='Error')
# print(p)

# evaluate goodness of fit on validation
performance <- data.frame(gof(prediction_rp, test_data[, 'y']),
                          gof(prediction_ada_rp, test_data[, 'y']))
colnames(performance) <- c('rpart', 'AdaBoost.R2(rpart)')
print(performance)

# plot dataset
colors <- c('black', rainbow(2))
plot(x, y, main='AdaBoost.R2 with 1D sinusoidal dataset with Gaussian noise',
     xlab='data - x', ylab='y and y_prediction', type='o', col=colors[1])

# plot prediction of testing
prediction_rp <- data.frame(x=test_data[, 'x'], y=prediction_rp)
prediction_rp <- prediction_rp[order(prediction_rp$x), ]
points(prediction_rp$x, prediction_rp$y, type='o', col=colors[2])

prediction_ada_rp <- data.frame(x=test_data[, 'x'], y=prediction_ada_rp)
prediction_ada_rp <- prediction_ada_rp[order(prediction_ada_rp$x), ]
points(prediction_ada_rp$x, prediction_ada_rp$y, type='o', col=colors[3])
legends <- c('training data', 'rpart', 'AdaBoost.R2(rpart)')
legend('topright', legend=legends, col=colors, cex=0.7, pch=21, lty=1)

# Print total time spent
end_time <- proc.time()
time_spent <- end_time - start_time
cat(sprintf("Done! Time spent: %.2f (s)", time_spent["elapsed"]), '\n')