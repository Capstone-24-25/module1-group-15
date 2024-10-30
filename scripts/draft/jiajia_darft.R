library(ggplot2)

# 1. 
#What do you imagine is the reason for log-transforming the protein levels in `biomarker-raw.csv`? (Hint: look at the distribution of raw values for a sample of proteins.)
# Since `biomarker-raw.csv` contains protein concentration levels across various samples, let's examine the distribution of a sample of these protein values.
raw_data <- read.csv('data/biomarker-raw.csv')
colnames(raw_data)
sample_column <- c("E3 ubiquitin-protein ligase CHIP", "CCAAT.enhancer.binding.protein.beta", "Gamma.enolase", "E3.SUMO.protein.ligase.PIAS4", "Interleukin.10.receptor.subunit.alpha" )








# 2.
# Temporarily remove the outlier trimming from preprocessing and do some exploratory analysis of outlying values. Are there specific *subjects* (not values) that seem to be outliers? If so, are outliers more frequent in one group or the other? (Hint: consider tabluating the number of outlying values per subject.)
