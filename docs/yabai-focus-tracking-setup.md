# Yabai Window Focus Recency Tracking Setup for Script Kit

This document provides the scripts and instructions to set up a system for tracking the focus history of windows managed by Yabai on macOS, designed to be used with the Script Kit app. This allows you to quickly focus Yabai-managed windows using Script Kit, sorted by focus recency.

## Purpose

The core components are:
1.  **Yabai:** The macOS tiling window manager.
2.  **Focus Logging Script (`log_yabai_focus.sh`):** A Bash script triggered by Yabai whenever window focus changes. It maintains a log file (`~/.cache/yabai_focus_history.log`) containing the IDs of the last N focused windows.
3.  **Yabai Signal Configuration:** A line in `.yabairc` to execute the logging script on focus events.
4.  **Utility Library (`yabai-utils.ts`):** A TypeScript module placed in your Script Kit `lib` folder (`~/.kenv/lib/`) that reads the log file and Yabai's current window state.
5.  **Main Script Kit Script (`yabai-focus.ts`):** A script run via Script Kit (`Cmd+;`) that uses the utility library to present a list of recently focused windows and focuses the selected one.

## Prerequisites

*   **Yabai:** The tiling window manager for macOS. (Install via Homebrew: `brew install koekeishiya/formulae/yabai`). Ensure it's running and configured.
*   **jq:** A command-line JSON processor. (Install via Homebrew: `brew install jq`)
*   **Script Kit App:** Download and install from [scriptkit.com](https://www.scriptkit.com/).

## Setup Steps

1.  **Create the Logging Script:**
    *   Choose a location for auxiliary scripts (e.g., `~/.config/scripts/`). Create the directory if it doesn't exist: `mkdir -p ~/.config/scripts`
    *   Create the file `~/.config/scripts/log_yabai_focus.sh`.
    *   Paste the following Bash code into the file:

        ```bash
        #!/bin/bash

        # Script to log the focused yabai window ID for recency tracking.

        LOG_FILE="$HOME/.cache/yabai_focus_history.log"
        MAX_HISTORY=20 # Keep track of the last 20 focused windows
        TMP_LOG_FILE="${LOG_FILE}.tmp.$$" # Temporary file for atomic write

        # Ensure the cache directory exists
        mkdir -p "$(dirname "$LOG_FILE")"

        # Check if the YABAI_WINDOW_ID environment variable is set (provided by the signal)
        if [[ -z "$YABAI_WINDOW_ID" ]]; then
          # For testing or manual execution, get the current focused window ID
          CURRENT_FOCUSED_ID=$(/opt/homebrew/bin/yabai -m query --windows --window | /opt/homebrew/bin/jq -r '.id')
          # Validate the manually fetched ID
          if [[ -z "$CURRENT_FOCUSED_ID" || "$CURRENT_FOCUSED_ID" == "null" ]]; then
            rm -f "$TMP_LOG_FILE" # Clean up temp file on error
            exit 1 # Exit if no valid ID found
          fi
          WINDOW_ID="$CURRENT_FOCUSED_ID"
        else
          WINDOW_ID="$YABAI_WINDOW_ID"
        fi

        # Ensure WINDOW_ID is not empty or null before proceeding
        if [[ -z "$WINDOW_ID" || "$WINDOW_ID" == "null" ]]; then
          rm -f "$TMP_LOG_FILE" # Clean up temp file on error
          exit 1 # Exit if ID is invalid
        fi

        # Read existing history FROM THE ACTUAL LOG FILE
        history=()
        if [[ -f "$LOG_FILE" ]]; then
          # Read line by line using while read
          while IFS= read -r line || [[ -n "$line" ]]; do
              # Trim whitespace (optional, but good practice)
              line_trimmed=$(echo "$line" | xargs)
              if [[ -n "$line_trimmed" ]]; then # Add only non-empty lines
                  history+=("$line_trimmed")
              fi
          done < "$LOG_FILE"
        else
          # history array is already initialized empty
          : # No action needed if file doesn't exist
        fi

        # Remove the current window ID if it already exists in the history
        new_history=()
        for id in "${history[@]}"; do
          # Trim whitespace just in case and compare
          id_trimmed=$(echo "$id" | xargs) # Trim whitespace
          if [[ -n "$id_trimmed" && "$id_trimmed" != "$WINDOW_ID" ]]; then # Ensure ID is not empty after trimming
            new_history+=("$id_trimmed")
          fi
        done

        # Prepend the new window ID
        updated_history=("$WINDOW_ID" "${new_history[@]}")

        # Trim the history to MAX_HISTORY entries
        if [[ ${#updated_history[@]} -gt $MAX_HISTORY ]]; then
          trimmed_history=("${updated_history[@]:0:$MAX_HISTORY}")
        else
          trimmed_history=("${updated_history[@]}")
        fi

        # Write the updated history to the TEMPORARY file
        printf "%s\\n" "${trimmed_history[@]}" > "$TMP_LOG_FILE"

        # Atomically rename the temporary file to the target log file
        mv "$TMP_LOG_FILE" "$LOG_FILE"
        if [[ $? -ne 0 ]]; then
            rm -f "$TMP_LOG_FILE" # Clean up temp file on error
            exit 1
        fi

        exit 0
        ```

    *   Make the script executable: `chmod +x ~/.config/scripts/log_yabai_focus.sh` (Adjust path if you used a different location).

2.  **Configure Yabai Signal:**
    *   Edit your Yabai configuration file (`~/.yabairc`).
    *   Add the following line, **making sure the absolute path to the script is correct**:

        ```sh
        yabai -m signal --add event=window_focused action="/Users/johnlindquist/.config/scripts/log_yabai_focus.sh"
        ```
        *(Replace `/Users/johnlindquist/.config/scripts/` with the actual absolute path if you chose a different location in Step 1)*.

    *   Restart the Yabai service for the changes to take effect: `yabai --restart-service`

3.  **Create the Utility Library:**
    *   Navigate to your Script Kit environment directory. Typically `~/.kenv/`. You can find it via Script Kit: `Cmd+;` -> `Kit` -> `Open .kenv at Path in Finder/Terminal`.
    *   Ensure a `lib` folder exists inside `.kenv` (`mkdir -p ~/.kenv/lib`).
    *   Create the file `~/.kenv/lib/yabai-utils.ts`.
    *   Paste the following TypeScript code into the file:

        ```typescript
        // Utility functions for yabai scripts
        import "@johnlindquist/kit"
        import * as fs from "fs/promises" // Use fs/promises for async operations
        import * as path from "path"

        export const YABAI_PATH = "/opt/homebrew/bin/yabai" // Assumes Homebrew default path
        const FOCUS_LOG_PATH = path.join(env.HOME, ".cache", "yabai_focus_history.log")

        interface YabaiWindow {
            id: number;
            pid: number;
            app: string;
            title: string;
            frame: {
                x: number;
                y: number;
                w: number;
                h: number;
            };
            "stack-index": number;
            "can-move": boolean;
            "can-resize": boolean;
            "has-focus": boolean;
            "has-shadow": boolean;
            "has-border": boolean;
            "has-parent-zoom": boolean;
            "has-fullscreen-zoom": boolean;
            "is-native-fullscreen": boolean;
            "is-visible": boolean;
            "is-minimized": boolean;
            "is-hidden": boolean;
            "is-floating": boolean;
            "is-sticky": boolean;
            "is-grabbed": boolean;
            level: number;
            layer: string;
            sublayer: string;
            display: number;
            space: number;
            split: string; // "horizontal" | "vertical" | ""
        }

        // Helper function to read focus history log
        const readFocusHistory = async (): Promise<number[]> => {
            try {
                const content = await fs.readFile(FOCUS_LOG_PATH, "utf-8")
                // Filter out empty lines that might result from concurrent writes or initial creation
                return content.trim().split("\n").filter(Boolean).map(id => parseInt(id.trim(), 10)).filter(id => !isNaN(id))
            } catch (error) {
                // If the file doesn't exist or there's an error reading, return empty array
                // console.warn(`Could not read focus history log: ${FOCUS_LOG_PATH}`, error)
                return []
            }
        }

        // Main function to get sorted windows for Script Kit prompt
        export const getWindows = async () => {
            const yabaiPromise = exec(`${YABAI_PATH} -m query --windows`);
            const timeoutPromise = new Promise((_, reject) =>
                setTimeout(() => reject(new Error("Yabai query timed out after 2 seconds.")), 2000)
            );

            try {
                const jsonResult = await Promise.race([yabaiPromise, timeoutPromise]) as { stdout: string; stderr: string; } | Error;

                if (jsonResult instanceof Error) {
                    console.error(jsonResult.message);
                    await div(`<div class="p-4 text-red-500">${jsonResult.message}</div>`)
                    process.exit(1);
                }
                if (!jsonResult.stdout) {
                    await div(`<div class="p-4 text-red-500">Failed to get yabai windows. Is yabai running? stderr: ${jsonResult.stderr}</div>`)
                    console.error(`Failed to get yabai windows. Is yabai running? stderr: ${jsonResult.stderr}`)
                    process.exit(1);
                }

                const allWindows: YabaiWindow[] = JSON.parse(jsonResult.stdout.trim());
                const recentIds = await readFocusHistory();

                // Find the currently focused window ID
                const focusedWindow = allWindows.find(w => w["has-focus"]);
                const focusedWindowId = focusedWindow?.id;

                // Filter out invalid windows (no app/title) and the currently focused window
                const validWindows = allWindows.filter(w => w.app && w.title && w.id !== focusedWindowId);

                // Create a map for quick lookup: ID -> Window Object
                const windowMap = new Map(validWindows.map(w => [w.id, w]));

                const sortedWindows: YabaiWindow[] = [];

                // Add windows based on recentIds order, removing them from the map
                for (const id of recentIds) {
                    if (windowMap.has(id)) {
                        sortedWindows.push(windowMap.get(id)!);
                        windowMap.delete(id); // Ensure no duplicates
                    }
                }

                // Add any remaining valid windows (not in recentIds log) to the end
                // These might be newly opened windows not yet logged or windows beyond the log's MAX_HISTORY
                sortedWindows.push(...windowMap.values());

                // Format for Script Kit's arg prompt
                return sortedWindows.map(w => ({
                    name: `${w.app}: ${w.title?.substring(0, 80) || "Untitled"}`,
                    description: `Space ${w.space} · Display ${w.display} · ID ${w.id}`,
                    value: w.id, // The window ID is the value needed for the focus command
                }));

            } catch (error) {
                const errorMessage = error instanceof Error ? error.message : String(error);
                console.error("Error fetching or processing windows:", errorMessage);
                await div(`<div class="p-4 text-red-500">Error fetching/processing yabai windows: ${errorMessage}</div>`)
                process.exit(1);
            }
        };
        ```

4.  **Create the Main Script Kit Script:**
    *   Open Script Kit (`Cmd+;`).
    *   Create a new script (`Cmd+N`).
    *   Name it something like `Yabai Focus Window` (this determines how you find it in Script Kit).
    *   Set a shortcut if desired (e.g., `Option+F`).
    *   Paste the following code into the script editor:

        ```typescript
        // Name: Yabai Focus Window
        // Description: Focus a yabai window selected from a recency-sorted list
        // Author: John Lindquist (Modified)
        // Shortcut: option f

        import "@johnlindquist/kit"
        // Assumes yabai-utils.ts is in ~/.kenv/lib/
        import { getWindows, YABAI_PATH } from "../lib/yabai-utils.js"

        const windows = await getWindows()

        if (!windows || windows.length === 0) {
            await div(`<div class="p-4 text-yellow-500">No other Yabai managed windows found to focus.</div>`)
            process.exit(0);
        }

        // Use Script Kit's arg prompt to show the sorted list
        const targetWindowId = await arg("Select window to focus", windows)

        // Hide the Script Kit prompt immediately after selection
        await hide()

        if (targetWindowId) {
            // Execute yabai command to focus the selected window ID
            await exec(`${YABAI_PATH} -m window --focus ${targetWindowId}`)
            // Optional: Show a brief confirmation toast
            // toast(`Focused window ${targetWindowId}`)
        } else {
            // Handle case where user escapes the prompt
            // toast("Focus action cancelled")
        }
        ```
    *   Save the script (`Cmd+S`).

## Dependencies

The `yabai-utils.ts` library implicitly uses `@johnlindquist/kit`, which is provided by the Script Kit app environment. No separate `npm install` is typically needed *within* the `.kenv` structure for Kit's own APIs.

## Usage

1.  Ensure Yabai is running.
2.  Ensure the `log_yabai_focus.sh` script is being triggered (focus different windows a few times, check for `~/.cache/yabai_focus_history.log` being created/updated).
3.  Activate Script Kit (`Cmd+;`).
4.  Type the name you gave the main script (e.g., "Yabai Focus") or use the shortcut you assigned (e.g., `Option+F`).
5.  A prompt will appear, listing your Yabai-managed windows, sorted by the most recently focused (excluding the current window).
6.  Select the desired window and press Enter.
7.  Script Kit will disappear, and Yabai should focus the selected window. 