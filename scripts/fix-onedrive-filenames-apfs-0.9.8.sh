#!/bin/zsh

export PATH=/usr/bin:/bin:/usr/sbin:/sbin

########################################################################################################
#
# Jamf Self Service Script to check user's OneDrive folder for illegal characters,
# leading or trailing spaces and dots and corrects them to allow smooth synchronization.
#
# Modified by soundsnw with help from Claude Code, April 3, 2026
#
# Configuration is at the top of the script.
#
# Changelog
#
# April 3, 2026
# - Converted from bash to zsh
# - Made illegal character renaming optional via fix_illegal_chars flag
#   (OneDrive on Mac now syncs : \ ? * " < > | natively)
# - Added possibility to optionally rename files containing « » ` # , % using fix_extended_chars
# - Made backup optional via create_backup flag, set it to disabled by default
# - Each fix function logs how many items it renamed
# - Directory passes use find -depth for true depth-first traversal
# - Illegal character replacement consolidated into a single zsh character class substitution
# - Use zsh/files and zf_mv builtin for renaming (no fork per rename)
# - Allow ±5 file count difference before/after to tolerate transient OneDrive file provider activity during rename
# - A number of other improvements, bugfixes and some hardening
# - Tested with OneDrive 26.045.0308
#
# January 26, 2020
# - Fixed numerical conditionals in while loops and file number comparisons, corrected quoting.
#
# September 8, 2019
# - Treats directories first
# - If the corrected filename is used by another file, appends a number at the end to
#   avoid overwriting
# - Checks if the number of files before and after renaming is the same
# - Uses mktemp for temp files
# - Restarts OneDrive and cleans up temp files if aborted
# - Uses local and readonly variables where appropriate
#
# September 4, 2019
# - Changed backup parent directory to user folder to avoid potential problems
#   if Desktop sync is turned on
#
# September 3, 2019
# - The script is now much faster, while still logging and making a backup before changing filenames
# - Backup being made using APFS clonefile (support for HFS dropped)
# - Spotlight prevented from indexing backup to prevent users from opening the wrong file later
#
# September 2, 2019
# - Only does rename operations on relevant files, for increased speed and safety
# - Changed all exit status codes to 0, to keep things looking tidy in Self Service
# - No longer removes .fstemp files before doing rename operations
#
# Version: 0.9.8
#
# Script logs are placed in /var/log/onedrive-fixlogs
#
# Original script by dsavage:
# https://github.com/UoE-macOS/jss/blob/master/utilities-fix-file-names.sh
#
# Use of this script is entirely at your own risk, there is no warranty.
#
########################################################################################################

zmodload zsh/datetime
zmodload zsh/files
setopt PIPE_FAIL EXTENDED_GLOB

########################################################################################################
# Configuration
########################################################################################################

# Name of the OneDrive folder in the user's home directory
# Adjust with OneDrive folder name used in your organization
# Set to Library/CloudStorage/OneDrive-Personal for non-business users
onedrive_folder_name="OneDrive"

# Set to false to skip making an APFS clonefile backup before renaming.
# Skipping is faster but leaves no safety net if something goes wrong.
#
# As long as Files On-Demand is enabled, the OneDrive folder cannot be reliably backed up.
# OneDrive Files On-Demand is enabled by default and cannot be disabled since 2022.
# https://techcommunity.microsoft.com/blog/onedriveblog/inside-the-new-files-on-demand-experience-on-macos/3058922
# It is possible to mark the contents of a OneDrive folder as Always available using a script
# https://learn.microsoft.com/en-us/sharepoint/files-on-demand-mac
create_backup=false

# OneDrive on Mac now syncs files with : \ ? * " < > | natively (as of February 2025).
# Set to true if you still want these renamed — they sync fine on Mac, but display
# as HTML entities (e.g. &#x2a; for *) on Windows, iOS, Android, and web.
# https://techcommunity.microsoft.com/blog/onedriveblog/improved-filename-and-external-drive-support-for-onedrive-mac/4372026
fix_illegal_chars=false

# Set to true to also rename files containing « » ` # , %
# Microsoft lists these as problematic for OneDrive/SharePoint sharing.
# https://support.microsoft.com/office/f14307b4-e9ff-4cd9-be79-9524bb323744
fix_extended_chars=false

# Date format used in log filenames and backup folder names.
# Set to US for mm/dd/yy (month first), EU for dd/mm/yy (day first).
date_format="US"

