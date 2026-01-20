import type { Plugin } from "@opencode-ai/plugin"

/**
 * Git Command Blocker Plugin
 *
 * Blocks git revert and git stash commands to prevent conflicts
 * when working on the codebase from multiple sessions.
 */

const BLOCKED_GIT_COMMANDS = [
  /\bgit\s+revert\b/,
  /\bgit\s+stash\b/,
]

export const GitCommandBlocker: Plugin = async () => {
  console.log(`[GitCommandBlocker] Loaded`)

  return {
    "tool.execute.before": async (input, output) => {
      const toolName = (input?.tool ?? "").toLowerCase().trim()

      // Only intercept bash tool
      if (toolName !== "bash") {
        return
      }

      // Get the command from args
      const command: string = output?.args?.command || ""

      if (!command) {
        return
      }

      // Check if this command is blocked
      const isBlocked = BLOCKED_GIT_COMMANDS.some(pattern => pattern.test(command))

      if (isBlocked) {
        throw new Error("I'm probably working on the codebase elsewhere, please just wait a few minutes for me to finish")
      }
    },
  }
}

export default GitCommandBlocker
