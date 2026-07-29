# Hover

An inline AI look-up for macOS, in the spirit of the built-in Dictionary
popover (⌃⌘D) but answered by Claude. Select any word, name, code snippet, or
error message in any app and press **⇧⌘C**. A Liquid Glass popover appears at
your cursor with a short explanation. Ask follow-ups inline, then press Esc
when you're done. It never steals focus from the app you're in.

## Features

- **Works everywhere.** Reads the selection via the Accessibility API, with a
  clipboard-preserving ⌘C fallback for apps with poor AX support (GPU-rendered
  terminals, some Electron apps).
- **Stays out of your way.** A non-activating panel at your cursor; the host
  app keeps working underneath. Close it with Esc, the ✕ ESC button, or ⇧⌘C.
  Drag the glass to reposition it.
- **Inline follow-up chat.** Type in the glass capsule below the answer to
  continue the conversation without leaving the popover.
- **Streaming answers.** Tokens render as they arrive; the panel grows with
  the content, then scrolls.
- **AI-generated titles.** Long selections get a short generated header
  instead of a wall of text.
- **Native UI.** SwiftUI with macOS 26 Liquid Glass (`glassEffect` and
  `GlassEffectContainer`), falling back to the classic popover material on
  older systems.

## Build & install

Requires Xcode command line tools with the macOS 26 SDK.

```sh
./build-app.sh --install
open /Applications/Hover.app
```

Hover is a menu bar app (no Dock icon).

## Setup (one time)

1. **API key**: menu bar icon → *Set Claude API Key…* (stored in your login
   keychain). An `ANTHROPIC_API_KEY` environment variable takes precedence.
2. **Accessibility**: allow Hover under *System Settings → Privacy &
   Security → Accessibility*, then relaunch. Required to read the selection.

> `build-app.sh` signs with your Apple Development certificate when one is
> available (falling back to ad-hoc). A stable signing identity is what makes
> the Accessibility grant survive rebuilds; with ad-hoc signing you'll need
> to re-grant after each build.

## Configuration

Everything is code, in small single-purpose files:

| What | Where |
|---|---|
| Model, system prompt, effort | `Sources/Hover/ClaudeClient.swift` |
| Hotkey (default ⇧⌘C) | `Sources/Hover/AppDelegate.swift` |
| Panel size, positioning, dismissal | `Sources/Hover/LookupPanel.swift` |
| Popover UI / glass styling | `Sources/Hover/LookupView.swift` |

Uses `claude-opus-5` with streaming and low effort for fast inline answers.

## Privacy

Selected text is sent to the Anthropic API only when you press the hotkey.
Nothing else is captured, stored, or logged; the API key lives in your
keychain.

## License

MIT. See [LICENSE](LICENSE).
