# Arch Config Backup

Backup Hyprland and Niri configs from your Arch Linux system. TUI for choosing what to save,
with retention control and multiple output formats.

## Description

A lightweight bash script that detects your Hyprland and/or Niri configs and backs them up
with an interactive menu. Supports timestamped (unique) or stable (overwrite) naming, keeps
up to 4 latest backups per type, and offers tar.gz, zip, or plain folder for Niri.

**Who it's for:** Arch users running Hyprland or Niri who want versioned config backups.

## Installation

Clone the repo and run the script. No extra packages required.

```bash
git clone https://github.com/martinvalentine/arch-config-backup.git
cd arch-config-backup
```

**Optional** – For a nicer TUI, install `dialog`:

```bash
sudo pacman -S dialog
```

Without `dialog`, the script falls back to a simple text menu.

## Usage

Run from the repo directory:

```bash
bash backup.sh
```

The script will:

1. Detect which configs exist (`~/.config/hypr/hyprland.conf`, `~/.config/niri`)
2. Show a menu: Backup Hyprland, Backup Niri, Manage Backups, or Exit
3. Ask for naming (timestamped vs stable) and, for Niri, format (tar.gz/zip/folder)
4. Create the backup in the current directory

**Example flow:**

```bash
$ bash backup.sh
=== Config Backup ===
Choose an option:
  1) Backup Hyprland
  2) Backup Niri
  3) Manage Backups
  4) Exit
Choice: 1
Save as:
1) Timestamped - unique file each time
2) Stable - fixed name, overwrites previous
Choice [1]: 1
Success: Backup created at ./hyprland_01-03-2026_backup_12-00-00.conf
```

## Features

- **Config detection** – Only shows options for configs that exist
- **Hyprland** – Backs up `hyprland.conf` (single file)
- **Niri** – Backs up the full `~/.config/niri` folder (tar.gz, zip, or plain copy)
- **Naming** – Timestamped (unique per run) or stable (fixed filename, overwrites)
- **Retention** – Keeps up to 4 latest backups; prompts to prune or manage when over limit
- **Overwrite confirmation** – Asks before overwriting existing stable backups
- **Manage Backups** – Delete individual backups via menu

## Tech Stack

- Bash
- `dialog` (optional, for TUI)
- `zip` (optional, for Niri zip format)
- `tar`, `find` (standard on Arch)

## Contributing

Pull requests are welcome. For larger changes, open an issue first to discuss.

## License

MIT License. See `LICENSE` file for details.
