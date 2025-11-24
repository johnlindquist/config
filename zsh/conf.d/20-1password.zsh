# =============================================================================
# 1Password Integration
# =============================================================================
# Centralized API key management with session caching.
#
# Usage:
#   opkey "Item Name"              # Get credential field
#   opkey "Item Name" password     # Get specific field
#   with GEMINI_API_KEY command    # Run command with key exported
#   opkey-clear                    # Clear session cache
#   oplist                         # List available items
#
# Customization:
#   Override OP_KEYS in local.zsh to use your own 1Password item names:
#   OP_KEYS[GEMINI_API_KEY]="My Gemini Key:credential"
# =============================================================================

# Session cache (avoids repeated biometric prompts)
declare -A _OP_CACHE

# Core fetcher with caching
opkey() {
  local item="$1" field="${2:-credential}"
  local cache_key="${item}:${field}"

  if [[ -z "${_OP_CACHE[$cache_key]}" ]]; then
    local val
    val=$(op item get "$item" --fields "$field" --reveal 2>/dev/null | tr -d '\n')
    [[ -z "$val" ]] && { echo "No key: $item" >&2; return 1; }
    _OP_CACHE[$cache_key]="$val"
  fi
  echo "${_OP_CACHE[$cache_key]}"
}

# Clear cache (after rotating keys)
opkey-clear() { _OP_CACHE=(); echo "Key cache cleared"; }

# List available items
oplist() {
  op item list --format json 2>/dev/null | jq -r '.[] | "\(.title) (\(.category))"' | sort
}

# Key registry - override in local.zsh with your item names
# Format: [ENV_VAR_NAME]="1Password Item Name:field"
typeset -A OP_KEYS
OP_KEYS+=(
  [GEMINI_API_KEY]="${OP_GEMINI_ITEM:-GEMINI_API_KEY}:credential"
  [GEMINI_API_KEY_FREE]="${OP_GEMINI_FREE_ITEM:-GEMINI_API_KEY_FREE}:credential"
  [OPENAI_API_KEY]="${OP_OPENAI_ITEM:-OPENAI_API_KEY}:credential"
  [GITHUB_API_KEY]="${OP_GITHUB_ITEM:-Github CLI Token}:password"
  [ANTHROPIC_API_KEY]="${OP_ANTHROPIC_ITEM:-ANTHROPIC_API_KEY}:credential"
  [GROQ_API_KEY]="${OP_GROQ_ITEM:-GROQ_API_KEY}:credential"
  [ZAI_API_KEY]="${OP_ZAI_ITEM:-ZAI_API_KEY}:credential"
  [OPENROUTER_KIMI_API_KEY]="${OP_KIMI_ITEM:-OPENROUTER_KIMI_API_KEY}:credential"
)

# Generic wrapper: `with KEY_NAME command args...`
with() {
  local key_name="$1"; shift
  local mapping="${OP_KEYS[$key_name]}"
  [[ -z "$mapping" ]] && { echo "Unknown key: $key_name (add to OP_KEYS in local.zsh)" >&2; return 1; }

  local item="${mapping%%:*}" field="${mapping#*:}"
  local key_val
  key_val=$(opkey "$item" "$field") || return 1
  export "$key_name"="$key_val"
  "$@"
}

# Convenience wrappers
with_gemini()      { GEMINI_API_KEY=$(opkey "${OP_GEMINI_ITEM:-GEMINI_API_KEY}") "$@"; }
with_free_gemini() { GEMINI_API_KEY=$(opkey "${OP_GEMINI_FREE_ITEM:-GEMINI_API_KEY_FREE}") "$@"; }
with_openai()      { OPENAI_API_KEY=$(opkey "${OP_OPENAI_ITEM:-OPENAI_API_KEY}") "$@"; }
with_github()      { GITHUB_API_KEY=$(opkey "${OP_GITHUB_ITEM:-Github CLI Token}" password) "$@"; }

# Create new credential
create_cred() {
  local title="$1" credential="$2"
  [[ -z "$title" || -z "$credential" ]] && { echo "Usage: create_cred <title> <credential>"; return 1; }
  op item create --category "API Credential" --title "$title" credential="$credential"
}
