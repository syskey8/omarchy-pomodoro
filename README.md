# Omarchy Pomodoro Plugin

A native, first-class Pomodoro focus timer for the Omarchy top bar. 

Built entirely with standard Omarchy `qs.Ui` components and Quickshell, this plugin perfectly matches your system theme, typography, and colors out of the box.

## Features
- **Standard Pomodoro Flow:** Automatically handles 25m focus sessions, 5m short breaks, and 15m long breaks (after 4 sessions).
- **Custom Timer:** A built-in NumberField to spin up a custom timer for any duration.
- **Native UI:** Beautiful dropdown panel with live countdown, progress bar, and mode selection.
- **Alerts:** Triggers desktop notifications and the system alarm sound (`pw-play`) when a phase completes.
- **Settings GUI Integration:** Change your default durations directly in the Omarchy Settings app.

## Installation

Install the plugin directly from GitHub using the Omarchy CLI:

```bash
omarchy plugin add https://github.com/syskey8/omarchy-pomodoro
```

Then, enable it and place it on the right side of your bar:

```bash
omarchy plugin enable pomodoro right
```

## Shortcuts (When panel is open)
- `S` or `Space` or `Enter` — Start / Pause
- `N` — Skip to the next phase
- `R` — Reset timer
- **Right-Click** the bar icon to Start/Pause without opening the panel.

## License
MIT
