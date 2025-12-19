#!/usr/bin/env bun
/**
 * Smart file finder with streaming fzf and Zed integration
 * Usage: smart-find.ts "natural language query"
 */

import { spawn, spawnSync } from "bun";

const EXCLUDES = [
  "node_modules",
  ".git",
  "dist",
  "build",
  ".next",
  "vendor",
  "__pycache__",
  ".venv",
  ".cache",
  "coverage",
];

const FD_EXCLUDES = EXCLUDES.map((e) => ["-E", e]).flat();
const RG_EXCLUDES = EXCLUDES.map((e) => `--glob=!${e}`);

// Pattern shortcuts - skip AI for these
const INSTANT_PATTERNS: Record<string, string[]> = {
  // File extensions
  "*.ts": ["fd", "-e", "ts", "-t", "f", ...FD_EXCLUDES],
  "*.tsx": ["fd", "-e", "tsx", "-t", "f", ...FD_EXCLUDES],
  "*.js": ["fd", "-e", "js", "-t", "f", ...FD_EXCLUDES],
  "*.json": ["fd", "-e", "json", "-t", "f", ...FD_EXCLUDES],
  "*.md": ["fd", "-e", "md", "-t", "f", ...FD_EXCLUDES],
  "*.sh": ["fd", "-e", "sh", "-t", "f", ...FD_EXCLUDES],
  "*.lua": ["fd", "-e", "lua", "-t", "f", ...FD_EXCLUDES],
  "*.css": ["fd", "-e", "css", "-t", "f", ...FD_EXCLUDES],
  "*.html": ["fd", "-e", "html", "-t", "f", ...FD_EXCLUDES],
  "*.py": ["fd", "-e", "py", "-t", "f", ...FD_EXCLUDES],
  "*.go": ["fd", "-e", "go", "-t", "f", ...FD_EXCLUDES],
  "*.rs": ["fd", "-e", "rs", "-t", "f", ...FD_EXCLUDES],
  "*.yaml": ["fd", "-e", "yaml", "-e", "yml", "-t", "f", ...FD_EXCLUDES],
  "*.toml": ["fd", "-e", "toml", "-t", "f", ...FD_EXCLUDES],

  // Common queries
  typescript: ["fd", "-e", "ts", "-e", "tsx", "-t", "f", ...FD_EXCLUDES],
  config: ["fd", "-e", "json", "-e", "yaml", "-e", "yml", "-e", "toml", "-e", "ini", "-t", "f", ...FD_EXCLUDES],
  tests: ["fd", "-g", "*.test.*", "-g", "*.spec.*", "-t", "f", ...FD_EXCLUDES],
  scripts: ["fd", "-e", "sh", "-t", "f", ...FD_EXCLUDES],
  readme: ["fd", "-i", "readme", "-t", "f", ...FD_EXCLUDES],
};

