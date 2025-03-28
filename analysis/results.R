#!/usr/bin/env Rscript
# analysis/results.R

# Description: A script to analyze PCIbex Farm results data.
# This script reads in the results file, cleans and tidies the data,
# calculates reaction times (RT) and accuracy, analyzes priming effects,
# and visualizes the results.
# Usage: Rscript analysis/results.R

# --- 1. Load Libraries ---
# Use pacman to load/install packages
library(tidyverse)
library(janitor)
library(here)

# --- 2. Define read.pcibex Function ---
# User-defined function to read in PCIbex Farm results files
# (Copied from _docs/analysis-with-R.md)
read.pcibex <- function(filepath, auto.colnames=TRUE, fun.col=function(col,cols){cols[cols==col]<-paste(col,"Ibex",sep=".");return(cols)}) {
  n.cols <- max(count.fields(filepath,sep=",",quote=NULL),na.rm=TRUE)
  if (auto.colnames){
    cols <- c()
    con <- file(filepath, "r")
    while ( TRUE ) {
      line <- readLines(con, n = 1, warn=FALSE)
      if ( length(line) == 0) {
        break
      }
      # Adjusted regex to handle potential variations in comment format
      m <- regmatches(line,regexec("^# (\\d+)\\. (.+)\\.?$",line))[[1]]
      if (length(m) == 3) {
        index <- as.numeric(m[2])
        value <- m[3]
        if (is.function(fun.col)){
          cols <- fun.col(value,cols)
        }
        # Ensure the cols vector is long enough
        if (index > length(cols)) {
            cols[(length(cols)+1):index] <- NA
        }
        cols[index] <- value
        # Simple break condition: stop if we have enough columns based on data
        # or if we hit a specific high number (e.g., 25) just in case.
        # A more robust method might be needed for highly variable files.
        if (!is.na(cols[n.cols]) || index > 25) {
             # Check if the last expected column is filled
             if (index == n.cols) break
             # Fallback: if we read a column index matching n.cols, assume header is done
        }
      }
    }
    close(con)
    # Remove potential NA placeholders if parsing didn't fill all indices contiguously
    cols <- cols[!is.na(cols)]
    # Ensure we have exactly n.cols names, padding if necessary
    if (length(cols) < n.cols) {
        cols <- c(cols, paste0("V", (length(cols)+1):n.cols))
    } else if (length(cols) > n.cols) {
        cols <- cols[1:n.cols]
    }
    # Use fill=TRUE to handle rows with fewer columns than the max
    return(read.csv(filepath, comment.char="#", header=FALSE, col.names=cols, fill=TRUE))
  } else{
    return(read.csv(filepath, comment.char="#", header=FALSE, col.names=seq(1:n.cols), fill=TRUE))
  }
}


# --- 3. Load and Clean Data ---
# Define the path to the results file relative to the script location
# Assumes the script is in 'analysis/' and data in '_docs/' at the same level
# Use here::here() for more robust path handling if preferred
# results_file <- here::here("..", "_docs", "results_dev.csv")
results_file <- "_docs/results_dev.csv"

# Check if file exists
if (!file.exists(results_file)) {
  stop("Results file not found at: ", results_file)
}

raw_results <- read.pcibex(results_file)

# Clean column names (convert to snake_case)
results_clean <- raw_results %>%
  janitor::clean_names()