# Set to false to run without Jamf. Messages will be printed to the terminal
# and written to the log instead of using jamf displayMessage.
use_jamf=true

# Character used to replace illegal or problematic characters in filenames (for example _ or -)
replacement_char="_"

########################################################################################################

finish() {
  trap - EXIT HUP INT QUIT TERM
  [[ -z "${tmp_dirnames-}" ]] || rm -f "$tmp_dirnames"
  [[ -z "${tmp_filenames-}" ]] || rm -f "$tmp_filenames"
  open "/Applications/OneDrive.app"
  pgrep -q caffeinate && killall caffeinate
  exit 0
}
trap finish EXIT HUP INT QUIT TERM

# Make sure the machine does not sleep until the script is finished
(caffeinate -sim -t 3600) &
disown

# Sets REPLY to the current date-time string in the configured format.
timestamp() {
  local fmt
  if [[ "$date_format" == US ]]; then
    fmt='%m%d%y-%H%M'
  else
    fmt='%d%m%y-%H%M'
  fi
  strftime -s REPLY "$fmt" $EPOCHSECONDS
}

log() {
  timestamp
  print "${REPLY}: $*" | /usr/bin/tee -a "$fixlog"
}

display_message() {
  if [[ "$use_jamf" == true ]]; then
    /usr/local/jamf/bin/jamf displayMessage -message "$1"
  else
    print "$1"
  fi
}

# Sets REPLY to a path guaranteed not to exist, appending -1, -2, etc. as needed.
unique_target() {
  local src="$1" base="$2" target="$2"
  local -i suffix=1

  if [[ "$src" != "$base" ]]; then
    while [[ -e "$target" ]]; do
      target="${base}-${suffix}"
      (( suffix++ ))
    done
  fi

  REPLY="$target"
}