// Keyword patterns that trigger specific searches
const KEYWORD_PATTERNS: Array<{ match: RegExp; cmd: (m: RegExpMatchArray) => string[] }> = [
  // "files containing X" - must start with "containing" to be specific
  {
    match: /^(?:files?\s+)?containing\s+["']?(\w+)["']?/i,
    cmd: (m) => ["rg", "-l", m[1], ...RG_EXCLUDES],
  },
  // "X files" where X is an extension
  {
    match: /^(\w+)\s+files?$/i,
    cmd: (m) => ["fd", "-e", m[1], "-t", "f", ...FD_EXCLUDES],
  },
  // "recent X" or "recently modified X"
  {
    match: /recent(?:ly)?(?:\s+(?:modified|edited|changed))?\s+(.+)/i,
    cmd: (m) => ["fd", "-t", "f", "--changed-within", "7d", ...FD_EXCLUDES],
  },
  // "large files"
  {
    match: /large\s+files?/i,
    cmd: () => ["fd", "-t", "f", "-S", "+100k", ...FD_EXCLUDES],
  },
];

function groupByDirectory(files: string[], threshold = 5): string[] {
  // Count files per directory
  const dirCounts = new Map<string, string[]>();

  for (const file of files) {
    const dir = file.includes("/") ? file.substring(0, file.lastIndexOf("/")) : ".";
    if (!dirCounts.has(dir)) dirCounts.set(dir, []);
    dirCounts.get(dir)!.push(file);
  }

  const result: string[] = [];

  for (const [dir, dirFiles] of dirCounts) {
    if (dirFiles.length >= threshold) {
      // Collapse directory - show as group header
      result.push(`📁 ${dir}/ (${dirFiles.length} files)`);
      // Still include files but indented
      for (const f of dirFiles.slice(0, 3)) {
        result.push(`   ${f}`);
      }
      if (dirFiles.length > 3) {
        result.push(`   ... and ${dirFiles.length - 3} more`);
      }
    } else {
      result.push(...dirFiles);
    }
  }

  return result;
}

// Natural AI: Semantically pick files from a broad listing
async function naturalSearch(query: string): Promise<string[]> {
  console.error("🧠 Natural: analyzing file tree...");

  // Get broad file listing
  const listCmd = `fd -t f ${FD_EXCLUDES.join(" ")} | head -500`;
  const listProc = spawn(["sh", "-c", listCmd], { stdout: "pipe", stderr: "pipe" });
  const allFiles = await new Response(listProc.stdout).text();
  await listProc.exited;

  const fileList = allFiles.trim();
  if (!fileList) return [];

  const prompt = `You are finding files for: "${query}"

Here are files in the project:
${fileList}

Pick up to 15 files most likely to match the user's intent.
Think semantically - what would contain "${query}"?
Consider directory names, file names, and common patterns.

Output ONLY file paths, one per line, best matches first:`;

  const shellCmd = `gemini -m gemini-3-flash-preview '${prompt.replace(/'/g, "'\\''")}' 2>/dev/null | grep -E "^[a-zA-Z0-9_./-]" | head -15`;

  const proc = spawn(["sh", "-c", shellCmd], { stdout: "pipe", stderr: "pipe" });
  const output = await new Response(proc.stdout).text();
  await proc.exited;

  return output.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
}

// Programmatic AI: Generate and run search commands
async function programmaticSearch(query: string): Promise<string[]> {
  console.error("⚡ Programmatic: generating search...");

  const commands = await getAICommands(query);
  if (commands.length === 0) return [];

  const cmd = commands[0];
  console.error(`   → ${cmd}`);

  const proc = spawn(["sh", "-c", cmd], { stdout: "pipe", stderr: "pipe" });
  const output = await new Response(proc.stdout).text();
  await proc.exited;

  return output.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
}

// Merge and rank results from both searches
async function mergeAndRank(query: string, natural: string[], programmatic: string[]): Promise<string[]> {
  // Dedupe, preserving order (natural results first as they're semantically picked)
  const seen = new Set<string>();
  const merged: string[] = [];

  // Interleave: natural first (smarter), then programmatic
  for (const f of natural) {
    if (!seen.has(f)) { seen.add(f); merged.push(f); }
  }
  for (const f of programmatic) {
    if (!seen.has(f)) { seen.add(f); merged.push(f); }
  }

  if (merged.length <= 15) return merged;

  // If too many results, have AI rank top 15
  console.error("🎯 Ranking top results...");

  const fileList = merged.slice(0, 50).join("\n");
  const prompt = `Query: "${query}"

Files found:
${fileList}

Pick the TOP 15 most relevant files. Output paths only, best first:`;

  const shellCmd = `gemini -m gemini-3-flash-preview '${prompt.replace(/'/g, "'\\''")}' 2>/dev/null | grep -E "^[a-zA-Z0-9_./-]" | head -15`;
  const proc = spawn(["sh", "-c", shellCmd], { stdout: "pipe", stderr: "pipe" });
  const output = await new Response(proc.stdout).text();
  await proc.exited;

  const ranked = output.split("\n").map((l) => l.trim()).filter((l) => l.length > 0 && merged.includes(l));
  const remaining = merged.filter((f) => !ranked.includes(f));

  return [...ranked, ...remaining];
}

async function getAICommands(query: string): Promise<string[]> {
  const prompt = `You are a semantic file search expert. Find files matching: "${query}"

THINK about what the user REALLY wants:
- Extract the CORE intent (what kind of file? what content?)
- Consider synonyms and related terms
- Be FLEXIBLE - finding something related is better than nothing

SEARCH STRATEGY:
1. For content searches, use: rg -li "pattern1|pattern2|pattern3" --glob "*.ext"
   - Use -i for case insensitive
   - Use | for OR (match ANY term)
   - Pick 2-3 key terms from the query
2. For file names, use: fd -i "pattern" -e ext
3. NEVER chain with xargs - use single rg with OR patterns instead

EXCLUDES (always add): ${EXCLUDES.map((e) => `-g "!${e}"`).join(" ")}

EXAMPLES:
Query: "markdown file with dropbox link to zoom recording"
rg -li "dropbox|zoom|recording" --glob "*.md" -g "!node_modules" -g "!.git"

Query: "config for database connection"
rg -li "database|db|connection|postgres|mysql" --glob "*.{json,yaml,yml,toml,env}" -g "!node_modules" -g "!.git"

Query: "test files for authentication"
fd -i "auth" -e test.ts -e spec.ts -E node_modules -E .git

Output ONLY one command, no explanation:`;

  // Use shell to capture both stdout and stderr, filter noise
  const shellCmd = `gemini -m gemini-3-flash-preview '${prompt.replace(/'/g, "'\\''")}' 2>/dev/null | grep -E "^(fd|rg|find) " | head -1`;

  const proc = spawn(["sh", "-c", shellCmd], {
    stdout: "pipe",
    stderr: "pipe",
  });

  const output = await new Response(proc.stdout).text();
  await proc.exited;

  // Return non-empty lines
  return output
    .split("\n")
    .map((l) => l.trim())
    .filter((l) => l.length > 0);
}

function detectInstantPattern(query: string): string[] | null {
  const q = query.toLowerCase().trim();

  // Direct pattern match
  if (INSTANT_PATTERNS[q]) return INSTANT_PATTERNS[q];

  // Glob pattern like "*.ts"
  if (q.startsWith("*.")) {
    const ext = q.slice(2);
    return ["fd", "-e", ext, "-t", "f", ...FD_EXCLUDES];
  }

  // Keyword patterns
  for (const { match, cmd } of KEYWORD_PATTERNS) {
    const m = q.match(match);
    if (m) return cmd(m);
  }

  return null;
}

async function runSearchCmd(cmdStr: string): Promise<void> {
  // Use shell to handle pipes and complex commands
  const proc = spawn(["sh", "-c", cmdStr], {
    stdout: "pipe",
    stderr: "inherit",
  });

  const reader = proc.stdout.getReader();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    process.stdout.write(value);
  }

  await proc.exited;
}

