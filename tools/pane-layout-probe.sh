#!/bin/bash
#
# pane-layout-probe.sh — drive tfx's pane visibility from the shell
# and read back the resulting layout state, so changes can be
# verified without manual UI interaction.
#
# Strategy: `@AppStorage` flags are backed by `UserDefaults`, and
# SwiftUI's `@AppStorage` observes the same `UserDefaults` key. So
# `defaults write <bundle> <key> -bool <value>` from another process
# is picked up by tfx via `UserDefaults.didChangeNotification` and
# fires the same `.onChange` handlers as a UI toggle. This avoids the
# Accessibility-permission requirement that `osascript` keystrokes
# need.
#
# Window-resize scenarios still require Accessibility, so they are
# split out into `scenario_resize` (skipped by default).
#
# Usage:
#   tools/pane-layout-probe.sh              # full toggle suite
#   tools/pane-layout-probe.sh reset        # reset defaults + relaunch
#   tools/pane-layout-probe.sh state        # print state snapshot
#   tools/pane-layout-probe.sh preview      # toggle preview off/on
#   tools/pane-layout-probe.sh folder       # toggle folder off/on
#   tools/pane-layout-probe.sh split        # toggle split on/off
#   tools/pane-layout-probe.sh resize       # window resize (needs Accessibility)
#   tools/pane-layout-probe.sh logs N       # tail N lines of pane log

set -u

BUNDLE_ID="org.spumoni.tfx"
SCHEME="tfx"
LOG_PATH="/tmp/tfx-pane-layout.log"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
NC='\033[0m'

# Defaults keys
KEY_FOLDER_W="TerminalFileManager.folderTreeWidth"
KEY_PREVIEW_W="TerminalFileManager.previewWidth"
KEY_FOLDER_V="TerminalFileManager.isFolderTreeVisible"
KEY_PREVIEW_V="TerminalFileManager.isPreviewVisible"
KEY_SPLIT_V="TerminalFileManager.isSplitViewVisible"

# --- helpers ---------------------------------------------------------

quit_tfx() {
    osascript -e 'tell application "tfx" to quit' >/dev/null 2>&1 || true
    sleep 0.5
    pkill -x tfx 2>/dev/null || true
    sleep 0.3
}

reset_defaults() {
    defaults delete "$BUNDLE_ID" "$KEY_FOLDER_W" 2>/dev/null || true
    defaults delete "$BUNDLE_ID" "$KEY_PREVIEW_W" 2>/dev/null || true
    defaults delete "$BUNDLE_ID" "$KEY_FOLDER_V" 2>/dev/null || true
    defaults delete "$BUNDLE_ID" "$KEY_PREVIEW_V" 2>/dev/null || true
    defaults delete "$BUNDLE_ID" "$KEY_SPLIT_V" 2>/dev/null || true
}

build_app() {
    xcodebuild -scheme "$SCHEME" -configuration Debug \
        -destination 'platform=macOS' build 2>&1 \
        | grep -E "error:|BUILD" | tail -3
}

derived_app_path() {
    xcodebuild -scheme "$SCHEME" -configuration Debug \
        -destination 'platform=macOS' -showBuildSettings 2>/dev/null \
        | awk -F'= ' '/BUILT_PRODUCTS_DIR/ {print $2; exit}' \
        | xargs -I{} echo "{}/tfx.app"
}

launch_app() {
    local app
    app="$(derived_app_path)"
    rm -f "$LOG_PATH"
    TFX_PANE_LAYOUT_LOGS=1 "$app/Contents/MacOS/tfx" >"$LOG_PATH" 2>&1 &
    sleep 2
}

# Read a Bool default, defaulting to a fallback string when absent
read_bool_default() {
    local key="$1"
    local fallback="$2"
    local value
    value=$(defaults read "$BUNDLE_ID" "$key" 2>/dev/null) || value="$fallback"
    echo "$value"
}

read_num_default() {
    local key="$1"
    local fallback="$2"
    local value
    value=$(defaults read "$BUNDLE_ID" "$key" 2>/dev/null) || value="$fallback"
    echo "$value"
}

# Toggle a Bool default and wait for the app to react.
#
# IMPORTANT: SwiftUI's `@AppStorage` does NOT reliably observe
# UserDefaults changes made by another process. So flipping a flag
# here doesn't actually move the running app's UI. To deterministically
# test the new state, this helper quits the app, writes the default,
# then re-launches — making the change visible at startup.
set_bool_default() {
    local key="$1"
    local value="$2"
    quit_tfx
    defaults write "$BUNDLE_ID" "$key" -bool "$value"
    launch_app
}

# Pull the most recent coordinator-reported pane widths from the log.
last_observed_widths() {
    local last
    last=$(grep "splitViewDidResizeSubviews: evaluating" "$LOG_PATH" 2>/dev/null | tail -1)
    if [[ -z "$last" ]]; then
        echo "  (no splitViewDidResizeSubviews line in log yet)"
        return
    fi
    # extract folder=X.X preview=Y.Y from line
    echo "  observed: $(echo "$last" | sed 's/.*content=//')"
}

