
# My Ultimate Karabiner Setup: A Deep Dive into Keyboard Customization

*How I transformed my keyboard into a hyper-productive command center using Karabiner-Elements and Goku*

After years of tweaking and refining, my Karabiner configuration has evolved into something of a keyboard symphony—a 1,000+ line EDN file that transforms every keystroke into precisely what I need, when I need it. This isn't just key remapping; it's a complete reimagining of how I interact with my Mac.

## The Philosophy: Context-Aware Computing

My Karabiner setup is built around a core philosophy: **every key should do more than one thing, and what it does should depend entirely on context**. Context includes:

- Which application is active
- How many fingers are on my trackpad
- Whether I'm holding other keys
- Which mouse buttons I'm pressing
- Whether I'm using my Colemak layout or not

This creates a layered, modal interaction system that feels natural once learned, but provides exponentially more functionality than a standard keyboard.

## The Foundation: Goku and EDN

Rather than editing Karabiner's JSON directly (which would be madness at this scale), I use [Goku](https://github.com/yqrashawn/GokuRakuJoudo) to write my configuration in EDN format. This allows for:

- **Readable aliases** instead of cryptic key codes
- **Template system** for reusable shell commands
- **Logical organization** of complex rules
- **Comments and documentation** inline

```clojure
;; Example of the readability difference
:modifiers {:hyper [:command :shift :control :option]
            :cos   [:command :shift :option]}
```

## The Architecture: Five Pillars

### 1. Application-Specific Behaviors

Each application gets its own behavior profile. For example:

**Chrome**: Left Cmd tap opens a new tab, hold for normal Cmd functionality
```clojure
[:chrome
 [:left_command :left_command nil {:alone [:!Ct]}]]
```

**VS Code/Cursor**: Left Cmd tap triggers \"Go to File\" (Cmd+P)
```clojure
[:code
 [:left_command :left_command nil {:alone :go_to_file}]]
```

**Ableton Live**: Complex track creation and navigation shortcuts that map to my musical workflow

### 2. Trackpad Integration: The Game Changer

This is where things get interesting. My setup detects how many fingers are touching the trackpad and completely changes keyboard behavior accordingly:

**1 Finger on Trackpad** = Selection/Navigation Mode:
- `T` becomes left-click
- `S` becomes right-click  
- `D` becomes shift-click
- Arrow keys work normally

**2 Fingers on Trackpad** = Enhanced Selection Mode:
- `X` becomes shift-click then Cmd+X
- `C` becomes click then Cmd+C
- More precise selection tools

**3 Fingers on Trackpad** = Media/Screenshot Mode:
- `S` captures screenshots
- `R` starts screen recording

This creates natural gesture-keyboard combinations that feel intuitive once learned.

### 3. Simlayers: Chord-Based Superpowers

Simlayers activate when I press two keys simultaneously, creating hundreds of additional shortcuts:

**Q + Key** = Quick utilities (reload config, timestamp)
**E + Key** = File/folder opening (\"Finder mode\")
**F + Key** = Movement layer (arrow keys on home row)
**J + Key** = Deletion layer (various delete operations)
**Space + Key** = Symbol layer (brackets, parentheses, etc.)

Each simlayer is mnemonically organized—`E` for \"Explorer\" gives me file operations, `F` for movement gives me arrows, etc.

### 4. Window Management Integration

My setup integrates deeply with [Yabai](https://github.com/koekeishiya/yabai) for window management. I can:

- Move windows between displays with `Equal + Click`
- Resize windows by tenths with `Equal + Y/U` 
- Navigate spaces with mouse buttons
- Create and destroy spaces dynamically

```clojure
:equal-mode
[:-j [:window_resize_to_next_tenth_wider]]
[:-y [:window_resize_to_next_tenth_narrower]]
[:-h [:space_left]]
[:-i [:space_right]]
```

### 5. The Colemak Layer

Since I use Colemak layout, my entire configuration includes a full QWERTY→Colemak remapping at the bottom. But more importantly, all my mnemonics are designed around Colemak letter positions, making the shortcuts more intuitive for my muscle memory.

## Power User Features

### Script Templates
I've defined templates for common shell operations:
```clojure
:templates {
  :launch \"/bin/bash /Users/johnlindquist/.config/scripts/launch_focus_app.sh \\\"%s\\\"\"
  :focus-or-open-chrome \"/usr/bin/osascript /Users/johnlindquist/.config/focus-tab.scpt \\\"%s\\\"\"
  :paste \"osascript -e 'set the clipboard to \\\"%s\\\"...'\"
}
```

### URL Quick Access
Period + Key opens specific websites in existing tabs or creates new ones:
- `.+C` → ChatGPT
- `.+G` → Google Gemini  
- `.+P` → Perplexity
- `.+Y` → YouTube

### Development Shortcuts
Semicolon mode types special characters using positional mnemonics:
- `;+E` → `!` (Exclamation)
- `;+A` → `@` (At symbol)
- `;+H` → `#` (Hash)

## The Learning Curve Reality

I won't lie—this setup has a steep learning curve. But here's the thing: you don't implement it all at once. I built this over years, adding one layer at a time. Each addition felt natural because it solved a specific pain point in my workflow.

Start small:
1. Begin with basic app-specific behaviors
2. Add one simlayer (I recommend Space for symbols)
3. Gradually add trackpad integration
4. Build out your most-used applications

## The Payoff

After living with this setup for years, I can't imagine working any other way. My keyboard has become an extension of my thoughts. Want to:

- Open my `.config` folder in Cursor? `; + K`
- Create a new MIDI track in Ableton? Touch trackpad + `T`
- Move current window to next display? `= + Click`
- Insert `console.log()` with cursor positioned? `' + C`

Everything is one or two keystrokes away, and because it's contextual, the same keys do different logical things in different situations.

## Key Takeaways

1. **Start Simple**: Don't try to implement everything at once
2. **Use Mnemonics**: Make shortcuts memorable (E for Explorer, F for Movement)
3. **Embrace Context**: Same keys, different meanings in different apps
4. **Document Everything**: Future you will thank present you
5. **Iterate Constantly**: This config evolved over years of daily use

## The Code

You can find my complete configuration in my [dotfiles repo](https://github.com/johnlindquist/dotfiles). The `karabiner.edn` file is extensively commented and organized for readability.

Remember: the best keyboard setup is the one you'll actually use. Start with solving your most frequent pain points, and build from there. Your future self will thank you for every keystroke saved.

---

*This post represents years of iteration and refinement. Your mileage may vary, but the principles of contextual, layered keyboard interaction can transform any workflow. The key is starting simple and building gradually.*

