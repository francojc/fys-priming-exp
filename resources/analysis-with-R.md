**Collecting Data from PCIbex Farm**

1.  **Run the experiment**: After designing and coding your experiment on the PCIbex Farm, you need to run it to collect data. It's recommended to run it multiple times with different participant IDs for testing purposes.
2.  **Access the results file**: On the PCIbex Farm interface, click the **Results** button to view the data collected. Make sure your project is either unpublished or that you are viewing the results for the correct published/unpublished state.
3.  **Delete previous results (optional)**: Before collecting new data for analysis, you might want to delete any existing results, especially if they are from test runs. You can do this by clicking the **...** next to the **Results** button and selecting the option to delete all results.
4.  **Download the results file**: Save the displayed results as a CSV file (e.g., `results.csv`) to a location that your R script can access.

**Analyzing Data with R**

The sources provide guidance on how to read, tidy, and analyze PCIbex results files using R.

1.  **Reading the results into R**: You can use R to read the CSV file. The sources provide a user-defined function `read.pcibex()` that is designed to correctly read PCIbex results files, handling the comment lines that provide column names.

    ```R
    # User-defined function to read in PCIbex Farm results files
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
          m <- regmatches(line,regexec("^# (\\d+)\\. (.+)\\.$",line))[]
          if (length(m) == 3) {
            index <- as.numeric(m)
            value <- m
            if (is.function(fun.col)){
              cols <- fun.col(value,cols)
            }
            cols[index] <- value
            if (index == n.cols){
              break
            }
          }
        }
        close(con)
        return(read.csv(filepath, comment.char="#", header=FALSE, col.names=cols))
      } else{
        return(read.csv(filepath, comment.char="#", header=FALSE, col.names=seq(1:n.cols)))
      }
    }

    # Read in results file
    results <- read.pcibex("results.csv")
    ```

    This function reads the column names from the comment section at the beginning of the results file. You need to ensure that your R script and the `results.csv` file are in the same working directory.

2.  **Understanding the results file structure**: The default PCIbex results file includes columns like time of receipt, participant IP hash, controller name, item number, element number, type, group, PennElementType, PennElementName, parameter, value, event time, and comments.

    *   When you use the `.log()` command on an element in a trial, additional rows are added to the results file containing information about that element (e.g., when a Canvas is printed, which key was pressed, the value of a Selector). The `PennElementName` column will indicate which element the log corresponds to, and the `Parameter` and `Value` columns will provide specific details.
    *   When you use the `.log(NAME, VALUE)` method on a trial (often within a `Template`), new columns with the specified `NAME` will be added to the results file for that trial, containing the corresponding `VALUE`.

3.  **Tidying the data (if using `tidyverse`)**: If you prefer using the `tidyverse` package in R, you might need to tidy your data because each trial's information might be spread across multiple rows. The sources provide an example of how to use `dplyr` and `tidyr` functions to reshape the data into a tidy format where each observation has its own row and each variable has its own column. This often involves filtering for relevant rows, selecting specific columns, grouping data, creating new variables (e.g., for event type or selection), and then using `pivot_wider()` to spread data across columns.

    ```R
    # Example using tidyverse (assuming you have loaded dplyr and tidyr)
    library(dplyr)
    library(tidyr)

    tidied_results <- results %>%
      filter(PennElementName == "side-by-side" | PennElementName == "selection") %>%
      select(ID, group, item, condition, PennElementName, Value, EventTime) %>%
      group_by(ID, item) %>%
      mutate(event = case_when(
        PennElementName == "side-by-side" ~ "canvas_time",
        PennElementName == "selection" ~ "selection_time"
      ),
      selection = case_when(
        "singular" %in% Value ~ "singular",
        "plural" %in% Value ~ "plural",
        FALSE ~ NA_character_
      ),
      EventTime = if_else(EventTime == "Never", NA_real_, suppressWarnings(as.numeric(EventTime)))) %>%
      ungroup() %>%
      select(-PennElementName, -Value) %>%
      pivot_wider(names_from = event, values_from = EventTime)
    ```

4.  **Analyzing the data**: Once the data is read and potentially tidied, you can perform various analyses depending on your research questions. Examples from the sources include:

    *   **Calculating reaction times**: This often involves subtracting the timestamp of the stimulus presentation (e.g., when a Canvas was printed) from the timestamp of the response (e.g., a key press or a selection).
    *   **Calculating accuracy**: This involves comparing the participant's response to the expected or correct answer, often derived from the experimental conditions or the stimuli themselves.
    *   **Calculating descriptive statistics**: You can use R functions (e.g., `mean()`, `sd()`, `summarize()` from `dplyr`) to calculate average reaction times, accuracy rates, etc., often grouped by experimental conditions or participant IDs.

    ```R
    # Example of calculating reaction times and accuracy (using tidied_results from above)
    tidied_results <- tidied_results %>%
      mutate(reaction_time = selection_time - canvas_time,
             correct = if_else(condition == selection, 1, 0))

    # Example of calculating average reaction time by condition
    average_rt_by_condition <- tidied_results %>%
      group_by(condition) %>%
      summarize(avg_rt = mean(reaction_time, na.rm = TRUE),
                n = sum(!is.na(reaction_time)))

    # Example of calculating average response accuracy by participant
    average_accuracy_by_participant <- tidied_results %>%
      group_by(ID) %>%
      summarize(accuracy = sum(correct, na.rm = TRUE) / sum(!is.na(correct)),
                answered = sum(!is.na(correct)) / n())
    ```

By following these steps, you can effectively collect the data from your PCIbex experiment on the PCIbex Farm and then use R, potentially with the `read.pcibex()` function and `tidyverse` tools, to organize and analyze your experimental results. Remember to tailor your R analysis to the specific data you logged and the research questions you aim to answer.
