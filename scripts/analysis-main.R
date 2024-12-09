1.
library(ggplot2)
library(reshape2)

data <- read.csv("data2/biomarker-raw.csv")

# Convert the selected protein columns to numeric (skip non-numeric values)
proteins <- data[, 3:7]  # Select a sample of 5 protein columns
proteins <- data.frame(lapply(proteins, function(x) as.numeric(as.character(x))))

# Melt the data for ggplot

proteins_long <- melt(proteins, variable.name = "Protein", value.name = "Level")

# Plot histograms for each selected protein
ggplot(proteins_long, aes(x = Level)) +
  geom_histogram(bins = 30, color = "black", fill = "skyblue") +
  facet_wrap(~Protein, scales = "free") +
  labs(title = "Distribution of Raw Protein Levels (Sample Proteins)",
       x = "Protein Level", y = "Frequency") +
  theme_minimal()

The histograms reveal that the distributions of raw protein levels are skewed right, with some values extending to higher ranges. 
This skewness is a common reason to apply a log transformation, which can help normalize these distributions.


2.


library(dplyr)
library(tidyr)

# Load the data (assuming it's processed after removing outlier trimming)
data <- read.csv("data2/biomarker-raw.csv")

# Convert relevant columns to numeric, skipping metadata columns
protein_data <- data[, -c(1,2)]  # Adjust index based on the actual data structure

# Define a function to identify outliers based on ±3 standard deviations
identify_outliers <- function(x) {
  upper_limit <- mean(x, na.rm = TRUE) + 3 * sd(x, na.rm = TRUE)
  lower_limit <- mean(x, na.rm = TRUE) - 3 * sd(x, na.rm = TRUE)
  return(x < lower_limit | x > upper_limit)
}

# Apply the outlier function across all protein columns
outliers <- protein_data %>%
  mutate(across(everything(), identify_outliers)) %>%
  rowwise() %>%
  mutate(outlier_count = sum(c_across(everything()), na.rm = TRUE)) %>%
  ungroup()

# Merge with subject ID and group columns
outlier_summary <- data %>%
  select(Group) %>%
  bind_cols(outliers["outlier_count"])

# Summarize the number of outlying values per subject and by group
outlier_by_group <- outlier_summary %>%
  group_by(Group) %>%
  summarise(avg_outliers = mean(outlier_count, na.rm = TRUE),
            total_outliers = sum(outlier_count, na.rm = TRUE),
            subjects_with_outliers = sum(outlier_count > 0))

# View results
print(outlier_by_group)

#Yes, there are specific subjects with outliers. According to the table of nsummary, there are 2 subjects with outlying values in the ASD group.
#Are outliers more frequent in one group or the other?
#Outliers are more frequent in the ASD group.
#ASD group with a total of 2 outliers, while the TD group has none.

3.
library(dplyr)
library(caret)  #data partition
library(dplyr)  #ttest
library(purrr)  #ttest
library(broom)  #ttest
library(tidyverse) #ttest
library(rstatix)
library(randomForest) #Random Forest
library(MASS)   #Logistic Regression

set.seed(123)

# Split training (80%) and testing (20%) sets
trainIndex <- createDataPartition(biomarker_clean$group, p = 0.8, list = FALSE)
training_data <- biomarker_clean[trainIndex, ]
testing_data <- biomarker_clean[-trainIndex, ]
head(training_data)
head(testing_data)

#### Apply T-test, Random Forest, and Logistic Regression  (Using Top 20 Features)


##### T-test Selection
library(dplyr)

# Ensure correct names and explicit call to dplyr::select
group_column <- training_data$group  # Confirm column name is correct
protein_columns <- dplyr::select(training_data, -group, -ados)  # Explicitly use dplyr



#T test for all protein
t_test_results <- sapply(protein_columns, function(protein) {
  t.test(protein ~ group_column)$p.value
})

# Convert result into frame
t_test_df <- data.frame(
  protein = names(t_test_results),
  p_value = t_test_results
)

# Extract top 20 proteins
top_proteins_ttest <- t_test_df %>%
  arrange(p_value) %>%
  slice(1:20) %>%
  pull(protein)


print(top_proteins_ttest)

##### Random Forest

library(randomForest)
library(dplyr)


# Alternative approach if select() conflicts remain
predictors <- training_data[, !names(training_data) %in% c("group", "ados")]
response <- factor(training_data$group)



set.seed(101422)


rf_model <- randomForest(x = predictors, 
                         y = response, 
                         ntree = 1000, 
                         importance = TRUE)


print(rf_model$confusion)


important_proteins_rf <- rf_model$importance %>%
  as_tibble() %>%
  mutate(protein = rownames(rf_model$importance)) %>%
  slice_max(MeanDecreaseGini, n = 20) %>%  # top 20
  pull(protein)


print(important_proteins_rf)

##### Logistic Regression

library(caret)
library(dplyr)



train_data_for_model <- training_data %>%
  dplyr::select(-ados) %>%
  dplyr::mutate(group = as.factor(group))



train_control <- trainControl(method = "none")


logistic_model <- train(group ~ ., 
                        data = train_data_for_model,
                        method = "glm",
                        family = "binomial",
                        trControl = train_control)


logistic_coefficients <- coef(logistic_model$finalModel)


coeff_df <- as.data.frame(logistic_coefficients) %>%
  rownames_to_column(var = "protein") %>%
  filter(protein != "(Intercept)") %>%
  rename(coefficient = logistic_coefficients) %>%
  mutate(abs_coefficient = abs(coefficient))


top_20_proteins <- coeff_df %>%
  arrange(desc(abs_coefficient)) %>%
  slice(1:20) %>%
  pull(protein)


print(top_20_proteins)

##### Fuzzy Interaction

all_top_proteins <- list(
  ttest = top_proteins_ttest,
  rf = important_proteins_rf,
  logreg = top_20_proteins
)


fuzzy_intersection_proteins <- all_top_proteins %>%
  unlist() %>%       
  table() %>% 
  .[. >= 2] %>%    
  names()            

print(fuzzy_intersection_proteins)

# Evaluate each set of selected proteins on testing data
evaluate_model_accuracy <- function(selected_proteins, model_name) {
  # Explicitly use dplyr::select() and tidyselect::all_of()
  predictors <- dplyr::select(testing_data, tidyselect::all_of(selected_proteins))
  response <- factor(testing_data$group)
  
  rf_test <- randomForest(x = predictors, y = response, ntree = 100)
  accuracy <- sum(diag(rf_test$confusion)) / sum(rf_test$confusion)
  
  cat("Accuracy of", model_name, "model on testing data:", accuracy, "\n")
}

# Evaluate individual methods
evaluate_model_accuracy(top_proteins_ttest, "T-test")
evaluate_model_accuracy(important_proteins_rf, "Random Forest")
#evaluate_model_accuracy(top_20_proteins, "Logistic Regression")

# Evaluate fuzzy intersection
evaluate_model_accuracy(fuzzy_intersection_proteins, "Fuzzy Intersection")

#Each method yields different predictive performance, with Random Forest and the Fuzzy Intersection performing similarly well.
#The fuzzy intersection can be a useful compromise when seeking a balance between different selection criteria, but in this case, it does not significantly outperform Random Forest alone.
