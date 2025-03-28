#!/usr/bin/env Rscript
# analysis/results.R

# Description: A script to analyze PCIbex Farm results data.
# This script reads in the results file, cleans and tidies the data,
# calculates reaction times (RT) and accuracy, analyzes priming effects,
# and visualizes the results.
# Usage: Rscript analysis/results.R

# --- 1. Load Libraries ---
# Environment controlled by flake.nix
library(tidyverse)
library(janitor)
library(here)
library(lme4) # for mixed effects models
library(lmerTest) # for p-values in mixed models
library(emmeans) # for estimated marginal means

# --- 2. Define read.pcibex Function ---
# User-defined function to read in PCIbex Farm results files
read.pcibex <- function(filepath, auto.colnames = TRUE, fun.col = function(col, cols) {
                          cols[cols == col] <- paste(col, "Ibex", sep = ".")
                          return(cols)
                        }) {
  n.cols <- max(count.fields(filepath, sep = ",", quote = NULL), na.rm = TRUE)
  if (auto.colnames) {
    cols <- c()
    con <- file(filepath, "r")
    while (TRUE) {
      line <- readLines(con, n = 1, warn = FALSE)
      if (length(line) == 0) {
        break
      }
      # Adjusted regex to handle potential variations in comment format
      m <- regmatches(line, regexec("^# (\\d+)\\. (.+)\\.?$", line))[[1]]
      if (length(m) == 3) {
        index <- as.numeric(m[2])
        value <- m[3]
        if (is.function(fun.col)) {
          cols <- fun.col(value, cols)
        }
        # Ensure the cols vector is long enough
        if (index > length(cols)) {
          cols[(length(cols) + 1):index] <- NA
        }
        cols[index] <- value
        if (!is.na(cols[n.cols]) || index > 25) {
          if (index == n.cols) break
        }
      }
    }
    close(con)
    cols <- cols[!is.na(cols)]
    if (length(cols) < n.cols) {
      cols <- c(cols, paste0("V", (length(cols) + 1):n.cols))
    } else if (length(cols) > n.cols) {
      cols <- cols[1:n.cols]
    }
    return(read.csv(filepath, comment.char = "#", header = FALSE, col.names = cols, fill = TRUE))
  } else {
    return(read.csv(filepath, comment.char = "#", header = FALSE, col.names = seq(1:n.cols), fill = TRUE))
  }
}

# --- 3. Load and Clean Data ---
results_file <- "_docs/results_prod.csv"

# Check if file exists
if (!file.exists(results_file)) {
  stop("Results file not found at: ", results_file)
}

raw_results <- read.pcibex(results_file)

# Clean column names (convert to snake_case)
results_clean <- raw_results %>%
  janitor::clean_names()

# --- 4. Tidy Data ---
processed_data <- results_clean %>%
  mutate(across(c(penn_element_type, penn_element_name, parameter, value, label), as.character)) %>%
  group_by(id, order_number_of_item) %>%
  fill(label, latin_square_group, condition, expected, prime_type,
    any_of(c("prime_word", "target_word")),
    .direction = "downup"
  ) %>%
  {
    print("Key press events found:")
    key_events <- filter(., penn_element_type == "Key") %>%
      select(penn_element_name, parameter, value) %>%
      distinct()
    print(key_events)
    .
  } %>%
  mutate(
    event_type = case_when(
      penn_element_type == "Text" & penn_element_name == "target" & parameter == "Print" ~ "target_onset",
      penn_element_type == "Key" & !is.na(value) ~ "response",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(event_type)) %>%
  {
    print("Event types identified after initial filter:")
    print(count(., event_type))
    .
  } %>%
  group_by(id, order_number_of_item, event_type) %>%
  arrange(event_time) %>%
  slice(1) %>%
  ungroup() %>%
  select(
    id, order_number_of_item, label, latin_square_group, condition,
    expected, prime_type, any_of(c("prime_word", "target_word")),
    event_type, event_time, value
  ) %>%
  pivot_wider(
    names_from = event_type,
    values_from = c(event_time, value)
  ) %>%
  {
    print("Column names after pivot_wider:")
    print(colnames(.))
    .
  } %>%
  rename(
    target_onset_time = event_time_target_onset,
    response_time = event_time_response,
    response_key = value_response
  ) %>%
  select(-any_of(c("value_target_onset"))) %>%
  ungroup()

# --- 5. Calculate RT and Accuracy ---
final_data <- processed_data %>%
  mutate(across(ends_with("_time"), ~ suppressWarnings(as.numeric(as.character(.))))) %>%
  mutate(rt = response_time - target_onset_time) %>%
  mutate(
    response_key = toupper(response_key),
    correct_response = case_when(
      condition == "word" ~ "F",
      condition == "nonword" ~ "J",
      TRUE ~ NA_character_
    ),
    accuracy = if_else(response_key == correct_response, 1, 0)
  ) %>%
  select(
    id,
    trial = order_number_of_item, label, group = latin_square_group,
    condition, expected_key = expected, prime_type,
    any_of(c("prime_word", "target_word")),
    rt, response_key, correct_response, accuracy
  )

# --- 6. Filter Data for Analysis ---
summary(final_data)

analysis_data_rt <- final_data %>%
  filter(label == "test") %>%
  filter(!is.na(rt) & !is.na(accuracy)) %>%
  filter(accuracy == 1) %>%
  filter(rt > 200 & rt < 2000) %>%
  filter(prime_type %in% c("related", "unrelated"))

print(paste("Number of trials remaining for RT analysis:", nrow(analysis_data_rt)))
analysis_data_rt %>% count(prime_type)

analysis_data_acc <- final_data %>%
  filter(label == "test") %>%
  filter(!is.na(rt) & !is.na(accuracy)) %>%
  filter(prime_type %in% c("related", "unrelated"))

# --- 7. Analyze Priming Effect ---
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

priming_effect_rt <- rt_summary %>%
  pivot_wider(names_from = prime_type, values_from = c(mean_rt, sd_rt, n)) %>%
  mutate(priming_effect_ms = mean_rt_unrelated - mean_rt_related)

print("Priming Effect (RT):")
print(paste("Raw mean difference:", round(priming_effect_rt$priming_effect_ms, 1), "ms"))

if (nrow(analysis_data_rt) > 5 && length(unique(analysis_data_rt$prime_type)) == 2) {
  rt_model <- lmer(
    rt ~ prime_type +
      (1 | id) +
      (1 | target_word),
    data = analysis_data_rt
  )
  print("Linear mixed effects model results:")
  print(summary(rt_model))
  emm <- emmeans(rt_model, ~prime_type)
  print("Estimated marginal means:")
  print(emm)
  pairs <- pairs(emm)
  print("Pairwise comparisons:")
  print(pairs)
  contrasts <- contrast(emm, "pairwise")
  effect_size <- summary(contrasts)$estimate / sqrt(VarCorr(rt_model)$id[1] + VarCorr(rt_model)$target_word[1])
  print(paste("Cohen's d effect size:", round(effect_size, 3)))
} else {
  print("Not enough data or conditions for mixed effects analysis.")
}

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
if (nrow(analysis_data_rt) > 0) {
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
} else {
  print("No data available for RT box plot.")
}

if (nrow(rt_summary) > 0 && "mean_rt_unrelated" %in% names(priming_effect_rt)) {
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
} else {
  print("No data available or priming effect could not be calculated for RT bar plot.")
}

if (nrow(acc_summary) > 0) {
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
} else {
  print("No data available for Accuracy bar plot.")
}