async function runSearch(cmd: string[]): Promise<void> {
  const proc = spawn(cmd, {
    stdout: "pipe",
    stderr: "inherit",
  });

  const reader = proc.stdout.getReader();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    process.stdout.write(value);
  }

  await proc.exited;
}

async function runWithFzfStr(cmdStr: string): Promise<string[]> {
  const fzfArgs = [
    "--multi",
    "--ansi",
    "--preview",
    "bat --style=numbers --color=always --line-range=:500 {} 2>/dev/null || cat {}",
    "--preview-window",
    "right:50%:wrap",
    "--bind",
    "ctrl-y:execute-silent(echo -n {} | pbcopy)+abort",
    "--bind",
    "ctrl-o:execute-silent(open -R {})+abort",
    "--header",
    "Enter: open in Zed | Tab: multi-select | ctrl-y: copy | ctrl-o: reveal",
  ];

  // Use shell to run the full command with pipe to fzf
  const fullCmd = `${cmdStr} | fzf ${fzfArgs.map((a) => `'${a}'`).join(" ")}`;
  const proc = spawn(["sh", "-c", fullCmd], {
    stdout: "pipe",
    stderr: "inherit",
    stdin: "inherit",
  });

  const output = await new Response(proc.stdout).text();
  await proc.exited;

  return output
    .trim()
    .split("\n")
    .filter((l) => l.length > 0);
}

