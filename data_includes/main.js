PennController.ResetPrefix(null) // Shorten command names (keep this line here))

// Start with welcome screen, then present test trials in a random order,
// and show the final screen after sending the results
Sequence( "welcome" , "practice" , randomize("test") , "send" , "final" )

Header( /* void */ )
    // Generate a random 6-character ID for each participant
    .log( "ID" , Math.random().toString(36).substring(2,8) )

// Welcome screen and logging user's ID
newTrial( "welcome" ,
    // We will print all Text elements, horizontally centered
    defaultText.center().print()
    ,
    newText("Welcome!")
    ,
    newText("In this experiment you are asked to decide whether the letter strings (appearing at the center of the screen) form real English words.")
    ,
    // Updated instruction keys to match ldt.md
    newText("To do this, press J if what you see is a word, or F if it is not a word.")
    ,
    newText("You should do this as quickly and accurately as possible.")
    ,
    newText("When you are ready, press SPACE to do a practice run.")
    ,
    newKey(" ").wait()  // Finish trial upon press on spacebar
)

newTrial("practice" ,
    // Text element at the top of the page to signal this is a practice trial
    newText("practice").color("blue").print("center at 50vw","top at 1em")
    ,
    // Display all future Text elements centered on the page, and log their display time code
    defaultText.center().print("center at 50vw","middle at 50vh")
    ,
    // Automatically start and wait for Timer elements when created
    defaultTimer.start().wait()
    ,
    // Mask, shown on screen for 500ms
    newText("mask","######"),
    newTimer("maskTimer", 500),
    getText("mask").remove()
    ,
    // Prime, shown on screen for 42ms (adjust timing as needed based on ldt.md recommendations)
    newText("prime","flower"), // Example prime
    newTimer("primeTimer", 42), // Consider 30-50ms range
    getText("prime").remove()
    ,
    // Target, shown on screen until F or J is pressed
    newText("target","FLOWER") // Example target
    ,
    // Use a tooltip to give instructions matching the welcome screen
    newTooltip("guide", "Now press J if this is an English word, F otherwise")
        .position("bottom center")  // Display it below the element it attaches to
        .key("", "no click")        // Prevent from closing the tooltip (no key, no click)
        .print(getText("target"))   // Attach to the "target" Text element
    ,
    newKey("answerTarget", "FJ")
        .wait()                 // Only proceed after a keypress on F or J
        .test.pressed("J")      // Test if J (word) was pressed
        .success( getTooltip("guide").text("<p>Yes, FLOWER <em>is</em> an English word (You pressed J)</p>") )
        .failure( getTooltip("guide").text("<p>You should press J: FLOWER <em>is</em> an English word (You pressed F)</p>") )
    ,
    getTooltip("guide")
        .label("Press SPACE to start the main experiment")  // Add a label to the bottom-right corner
        .key(" ")                       // Pressing Space will close the tooltip
        .wait()                         // Proceed only when the tooltip is closed
    ,
    getText("target").remove()          // End of trial, remove "target"
)

// Executing experiment from ldt_stimuli.csv table
Template( "ldt_stimuli.csv" ,
    row => newTrial( "test" ,
        // Display all Text elements centered on the page, and log their display time code
        defaultText.center().print("center at 50vw","middle at 50vh").log()
        ,
        // Automatically start and wait for Timer elements when created, and log those events
        defaultTimer.log().start().wait()
        ,
        // Mask, shown on screen for 500ms (Forward Mask)
        newText("mask1","#######"), // Changed name to mask1
        newTimer("maskTimer1", 500), // Changed name to maskTimer1
        getText("mask1").remove()
        ,
        // Prime, shown on screen for 42ms (adjust timing as needed, e.g., 30-50ms)
        newText("prime",row.prime),
        newTimer("primeTimer", 42), // Consider 30-50ms range
        getText("prime").remove()
        ,
        // Backward Mask (Added based on ldt.md)
        newText("mask2","#######"), // Changed name to mask2
        newTimer("maskTimer2", 100), // Display for 100ms (adjust as needed, 100-500ms range suggested)
        getText("mask2").remove()
        ,
        // Target, shown on screen until F or J is pressed
        newText("target",row.target)
        ,
        newKey("answerTarget", "FJ").log().wait()   // Proceed upon press on F or J (log it)
        ,
        getText("target").remove()
        // End of trial, move to next one
    )
    // Log information from the CSV file for this trial
    .log( "Group"     , row.group)
    .log( "Condition" , row.condition)  // 'word' or 'nonword'
    .log( "Expected"  , row.expected )  // 'f' or 'j'
    .log( "PrimeType" , row.primetype ) // 'related' or 'unrelated'
    .log( "PrimeWord" , row.prime )     // Log the actual prime word
    .log( "TargetWord", row.target )    // Log the actual target word
)

// Send the results
SendResults("send")

// A simple final screen
newTrial ( "final" ,
    newText("The experiment is over. Thank you for participating!")
        .print()
    ,
    newText("You can now close this page.")
        .print()
    ,
    // Stay on this page forever
    newButton().wait()
)