# Most recent contentMinSize the coordinator wrote.
last_observed_min() {
    local last
    last=$(grep "wrote contentMinSize" "$LOG_PATH" 2>/dev/null | tail -1)
    if [[ -z "$last" ]]; then
        last=$(grep "applyContentMinSize" "$LOG_PATH" 2>/dev/null | tail -1)
    fi
    if [[ -z "$last" ]]; then
        echo "  (no applyContentMinSize line in log yet)"
        return
    fi
    echo "  $last"
}

print_state() {
    local label="${1:-state}"
    echo -e "${BOLD}=== $label ===${NC}"
    echo -e "${DIM}visibility (effective):${NC}"
    # Show 0/1 always; fall back to compile-time defaults
    # (folder=1, preview=1, split=0) when the key has never been
    # written. The coordinator's log lines below reflect what the
    # running app actually sees, so any mismatch is a sync bug.
    printf "  folder=%s  preview=%s  split=%s\n" \
        "$(read_bool_default "$KEY_FOLDER_V" "1")" \
        "$(read_bool_default "$KEY_PREVIEW_V" "1")" \
        "$(read_bool_default "$KEY_SPLIT_V" "0")"
    echo -e "${DIM}stored widths (effective):${NC}"
    # When the key isn't in UserDefaults yet, report the compile-
    # time defaults so the displayed value is always a usable
    # number, never a fallback string.
    printf "  folder=%s  preview=%s\n" \
        "$(read_num_default "$KEY_FOLDER_W" "200")" \
        "$(read_num_default "$KEY_PREVIEW_W" "320")"
    echo -e "${DIM}coordinator-observed last widths:${NC}"
    last_observed_widths
    echo -e "${DIM}coordinator-observed last contentMinSize:${NC}"
    last_observed_min
    echo ""
}

# --- scenarios -------------------------------------------------------

scenario_reset_and_launch() {
    quit_tfx
    reset_defaults
    launch_app
    print_state "initial (clean defaults)"
}

scenario_preview_toggle() {
    print_state "before preview toggle"
    echo -e "${GREEN}>> defaults write isPreviewVisible=false${NC}"
    set_bool_default "$KEY_PREVIEW_V" false
    print_state "after preview OFF"
    echo -e "${GREEN}>> defaults write isPreviewVisible=true${NC}"
    set_bool_default "$KEY_PREVIEW_V" true
    print_state "after preview ON"
}

scenario_folder_toggle() {
    print_state "before folder toggle"
    echo -e "${GREEN}>> defaults write isFolderTreeVisible=false${NC}"
    set_bool_default "$KEY_FOLDER_V" false
    print_state "after folder OFF"
    echo -e "${GREEN}>> defaults write isFolderTreeVisible=true${NC}"
    set_bool_default "$KEY_FOLDER_V" true
    print_state "after folder ON"
}

scenario_split_toggle() {
    print_state "before split toggle"
    echo -e "${GREEN}>> defaults write isSplitViewVisible=true${NC}"
    set_bool_default "$KEY_SPLIT_V" true
    print_state "after split ON"
    echo -e "${GREEN}>> defaults write isSplitViewVisible=false${NC}"
    set_bool_default "$KEY_SPLIT_V" false
    print_state "after split OFF"
}

# Requires Accessibility permission for osascript.
scenario_resize() {
    echo -e "${BOLD}(needs Accessibility permission for osascript)${NC}"
    print_state "before resize"
    for w in 900 700 500 1000; do
        echo -e "${GREEN}>> resize window to ${w}pt${NC}"
        osascript <<EOF >/dev/null 2>&1
tell application "System Events"
    tell process "tfx"
        set theWindow to first window
        set sz to size of theWindow
        set size of theWindow to {$w, item 2 of sz}
    end tell
end tell
EOF
        sleep 0.4
        print_state "after resize to $w"
    done
}

scenario_full() {
    scenario_reset_and_launch
    scenario_preview_toggle
    scenario_folder_toggle
    scenario_split_toggle
    echo -e "${BOLD}full coordinator log saved at:${NC} $LOG_PATH"
}

# --- main ------------------------------------------------------------

cd "$PROJECT_ROOT" || exit 1

case "${1:-full}" in
    reset)
        quit_tfx
        reset_defaults
        launch_app
        print_state "after reset + launch"
        ;;
    state)
        print_state "current"
        ;;
    build)
        build_app
        ;;
    relaunch)
        quit_tfx
        launch_app
        print_state "after relaunch (defaults preserved)"
        ;;
    preview)
        scenario_preview_toggle
        ;;
    folder)
        scenario_folder_toggle
        ;;
    split)
        scenario_split_toggle
        ;;
    resize)
        scenario_resize
        ;;
    full)
        scenario_full
        ;;
    logs)
        n="${2:-30}"
        tail -"$n" "$LOG_PATH"
        ;;
    help|-h|--help)
        sed -n '1,30p' "$0"
        ;;
    *)
        echo "unknown subcommand: $1"
        echo "see: $0 help"
        exit 1
        ;;
esac