# Sets REPLY to the fully normalized filename component passed in.
# All fixes applied in sequence so combined issues are resolved in one rename.
normalize_name() {
  local name="$1"

  # Optional: replace characters that are illegal on Windows / OneDrive web
  if [[ "$fix_illegal_chars" == true ]]; then
    name=${name//[:\\?*\"<>|]/$replacement_char}
  fi

  # Optional: replace additional characters listed as problematic by Microsoft
  if [[ "$fix_extended_chars" == true ]]; then
    name=${name//[«»\`#,%]/$replacement_char}
  fi

  # Remove leading spaces
  name="${name##[[:space:]]##}"

  # Remove two or more leading dots (single dot = normal hidden file)
  [[ "$name" == ..* ]] && name="${name##.##}"

  # Remove trailing spaces and dots
  name="${name%%([[:space:]]|.)##}"

  # If trimming/replacing produced an empty string, build a safe fallback
  # by collapsing spaces and dots to hyphens.
  if [[ -z "$name" ]]; then
    name="${1//[[:space:]]/-}"
    name="${name//./-}"
    [[ -z "$name" ]] && name="-"
  fi

  REPLY="$name"
}

# Read NUL-delimited paths from a temp file and rename any whose normalized form differs.
rename_from_file() {
  local label="$1" tmpfile="$2"
  local path name dir fixed target
  local -i renamed=0

  while IFS= read -r -d '' path; do
    [[ -z "$path" ]] && continue

    name="${path:t}"
    dir="${path:h}"

    normalize_name "$name"
    fixed="$REPLY"

    unique_target "$path" "$dir/$fixed"
    target="$REPLY"

    [[ "$path" == "$target" ]] && continue

    if zf_mv -f "$path" "$target" 2>>"$fixlog"; then
      print -r -- "$path -> $target" >> "$fixlog"
      (( renamed++ ))
    else
      log "Failed to rename: $path"
    fi
  done < "$tmpfile"

  log "$label: renamed $renamed item(s)."
}

main() {
  if (( EUID != 0 )); then
    print "This script must be run as root, aborting."
    exit 0
  fi

  local loggedinuser
  loggedinuser="$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

  if [[ -z "$loggedinuser" ]]; then
    print "Could not determine logged-in user, aborting."
    exit 0
  fi

  local onedrivefolder="/Users/$loggedinuser/$onedrive_folder_name"
  local fixdate
  timestamp
  fixdate="$REPLY"

  [[ -d /var/log/onedrive-fixlogs ]] || mkdir -p /var/log/onedrive-fixlogs
  local -r fixlog="/var/log/onedrive-fixlogs/onedrive-fixlog-$fixdate"
  log "Log created at $fixlog"

  local apfscheck
  apfscheck="$(diskutil info / | awk '/Type \(Bundle\)/ {print $3}')"

  if [[ "$apfscheck" != apfs ]]; then
    log "File system not supported, aborting."
    display_message "The file system on this Mac is not supported, please upgrade to macOS High Sierra or more recent."
    exit 0
  fi

  log "File system is APFS, the script may continue."

  if [[ ! -d "$onedrivefolder" ]]; then
    log "OneDrive directory not present, aborting."
    display_message "Cannot find the OneDrive folder. Ask IT to help set up OneDrive, or change the name of the folder"
    exit 0
  fi

  log "OneDrive directory is present. Stopping OneDrive."
  killall OneDrive || true
  while pgrep -xq OneDrive 2>/dev/null; do
    sleep 0.5
  done

  local beforefix_size beforefix_filecount
  beforefix_size="$(du -sk "$onedrivefolder" | awk -F '\t' '{print $1}')"
  beforefix_filecount=$(( $(find "$onedrivefolder" -mindepth 1 -print0 | /usr/bin/tr -dc '\0' | wc -c) ))
  log "Before fixing: ${beforefix_size} KB, ${beforefix_filecount} items."

  if [[ "$create_backup" == true ]]; then
    local backup_root="/Users/$loggedinuser/FF-Backup-$fixdate"
    local backup_dir="$backup_root/$fixdate.noindex"

    rm -rf /Users/$loggedinuser/FF-Backup-??????-????(N) 2>/dev/null

    mkdir -p "$backup_dir"
    chown "$loggedinuser":staff "$backup_root" "$backup_dir"
    touch "$backup_dir/.metadata_never_index"
    cp -cpR "$onedrivefolder" "$backup_dir"
    log "APFS clonefile backup created at $backup_dir."
  else
    log "Backup skipped."
  fi

  local -a illegal_filter=()
  if [[ "$fix_illegal_chars" == true ]]; then
    illegal_filter=(-o -name '*[\\:*?"<>|]*')
  fi

  local -a extended_filter=()
  if [[ "$fix_extended_chars" == true ]]; then
    extended_filter=(-o -name '*[«»`#,%]*')
  fi

  local tmp_dirnames tmp_filenames
  tmp_dirnames="$(mktemp)"
  tmp_filenames="$(mktemp)"

  # Directories first, deepest first (-depth ensures children are renamed before
  # their parent, preventing broken paths mid-run). Only problem names are
  # collected so mv is never called on clean filenames.
  log "Fixing directory names."
  find "$onedrivefolder" -depth -mindepth 1 -type d \
    \( -name "* " -o -name "*." -o -name " *" -o -name "..*" "${illegal_filter[@]}" "${extended_filter[@]}" \) \
    -print0 > "$tmp_dirnames"
  rename_from_file "Directories" "$tmp_dirnames"

  # Files after all directory renames are settled. -depth intentionally
  # omitted since order within a directory doesn't matter for files.
  log "Fixing file names."
  find "$onedrivefolder" -mindepth 1 \! -type d \
    \( -name "* " -o -name "*." -o -name " *" -o -name "..*" "${illegal_filter[@]}" "${extended_filter[@]}" \) \
    -print0 > "$tmp_filenames"
  rename_from_file "Files" "$tmp_filenames"

  local afterfix_size afterfix_filecount
  afterfix_size="$(du -sk "$onedrivefolder" | awk -F '\t' '{print $1}')"
  afterfix_filecount=$(( $(find "$onedrivefolder" -mindepth 1 -print0 | /usr/bin/tr -dc '\0' | wc -c) ))
  log "After fixing: ${afterfix_size} KB, ${afterfix_filecount} items. Restarting OneDrive."

  if (( afterfix_filecount >= beforefix_filecount - 5 && afterfix_filecount <= beforefix_filecount + 5 )); then
    if [[ "$create_backup" == true ]]; then
      display_message "File names have been corrected. A backup has been placed in FF-Backup-$fixdate in your user folder. The backup will be replaced the next time you correct filenames. You may also delete it, should you need more space."
    else
      display_message "File names have been corrected."
    fi
  else
    if [[ "$create_backup" == true ]]; then
      display_message "Something went wrong. A backup has been placed in FF-Backup-$fixdate in your user folder. Ask IT to help restore the backup."
    else
      display_message "Something went wrong. Ask IT for help."
    fi
  fi
}

main
finish
