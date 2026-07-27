import { tool } from "@opencode-ai/plugin"
import path from "path"

export const get_session_stats = tool({
  description: "Get token usage and session stats for the current opencode session. Returns input/output tokens, user message words, and lines added/deleted from write/edit operations.",
  args: {},
  async execute(_args, _context) {
    try {
      const script = path.join(process.cwd(), ".opencode/tools/get_session_stats.py")
      const sessionID = _context.sessionID
      const proc = Bun.spawn(["python3", script, sessionID])
      const output = await new Response(proc.stdout).text()
      const stats = JSON.parse(output.trim())
      
      return [
        `Session Stats:`,
        `  Input Tokens: ${stats.input_tokens.toLocaleString()}`,
        `  Output Tokens: ${stats.output_tokens.toLocaleString()}`,
        `  User Words: ${stats.user_word_count}`,
        `  Lines Added: ${stats.lines_added}`,
        `  Lines Deleted: ${stats.lines_deleted}`,
        `  Files Changed: ${stats.files_changed}`,
      ].join("\n")
    } catch (e) {
      return `Error: ${e.message}`
    }
  },
})
