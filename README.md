# PCIbex Lexical Decision Priming Experiment

## Overview

This project contains a web-based psycholinguistic experiment implemented using the PCIbex framework (PennController for Ibex). The experiment is a Lexical Decision Task (LDT) designed to investigate masked priming effects as a demonstration for FYS. Participants see a sequence of stimuli (forward mask, prime, backward mask, target) and must decide as quickly and accurately as possible whether the final target string is a real English word or a non-word. The prime word is either related or unrelated to the target word.

The experiment logic is defined in JavaScript using PennController, stimuli are loaded from a CSV file, and data analysis is performed using R within a Quarto document.

## Features

*   **Experiment Framework:** Built with PCIbex and PennController.
*   **Task:** Masked Lexical Decision Task (LDT) with priming.
*   **Stimuli:** Primes and targets loaded from `chunk_includes/ldt_stimuli.csv`.
*   **Procedure:** Includes forward masking, brief prime presentation, backward masking, and target presentation until response.
*   **Reproducible Environment:** Uses Nix flakes (`flake.nix`) and direnv (`.envrc`) to manage dependencies and ensure a consistent development environment for analysis.
*   **Data Analysis:** Includes an R script (`analysis/exp_results.qmd`) using the Tidyverse, `lme4`, and Quarto for analyzing and reporting results.
*   **Custom Components:** Likely utilizes custom JavaScript controllers (from `js_includes/`) and CSS (from `css_includes/`) for specific presentation or interaction needs (though these files are not currently active in the chat).