async function runWithFzf(searchCmd: string[]): Promise<string[]> {
  // Build fzf command with preview and multi-select
  const fzfArgs = [
    "--multi",
    "--ansi",
    "--preview",
    "bat --style=numbers --color=always --line-range=:500 {} 2>/dev/null || cat {}",
    "--preview-window",
    "right:50%:wrap",
    "--bind",
    "ctrl-y:execute-silent(echo -n {} | pbcopy)+abort",
    "--bind",
    "ctrl-o:execute-silent(open -R {})+abort",
    "--header",
    "Enter: open in Zed | Tab: multi-select | ctrl-y: copy | ctrl-o: reveal",
  ];

  // Create search process
  const searchProc = spawn(searchCmd, {
    stdout: "pipe",
    stderr: "inherit",
  });

  // Pipe to fzf
  const fzfProc = spawn(["fzf", ...fzfArgs], {
    stdin: searchProc.stdout,
    stdout: "pipe",
    stderr: "inherit",
  });

  const output = await new Response(fzfProc.stdout).text();
  await fzfProc.exited;

  return output
    .trim()
    .split("\n")
    .filter((l) => l.length > 0);
}

async function openInZed(files: string[]): Promise<void> {
  if (files.length === 0) return;

  // Open all selected files in Zed
  const args = files.map((f) => f.trim());
  spawnSync(["zed", ...args]);
}

async function showInFzf(files: string[]): Promise<string[]> {
  if (files.length === 0) return [];

  const fzfArgs = [
    "--multi",
    "--ansi",
    "--preview",
    "bat --style=numbers --color=always --line-range=:500 {} 2>/dev/null || cat {}",
    "--preview-window",
    "right:50%:wrap",
    "--bind",
    "ctrl-y:execute-silent(echo -n {} | pbcopy)+abort",
    "--bind",
    "ctrl-o:execute-silent(open -R {})+abort",
    "--header",
    "🎯 AI-ranked results | Enter: Zed | Tab: multi | ctrl-y: copy",
  ];

  const input = files.join("\n");
  const proc = spawn(["fzf", ...fzfArgs], {
    stdout: "pipe",
    stderr: "inherit",
    stdin: "pipe",
  });

  proc.stdin.write(input);
  proc.stdin.end();

  const output = await new Response(proc.stdout).text();
  await proc.exited;

  return output.trim().split("\n").filter((l) => l.length > 0);
}

async function main() {
  const args = process.argv.slice(2);
  const listOnly = args.includes("--list") || args.includes("-l");
  const fastMode = args.includes("--fast") || args.includes("-f");
  const query = args.filter((a) => !a.startsWith("-")).join(" ");

  if (!query) {
    console.error("Usage: smart-find [options] <query>");
    console.error("Options:");
    console.error("  --list, -l  Print results without fzf");
    console.error("  --fast, -f  Skip AI ranking (faster)");
    console.error("Examples:");
    console.error('  smart-find "*.ts"                    # instant glob');
    console.error('  smart-find "dropbox zoom workshop"   # AI parallel search');
    process.exit(1);
  }

  // Check for instant pattern
  const instantCmd = detectInstantPattern(query);

  let results: string[];

  if (instantCmd) {
    // Instant mode - no AI needed
    console.error(`⚡ Instant: ${instantCmd.join(" ")}`);
    const proc = spawn(instantCmd, { stdout: "pipe", stderr: "pipe" });
    const output = await new Response(proc.stdout).text();
    await proc.exited;
    results = output.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
  } else if (fastMode) {
    // Fast mode - only programmatic search
    results = await programmaticSearch(query);
  } else {
    // Full AI mode - parallel natural + programmatic
    console.error(`🤖 AI search: "${query}"`);
    console.error("");

    // Run both searches in parallel
    const [natural, programmatic] = await Promise.all([
      naturalSearch(query),
      programmaticSearch(query),
    ]);

    console.error(`   Natural found: ${natural.length} files`);
    console.error(`   Programmatic found: ${programmatic.length} files`);

    // Merge and rank
    results = await mergeAndRank(query, natural, programmatic);
    console.error(`   Final ranked: ${results.length} files`);
    console.error("");
  }

  if (results.length === 0) {
    console.error("No files found");
    process.exit(0);
  }

  if (listOnly) {
    for (const f of results) console.log(f);
  } else {
    const selected = await showInFzf(results);
    await openInZed(selected);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