# --- 4. Tidy Data ---
# Reshape data to have one row per trial with relevant columns
# This involves identifying key events (target onset, response) and conditions
processed_data <- results_clean %>%
  # Ensure relevant columns are treated as characters initially to avoid factor issues
  mutate(across(c(penn_element_type, penn_element_name, parameter, value, label), as.character)) %>%
  # Group by participant and trial number
  group_by(id, order_number_of_item) %>%
  # Fill down trial-level information (conditions, labels, etc.)
  # Use .direction = "downup" to fill both down and up within a group
  fill(label, latin_square_group, condition, expected, prime_type,
       # Add any other columns logged per trial (like prime_word, target_word if they exist)
       any_of(c("prime_word", "target_word")),
       .direction = "downup") %>%
  # Identify key events
  mutate(
    event_type = case_when(
      # Target onset (using Text element named 'target')
      penn_element_type == "Text" & penn_element_name == "target" & parameter == "Print" ~ "target_onset",
      # Response (using Key element named 'answerTarget')
      penn_element_type == "Key" & penn_element_name == "answer_target" & parameter == "PressedKey" ~ "response",
      # Add other events if needed (e.g., prime onset)
      # penn_element_type == "Text" & penn_element_name == "prime" & parameter == "Print" ~ "prime_onset",
      TRUE ~ NA_character_ # Ignore other rows for pivoting time/value
    )
  )  %>%
  # Keep only rows with key events
  filter(!is.na(event_type)) %>%
  # Select relevant columns for pivoting
  select(id, order_number_of_item, label, latin_square_group, condition,
         expected, prime_type, any_of(c("prime_word", "target_word")), # Keep condition cols
         event_type, event_time, value) %>% # Keep event time and response value
  # Pivot wider to get target_onset_time, response_time, and response_key in columns
  # Note: 'value' column contains the pressed key for 'response' events
  pivot_wider(
    names_from = event_type,
    values_from = c(event_time, value),
    # If multiple events of same type (shouldn't happen here), use list
    # values_fn = list(event_time = list, value = list)
  ) %>%
  # Rename columns for clarity
  rename(
    target_onset_time = event_time_target_onset,
    response_time = event_time_response,
    response_key = value_response # The key pressed
  ) %>%
  # Remove the value column associated with target onset (likely NA)
  select(-any_of(c("value_target_onset"))) %>%
  ungroup()

# --- 5. Calculate RT and Accuracy ---
# Convert time columns to numeric, calculate RT, determine accuracy
# Assumption: 'f' key for 'word' condition, 'j' key for 'nonword' condition
# Adjust this mapping based on your experiment's instructions (e.g., F/J keys)
final_data <- processed_data %>%
  # Ensure time columns are numeric (handle potential "Never" or non-numeric values)
  mutate(across(ends_with("_time"), ~suppressWarnings(as.numeric(as.character(.))))) %>%
  # Calculate Reaction Time (RT) in milliseconds
  mutate(rt = response_time - target_onset_time) %>%
  # Determine the correct key press based on the 'condition' column
  mutate(
    # Convert response key to uppercase for consistent comparison
    response_key = toupper(response_key),
    # Define correct response based on condition (Word/Nonword)
    correct_response = case_when(
      condition == "word" ~ "F", # Assuming F key for word
      condition == "nonword" ~ "J", # Assuming J key for nonword
      TRUE ~ NA_character_
    ),
    # Calculate accuracy (1 for correct, 0 for incorrect)
    accuracy = if_else(response_key == correct_response, 1, 0)
  ) %>%
  # Select and arrange final columns
  select(
    id, trial = order_number_of_item, label, group = latin_square_group,
    condition, expected_key = expected, prime_type,
    any_of(c("prime_word", "target_word")), # Keep if they exist
    rt, response_key, correct_response, accuracy
  )

# --- 6. Filter Data for Analysis ---
# Remove practice trials, NAs, incorrect trials (for RT), and outliers

# View potential issues before filtering
summary(final_data)
# How many trials per participant/condition?
# final_data %>% count(id, prime_type, condition)

# Filter steps:
analysis_data_rt <- final_data %>%
  # 1. Keep only 'test' trials
  filter(label == "test") %>%
  # 2. Remove trials with NA reaction times or NA accuracy
  filter(!is.na(rt) & !is.na(accuracy)) %>%
  # 3. Keep only correct trials for RT analysis
  filter(accuracy == 1) %>%
  # 4. Remove RT outliers (e.g., < 200ms or > 2000ms) - adjust as needed
  filter(rt > 200 & rt < 2000) %>%
  # 5. Keep only relevant conditions if necessary (e.g., exclude fillers if any)
  # filter(condition %in% c("word", "nonword")) # Already implicitly done by accuracy calc
  # 6. Keep only relevant prime types for priming analysis
  filter(prime_type %in% c("related", "unrelated"))

