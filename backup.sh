#!/bin/bash

# =============================================================================
# 1. Constants
# =============================================================================
DEST_DIR="."
CURRENT_DATE=$(date +"%d-%m-%Y")
CURRENT_TIME=$(date +"%H-%M-%S")
HYPRLAND_SOURCE="$HOME/.config/hypr/hyprland.conf"
NIRI_SOURCE="$HOME/.config/niri"
MAX_BACKUPS=4

# =============================================================================
# 2. Config Detection
# =============================================================================
check_hyprland() {
    [ -f "$HYPRLAND_SOURCE" ]
}

check_niri() {
    [ -d "$NIRI_SOURCE" ]
}

# =============================================================================
# 3. prune_to_latest(pattern, n)
# =============================================================================
# Prune backups to keep only N newest (by mtime)
prune_to_latest() {
    local type="$1"
    local keep="$2"
    local paths
    mapfile -t paths < <(get_backup_list "$type")
    local count=${#paths[@]}
    local to_remove=$((count - keep))
    if [ "$to_remove" -le 0 ]; then
        return 0
    fi
    local i
    for ((i = keep; i < count; i++)); do
        local p="${paths[$i]}"
        [ -n "$p" ] || continue
        if [ -d "$p" ]; then
            rm -rf "$p"
        else
            rm -f "$p"
        fi
    done
}

# Count backups matching pattern (supports multi-pattern for niri: tar.gz, zip, folder)
count_backups() {
    local type="$1"
    if [ "$type" = "hyprland" ]; then
        find "$DEST_DIR" -maxdepth 1 -name "hyprland_*_backup_*.conf" -type f 2>/dev/null | wc -l
    else
        find "$DEST_DIR" -maxdepth 1 \( -name "niri_*_backup_*.tar.gz" -o -name "niri_*_backup_*.zip" -o \( -name "niri_*_backup_*" -type d \) \) 2>/dev/null | wc -l
    fi
}

# Get list of backups sorted by mtime (newest first)
get_backup_list() {
    local type="$1"
    if [ "$type" = "hyprland" ]; then
        find "$DEST_DIR" -maxdepth 1 -name "hyprland_*_backup_*.conf" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-
    else
        find "$DEST_DIR" -maxdepth 1 \( -name "niri_*_backup_*.tar.gz" -o -name "niri_*_backup_*.zip" -o \( -name "niri_*_backup_*" -type d \) \) -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-
    fi
}

# =============================================================================
# 4 & 6. retention_prompt and manage_backups_menu
# =============================================================================
manage_backups_menu() {
    local type="$1"       # "hyprland" or "niri"
    local require_prune="$2"

    while true; do
        local count
        count=$(count_backups "$type")
        [ -z "$count" ] && count=0

        if [ "$require_prune" = "true" ] && [ "$count" -le "$MAX_BACKUPS" ]; then
            # User has reduced to <= 4, can return
            return 0
        fi

        local files
        mapfile -t files < <(get_backup_list "$type")

        if [ ${#files[@]} -eq 0 ]; then
            if command -v dialog &>/dev/null; then
                dialog --msgbox "No ${type} backups found." 6 40
            else
                echo "No ${type} backups found."
            fi
            return 0
        fi

        # Build dialog menu: tag item tag item ...
        local menu_items=()
        for f in "${files[@]}"; do
            local basename="${f##*/}"
            menu_items+=("$basename" "$f")
        done

        if [ "$require_prune" = "true" ]; then
            local msg="You have $count backups (max $MAX_BACKUPS). Select one to remove:"
        else
            local msg="Select a backup to remove, or Cancel to go back:"
        fi

        local choice
        if command -v dialog &>/dev/null; then
            choice=$(dialog --stdout --title "Manage ${type^} Backups" \
                --menu "$msg" $((15 + ${#files[@]})) 60 10 "${menu_items[@]}" 2>/dev/null)
        else
            echo "$msg"
            PS3="Enter number (or 0 to go back): "
            select choice in "${files[@]}"; do
                if [ "$REPLY" = "0" ] || [ -z "$REPLY" ]; then
                    [ "$require_prune" != "true" ] && return 0
                    echo "You must reduce to $MAX_BACKUPS or fewer backups before continuing."
                elif [ -n "$choice" ]; then
                    break
                fi
            done
        fi

        if [ -z "$choice" ]; then
            if [ "$require_prune" = "true" ]; then
                if command -v dialog &>/dev/null; then
                    dialog --msgbox "You must reduce to $MAX_BACKUPS or fewer backups before continuing." 6 50
                else
                    echo "You must reduce to $MAX_BACKUPS or fewer backups before continuing."
                fi
                continue
            else
                return 0
            fi
        fi

        local to_remove="$choice"
        if [[ "$choice" != /* ]] && [[ "$choice" != ./* ]]; then
            to_remove="${DEST_DIR%/}/$choice"
        fi

        local confirmed
        if command -v dialog &>/dev/null; then
            dialog --yesno "Delete this backup?\n$to_remove" 8 60 && confirmed=1
        else
            read -p "Delete $to_remove? [y/N] " -n 1 -r
            echo
            [[ $REPLY =~ ^[Yy]$ ]] && confirmed=1
        fi

        if [ -n "$confirmed" ]; then
            if [ -d "$to_remove" ]; then
                rm -rf "$to_remove"
            elif [ -f "$to_remove" ]; then
                rm -f "$to_remove"
            fi
        fi
    done
}

retention_prompt() {
    local type="$1"

    local count
    count=$(count_backups "$type")
    [ -z "$count" ] && count=0

    if [ "$count" -le "$MAX_BACKUPS" ]; then
        return 0
    fi

    local choice
    if command -v dialog &>/dev/null; then
        choice=$(dialog --stdout --title "Too many backups" \
            --menu "You have $count ${type} backups (max $MAX_BACKUPS). What would you like to do?" 12 50 2 \
            "prune" "Prune to 4 latest" \
            "manage" "Manage Backups (remove manually)" 2>/dev/null)
    else
        echo "You have $count ${type} backups (max $MAX_BACKUPS)."
        echo "1) Prune to 4 latest"
        echo "2) Manage Backups (remove manually)"
        read -p "Choice [1]: " input || input=""
        case "${input:-1}" in
            1) choice="prune" ;;
            2) choice="manage" ;;
            *) choice="prune" ;;
        esac
    fi

    case "$choice" in
        prune)
            prune_to_latest "$type" "$MAX_BACKUPS"
            ;;
        manage)
            manage_backups_menu "$type" "true"
            ;;
    esac
}

# =============================================================================
# 5. do_backup_hyprland, do_backup_niri
# =============================================================================
do_backup_hyprland() {
    local dest_file="${DEST_DIR}/hyprland_${CURRENT_DATE}_backup_${CURRENT_TIME}.conf"
    if cp "$HYPRLAND_SOURCE" "$dest_file"; then
        if command -v dialog &>/dev/null; then
            dialog --msgbox "Backup created:\n$dest_file" 6 50
        else
            echo "Success: Backup created at $dest_file"
        fi
        retention_prompt "hyprland"
    else
        if command -v dialog &>/dev/null; then
            dialog --msgbox "Error: Failed to copy file." 5 40
        else
            echo "Error: Failed to copy file."
        fi
        return 1
    fi
}

do_backup_niri() {
    local base_name="niri_${CURRENT_DATE}_backup_${CURRENT_TIME}"
    local format=""
    if command -v dialog &>/dev/null; then
        format=$(dialog --stdout --title "Niri backup format" \
            --menu "Choose backup format:" 11 45 3 \
            "tar.gz" "Compressed tarball (recommended)" \
            "zip" "ZIP archive (portable)" \
            "folder" "Plain folder copy (easy to browse)" 2>/dev/null)
    else
        echo "Niri backup format:"
        echo "1) tar.gz - Compressed tarball (recommended)"
        echo "2) zip - ZIP archive (portable)"
        echo "3) folder - Plain folder copy (easy to browse)"
        local input
        read -p "Choice [1]: " input || input=""
        case "${input:-1}" in
            1) format="tar.gz" ;;
            2) format="zip" ;;
            3) format="folder" ;;
            *) format="tar.gz" ;;
        esac
    fi

    [ -z "$format" ] && return 0

    local dest_path="${DEST_DIR}/${base_name}"
    local success=0

    case "$format" in
        tar.gz)
            dest_path="${dest_path}.tar.gz"
            if tar -czf "$dest_path" -C "$HOME/.config" niri 2>/dev/null; then
                success=1
            fi
            ;;
        zip)
            dest_path="${dest_path}.zip"
            if command -v zip &>/dev/null; then
                local abs_dest
                abs_dest="$(cd -P "$DEST_DIR" 2>/dev/null && pwd)/${base_name}.zip"
                (cd "$HOME/.config" && zip -rq "$abs_dest" niri) 2>/dev/null && success=1
            else
                if command -v dialog &>/dev/null; then
                    dialog --msgbox "zip is not installed. Run: pacman -S zip" 6 50
                else
                    echo "Error: zip is not installed. Run: pacman -S zip"
                fi
                return 1
            fi
            ;;
        folder)
            if cp -r "$NIRI_SOURCE" "$dest_path" 2>/dev/null; then
                success=1
            fi
            ;;
        *)
            return 1
            ;;
    esac

    if [ "$success" -eq 1 ]; then
        if command -v dialog &>/dev/null; then
            dialog --msgbox "Backup created:\n$dest_path" 6 50
        else
            echo "Success: Backup created at $dest_path"
        fi
        retention_prompt "niri"
    else
        if command -v dialog &>/dev/null; then
            dialog --msgbox "Error: Failed to create backup." 5 40
        else
            echo "Error: Failed to create backup."
        fi
        return 1
    fi
}

# =============================================================================
# 7. main_menu
# =============================================================================
main_menu() {
    while true; do
        local items=()
        [ "$HAS_HYPRLAND" = "1" ] && items+=("hyprland" "Backup Hyprland")
        [ "$HAS_NIRI" = "1" ] && items+=("niri" "Backup Niri")
        items+=("manage" "Manage Backups")
        items+=("exit" "Exit")

        if [ ${#items[@]} -eq 2 ]; then
            # Only manage + exit
            items=("manage" "Manage Backups" "exit" "Exit")
        fi

        local choice=""
        if command -v dialog &>/dev/null; then
            choice=$(dialog --stdout --title "Config Backup" \
                --menu "Choose an option:" 12 40 6 "${items[@]}" 2>/dev/null)
        else
            echo "=== Config Backup ==="
            echo "Choose an option:"
            local i=1
            for ((j=0; j<${#items[@]}; j+=2)); do
                echo "  $i) ${items[j+1]}"
                ((i++))
            done
            local input
            read -p "Choice: " input || input=""
            local idx=$(( (input - 1) * 2 ))
            if [ "$idx" -ge 0 ] 2>/dev/null && [ -n "$input" ]; then
                choice="${items[$idx]}"
            fi
        fi

        [ -z "$choice" ] && exit 0

        case "$choice" in
            hyprland)
                do_backup_hyprland
                ;;
            niri)
                do_backup_niri
                ;;
            manage)
                if [ "$HAS_HYPRLAND" = "1" ] && [ "$HAS_NIRI" = "1" ]; then
                    local subchoice
                    if command -v dialog &>/dev/null; then
                        subchoice=$(dialog --stdout --title "Manage Backups" \
                            --menu "Which type?" 10 40 2 \
                            "hyprland" "Hyprland backups" \
                            "niri" "Niri backups" 2>/dev/null)
                    else
                        echo "1) Hyprland 2) Niri"
                        read -p "Choice: " input
                        [ "$input" = "1" ] && subchoice="hyprland"
                        [ "$input" = "2" ] && subchoice="niri"
                    fi
                    [ -n "$subchoice" ] && manage_backups_menu "$subchoice" "false"
                elif [ "$HAS_HYPRLAND" = "1" ]; then
                    manage_backups_menu "hyprland" "false"
                elif [ "$HAS_NIRI" = "1" ]; then
                    manage_backups_menu "niri" "false"
                else
                    if command -v dialog &>/dev/null; then
                        dialog --msgbox "No backups to manage." 5 40
                    else
                        echo "No backups to manage."
                    fi
                fi
                ;;
            exit)
                exit 0
                ;;
        esac
    done
}

# =============================================================================
# 8. Entry point
# =============================================================================
HAS_HYPRLAND=0
HAS_NIRI=0
check_hyprland && HAS_HYPRLAND=1
check_niri && HAS_NIRI=1

if [ "$HAS_HYPRLAND" -eq 0 ] && [ "$HAS_NIRI" -eq 0 ]; then
    if command -v dialog &>/dev/null; then
        dialog --msgbox "No Hyprland or Niri configs detected." 6 50
    else
        echo "Error: No Hyprland or Niri configs detected."
    fi
    exit 1
fi

main_menu
