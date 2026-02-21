# New features to implement

## Facial recognition

I would like the tagging UI to help identify faces and make them easy to tag. After faces have been tagged, I want an option to search the open folder's photos and find the "same" faces in other photos and offer to auto tag them as well. Eventually, this would give the user a way to see all photos of a given person across their library.

We can implement incrementally:

1. Add a facial recognition in the photo viewer (only shown when labels are not hidden)
    - Should use apple's built-in APIs (apple intelligence?) OR a third-party library/dependency. Don't re-invent the wheel.
2. As part of the indexing process, scan all photos for faces and build an index. These can be used to suggest labels in the labeling UI or as part of a batch assign labeling functionality in a future step.
    - Key question is where does this data get saved? As part of app data? What is ideal here?
    - If this process is significantly more intensive than the existing indexing, we should consider moving it to it's own process.
3. Build features on top of facial indexing:
    1. From the labeling UI, if a face is "known" (associated to an existing label), suggest the same label.
    2. Create a new route/view build off of the library view that shows all known faces and gives the abililty assign across all photos from one place.
    3. Find-by-face view where all faces are shown as tiles, clicking the face will show a view of all photos of that person. This would probably be part of the batch assign label by face UI. That is 2 and 3 of this list are probably the same view.

## Audio recording and processing

This feature, in its end state, would allow the user to enable recording audio while viewing the photos. The audio would be saved to file with the same name as the photo. Then, an additional process would run speech to text on the audio and capture the audio in text. The text couldthen be summarized using Apple intelligence (where available) to create a summary. Both the summary and the full text would be appended to the notes markdown document in a structured way that could be read/updated.

Incremental implementation:

1. Audio recording during viewing
    - Record button lives in the viewer toolbar, in `.secondaryAction`, next to presentation controls.
    - When enabled, when a new photo is viewed audio recording would start.
    - When user navigates away from that photo, audio recording is stopped and saved.
    - While recording, the record button turns red.
    - When moving to a new photo while recording, the button blinks 3 times to indicate a new recording has started.
    - Audio should be trimmed for silence. Long pauses or silences should be cropped out to keep audio files more concise.
    - Audio format should be as small as possible—use sensible standards here.
    - Audio files should be named the same as the photo with a date date appended in ISO format. This way multiple audio files can be created without name collisions.
2. Speech to text on the audio should be run to generate a text version of the audio recording
    - This should use apple intelligence where available. If apple intelligence is not available, can we still do this? I'm not sure if there are libraries or other ways to achieve? Please advise.
    - When this feature is implemented, the start recording dialog should now have two checkbox options: "Save original recording files" and "Update note with recording text". Those checkboxes will determine the settings for the recording "session".
    - When enabled, text should be appended to the notes markdown file. The text should have a heading of "Audio - DATE" where the date is the date time of the recording.
    - When save not enabled, after the audio files are processed to convert speech to text, the audio files should be moved to trash. Let's not hard delete.
3. Summaries should be created of recordings and also appended to the notes file
    - An additional option should be added to the start recording dialog: "Save recording summaries to notes", should default to on
    - When enabled, use apple intelligence (or comparable) to summarize the text recording.
    - When enabled, append the summary to the notes file with "Audio Summary - DATE"
