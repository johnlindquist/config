import type { Plugin } from "@opencode-ai/plugin"

/**
 * Rust Check Plugin
 * 
 * Runs cargo check after .rs files are edited and forces the agent
 * to fix errors before continuing.
 */
export const RustCheck: Plugin = async ({ directory, $ }) => {
  // Track pending .rs file edits (captured in before, checked in after)
  let pendingRsFile: string | null = null

  return {
    // Capture the file path BEFORE the edit
    "tool.execute.before": async (input, output) => {
      const toolName = (input?.tool ?? "").toLowerCase().trim()
      
      if (toolName !== "edit") {
        pendingRsFile = null
        return
      }
      
      const filePath: string = output?.args?.filePath ?? output?.args?.file ?? ""
      
      if (filePath.endsWith(".rs")) {
        pendingRsFile = filePath
      } else {
        pendingRsFile = null
      }
    },

    // Run cargo check AFTER the edit completes
    "tool.execute.after": async (input) => {
      const toolName = (input?.tool ?? "").toLowerCase().trim()
      
      if (toolName !== "edit" || !pendingRsFile) {
        return
      }
      
      const filePath = pendingRsFile
      pendingRsFile = null // Clear for next edit

      // Run cargo check in the project directory
      // Using .nothrow() so it returns result instead of throwing on non-zero exit
      const result = await $`cargo check 2>&1`.cwd(directory).nothrow()
      
      if (result.exitCode !== 0) {
        throw new Error(
          `Rust compilation error after editing ${filePath}. Fix the errors before continuing:\n\n${result.text()}`
        )
      }
    },
  }
}

export default RustCheck