# Check remaining data
print(paste("Number of trials remaining for RT analysis:", nrow(analysis_data_rt)))
analysis_data_rt %>% count(prime_type)

# For accuracy analysis, use data before filtering for correct trials & RT outliers
analysis_data_acc <- final_data %>%
  filter(label == "test") %>%
  filter(!is.na(rt) & !is.na(accuracy)) %>%
  filter(prime_type %in% c("related", "unrelated"))

# --- 7. Analyze Priming Effect ---

# Calculate summary statistics for RT
rt_summary <- analysis_data_rt %>%
  group_by(prime_type) %>%
  summarise(
    mean_rt = mean(rt, na.rm = TRUE),
    sd_rt = sd(rt, na.rm = TRUE),
    n = n()
  ) %>%
  ungroup()

print("Reaction Time Summary (Correct Trials):")
print(rt_summary)

# Calculate priming effect size (Unrelated RT - Related RT)
priming_effect_rt <- rt_summary %>%
  pivot_wider(names_from = prime_type, values_from = c(mean_rt, sd_rt, n)) %>%
  mutate(priming_effect_ms = mean_rt_unrelated - mean_rt_related)

print("Priming Effect (RT):")
print(priming_effect_rt$priming_effect_ms)

# Perform a t-test (assuming normality and equal variance - check assumptions for formal analysis)
# Note: A linear mixed-effects model (lmer) would be more appropriate to account
# for participant and item variability in a real analysis.
if (nrow(analysis_data_rt) > 5 && length(unique(analysis_data_rt$prime_type)) == 2) {
  rt_ttest <- t.test(rt ~ prime_type, data = analysis_data_rt)
  print("T-test Results (RT):")
  print(rt_ttest)
} else {
  print("Not enough data or conditions for t-test.")
}


# Calculate summary statistics for Accuracy
acc_summary <- analysis_data_acc %>%
  group_by(prime_type) %>%
  summarise(
    mean_accuracy = mean(accuracy, na.rm = TRUE),
    n = n()
  ) %>%
  ungroup()

print("Accuracy Summary:")
print(acc_summary)

# --- 8. Visualize Results ---

# Plot RTs by Prime Type (Box Plot)
plot_rt_box <- ggplot(analysis_data_rt, aes(x = prime_type, y = rt, fill = prime_type)) +
  geom_boxplot(alpha = 0.7) +
  labs(
    title = "Reaction Time by Prime Type (Correct Trials)",
    x = "Prime Type",
    y = "Reaction Time (ms)"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

print(plot_rt_box)
# ggsave("analysis/rt_boxplot.png", plot_rt_box, width = 6, height = 4)


# Plot Mean RTs by Prime Type (Bar Plot with Error Bars)
plot_rt_bar <- rt_summary %>%
  ggplot(aes(x = prime_type, y = mean_rt, fill = prime_type)) +
  geom_bar(stat = "identity", alpha = 0.8, width = 0.7) +
  geom_errorbar(
    aes(ymin = mean_rt - sd_rt / sqrt(n), ymax = mean_rt + sd_rt / sqrt(n)),
    width = 0.2
  ) +
  labs(
    title = "Mean Reaction Time by Prime Type (Correct Trials)",
    subtitle = paste("Priming Effect:", round(priming_effect_rt$priming_effect_ms, 1), "ms"),
    x = "Prime Type",
    y = "Mean Reaction Time (ms)"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

print(plot_rt_bar)
# ggsave("analysis/rt_barplot.png", plot_rt_bar, width = 6, height = 4)


# Plot Mean Accuracy by Prime Type (Bar Plot)
plot_acc_bar <- acc_summary %>%
  ggplot(aes(x = prime_type, y = mean_accuracy, fill = prime_type)) +
  geom_bar(stat = "identity", alpha = 0.8, width = 0.7) +
  scale_y_continuous(limits = c(0, 1), labels = scales::percent) +
  labs(
    title = "Mean Accuracy by Prime Type",
    x = "Prime Type",
    y = "Mean Accuracy"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

print(plot_acc_bar)
# ggsave("analysis/accuracy_barplot.png", plot_acc_bar, width = 6, height = 4)

# --- End of Script ---
