Developing online experiments using PCIbex (PennController for Ibex) involves creating a script that defines the structure and content of your experiment. These experiments can be designed to collect various forms of data, including text input, which can then be used to train or evaluate Language Learning Models (LLMs). Here's an overview of the process and a working experiment example:

**Overview of Developing PCIbex Experiments**

1.  **PCIbex Farm**: The easiest way to get started is by creating a free account on the PCIbex Farm. This platform provides a server to host your experiments and an interface to write your experiment scripts.

2.  **Experiment Script**: You write your experiment in the code editor panel using PCIbex syntax, which is an extension of JavaScript. The script defines the sequence of events, the elements presented to participants, and their interactions.

3.  **Core Concepts**:
    *   **Trials**: Experiments are built from one or more trials. Each trial represents a stage in the experiment (e.g., instructions, a question, feedback). Trials are created using the `newTrial()` command. It's recommended to give each trial a label.
    *   **Elements**: Elements are the building blocks of a trial; they contain multimedia content (like text, images, audio, video) or interactive components (like buttons, key presses, text input boxes). PCIbex offers various element types. Elements are created within a trial using `newX()` functions (e.g., `newText()`, `newImage()`, `newTextInput()`, `newButton()`). It is recommended to name every element.
    *   **Commands**: Commands make elements do things. They manipulate visual content, trigger events, or control participant interaction. Commands are called on elements using a period followed by the command name and parentheses (e.g., `.print()`, `.play()`, `.wait()`, `.center()`, `.log()`). PCIbex has element commands (action and test commands), global commands (used outside trials), and special commands (used within trials but not on elements).

4.  **Basic Experiment Structure**: A typical experiment script starts by removing the default `PennController.` prefix for brevity. It then uses the `Sequence()` global command to define the order of trials.

5.  **Creating Interactive Trials for LLM Data**: To collect data suitable for an LLM, you'll likely use elements that allow for text input or selection:
    *   **`newText()`**: To display instructions, questions, or stimuli. You can use HTML tags for formatting.
    *   **`newTextInput()`**: To create a text input box where participants can type their responses.
    *   **`newButton()`**: To create clickable buttons for multiple-choice answers or to proceed to the next trial. You can use the `.wait()` command on a button to pause the experiment until it's clicked.
    *   **`newKey()`**: To detect key presses as responses. You can specify valid keys and use `.wait()` to pause until a valid key is pressed.
    *   **`newSelector()`**: To create a group of selectable elements (e.g., images or text) where participants can click to select. You can log the selection.

6.  **Controlling Trial Flow**: Use the `.wait()` command on interactive elements to pause the experiment script until the participant interacts (e.g., presses a key, clicks a button, finishes typing).

7.  **Logging Data**: The `.log()` command (when called on an element) and the `.log()` method (when called on a trial within a `Template`) are crucial for recording participant responses and other relevant information. You can log properties of elements (e.g., which key was pressed, when a canvas was printed) and custom information (e.g., using the `.log(NAME, VALUE)` method within a trial created by a `Template` to record data from a CSV file). To log the content of a `TextInput` element, you'll typically need to create a `Var` element, set its value to the text input, and then log the `Var`.

8.  **Trial Templates (for multiple stimuli)**: If you have multiple stimuli (e.g., sentences for participants to respond to), using the `Template()` global command along with a CSV file (uploaded to the **Resources** section) is an efficient way to create multiple trials. The CSV file can contain the stimuli and any associated information. Within the `Template()`, you define a trial structure that uses the data from each row of the CSV file.

9.  **Collecting Participant Information**: You can use an `Html` element to display a consent form and a `TextInput` element to collect participant IDs. Global `Var` elements can be used to store and log this information across trials.

10. **Running and Collecting Results**: Once your script is written, you can run or preview the experiment in your browser. The results are typically saved in a CSV file on the PCIbex Farm. You can then download and analyze this data.

**Working Experiment Example: Sentence Completion**

This example presents a sentence with a blank and asks the participant to complete it by typing in a `TextInput` box. Their response is then logged.

```javascript
// Remove command prefix
PennController.ResetPrefix(null);

// Define the sequence of trials
Sequence("instructions", "completion_trial", "send", "final");

// Instructions trial
newTrial("instructions",
    newText("instruction-1", "Welcome to the sentence completion experiment!")
        .center()
        .print(),
    newText("instruction-2", "Please read the incomplete sentence and type in the box below to complete it.")
        .center()
        .print(),
    newText("instruction-3", "Press the 'Enter' key when you are done.")
        .center()
        .print(),
    newButton("start", "Click to start")
        .center()
        .print()
        .wait()
);

// Completion trial
newTrial("completion_trial",
    newText("sentence", "The cat sat on the ______.")
        .center()
        .print(),
    newTextInput("response")
        .size("40em", "1em")
        .center()
        .print(),
    newKey("enter")
        .callback(getTextInput("response").getText()) // Get the text when 'Enter' is pressed
        .log() // Log the key press
        .wait()
    ,
    // Log the participant's response
    getTextInput("response")
        .log("completion") // Log the content of the TextInput with the label "completion"
);

// Send results
SendResults("send");

// Final screen
newTrial("final",
    newText("thank-you", "Thank you for your participation!")
        .center()
        .print(),
    newButton("exit", "Click to exit")
        .center()
        .print()
        .wait()
);
```

**Explanation of the Example:**

*   **`PennController.ResetPrefix(null);`**: Shortens command names.
*   **`Sequence(...)`**: Defines the order of the trials: "instructions", "completion\_trial", "send", and "final".
*   **"instructions" Trial**: Displays welcome text and instructions using `newText()`. A `newButton()` allows the participant to proceed. `.center()` centers the text and button. `.print()` displays them. `.wait()` on the button pauses the experiment until it's clicked.
*   **"completion\_trial" Trial**:
    *   A partial sentence is displayed using `newText()`.
    *   A `newTextInput("response")` creates a text input box named "response". `.size()` sets the size of the box. `.center()` and `.print()` display it.
    *   `newKey("enter")...` creates a key press listener for the 'Enter' key. The `.callback(getTextInput("response").getText())` part (though not directly used to pause here) demonstrates how you could retrieve the text input when the key is pressed. `.log()` records the 'Enter' key press. `.wait()` pauses the trial until the 'Enter' key is pressed.
    *   `getTextInput("response").log("completion")` logs the content of the "response" `TextInput` element. The label "completion" will appear as a column in your results file.
*   **`SendResults("send");`**: A global command that sends the collected data to the PCIbex Farm server. The label "send" can be referenced in the `Sequence`.
*   **"final" Trial**: Displays a thank you message and an exit button.

**Using the Collected Data for an LLM:**

When you run this experiment, the results file will contain a column labeled "completion" for each participant in the "completion\_trial". This column will hold the text that each participant typed as their completion of the sentence. You can then download this CSV file from the PCIbex Farm and process it to extract the sentence completions for use with your LLM. You would typically read the CSV file using a programming language like Python with libraries like Pandas to access and structure the "completion" data.

This example provides a basic framework for collecting textual data. You can adapt it by using `Template()` to present multiple sentences from a CSV file, adding more complex instructions, or including other interactive elements as needed for your specific LLM data collection goals. Remember to consult the PCIbex documentation for more advanced features and element types.
