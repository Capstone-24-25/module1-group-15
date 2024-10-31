# Load necessary libraries
library(dplyr)
library(ggplot2)

# Load the raw data
biomarker_data <- read.csv("/mnt/data/biomarker-raw.csv")

# Step 1: Identify outliers without trimming
# Using a common method like 1.5 * IQR for identifying outliers per protein
identify_outliers <- function(x) {
  q1 <- quantile(x, 0.25, na.rm = TRUE)
  q3 <- quantile(x, 0.75, na.rm = TRUE)
  iqr <- q3 - q1
  lower_bound <- q1 - 1.5 * iqr
  upper_bound <- q3 + 1.5 * iqr
  return(x < lower_bound | x > upper_bound)
}

# Apply the function to each protein column to flag outliers
outliers <- biomarker_data %>%
  select(-subject_id, -group) %>%  # Exclude non-protein columns
  mutate_all(identify_outliers)

# Step 2: Summarize outliers by subject
# Create a summary table to count the number of outliers per subject
outliers_summary <- biomarker_data %>%
  select(subject_id, group) %>%  # Keep only subject and group information
  bind_cols(outliers) %>%
  rowwise() %>%
  mutate(outlier_count = sum(c_across(-subject_id, -group), na.rm = TRUE)) %>%
  ungroup()

# Step 3: Analyze outlier counts
# Count the number of outlying values per subject and examine frequency by group
outliers_by_subject <- outliers_summary %>%
  group_by(subject_id, group) %>%
  summarize(total_outliers = sum(outlier_count), .groups = 'drop')

# Step 4: Visualize the results
# Plot the number of outliers per subject, grouped by group (if applicable)
ggplot(outliers_by_subject, aes(x = subject_id, y = total_outliers, fill = group)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Number of Outlying Values per Subject",
       x = "Subject ID", y = "Total Outliers") +
  theme_minimal()

# Step 5: Summary table of outliers by group
outliers_by_group <- outliers_by_subject %>%
  group_by(group) %>%
  summarize(mean_outliers = mean(total_outliers, na.rm = TRUE),
            median_outliers = median(total_outliers, na.rm = TRUE),
            max_outliers = max(total_outliers, na.rm = TRUE))

# Display results
print("Outlier counts by subject:")
print(outliers_by_subject)
print("Summary of outliers by group:")
print(outliers_by_group)
