#!/bin/bash
# =============================================================================
#  WordPress Malware Remediation Script — Multi-User Edition
#  Scans, verifies, and remediates WordPress installations under cPanel accounts
# =============================================================================

# ── Color Palette ─────────────────────────────────────────────────────────────
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"

C_WHITE="\e[97m"
C_CYAN="\e[96m"
C_BLUE="\e[94m"
C_GREEN="\e[92m"
C_YELLOW="\e[93m"
C_RED="\e[91m"
C_MAGENTA="\e[95m"
C_ORANGE="\e[38;5;214m"
C_GRAY="\e[38;5;245m"

BG_BLUE="\e[44m"
BG_DARK="\e[48;5;235m"

# ── Report File Setup ──────────────────────────────────────────────────────────
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
REPORT_DIR="/root/wp_remediation_reports"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/wp_report_${TIMESTAMP}.txt"
HTML_FILE="$REPORT_DIR/wp_report_${TIMESTAMP}.html"
ANSI_LOG=$(mktemp)

# Cleanup temp files on exit, then convert ANSI log → HTML
trap '_build_html; rm -f "$ANSI_LOG" "$_SITE_COUNT_FILE"' EXIT

# ── Tee: terminal  +  plain txt (ANSI stripped)  +  raw ANSI log for HTML ─────
exec > >(tee \
    >(sed 's/\x1b\[[0-9;]*m//g' >> "$REPORT_FILE") \
    >(cat >> "$ANSI_LOG") \
) 2>&1

# ── HTML Builder — called once at EXIT after all output is written ─────────────
_build_html() {
    # Wait briefly to ensure the ANSI_LOG pipe has flushed
    sleep 1

    local gen_time
    gen_time=$(date '+%Y-%m-%d %H:%M:%S')

    # Write HTML header
    cat > "$HTML_FILE" << HTMLHEAD
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>WP Remediation Report — ${gen_time}</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:ital,wght@0,300;0,400;0,700;1,400&family=Inter:wght@400;500;600;700&display=swap');

  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    background: #0d1117;
    color: #c9d1d9;
    font-family: 'JetBrains Mono', 'Courier New', monospace;
    font-size: 13.5px;
    line-height: 1.75;
  }

  .page-wrap {
    max-width: 1140px;
    margin: 0 auto;
    padding: 36px 28px 80px;
  }

  /* ── Top header bar ── */
  .report-header {
    background: linear-gradient(135deg, #1a2332 0%, #161b22 100%);
    border: 1px solid #30363d;
    border-radius: 12px;
    padding: 24px 28px;
    margin-bottom: 28px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-wrap: wrap;
    gap: 12px;
  }
  .report-header-left h1 {
    font-family: 'Inter', sans-serif;
    font-size: 18px;
    font-weight: 700;
    color: #f0f6fc;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .report-header-left h1 .shield { font-size: 22px; }
  .report-header-left p {
    font-family: 'Inter', sans-serif;
    font-size: 12px;
    color: #8b949e;
    margin-top: 4px;
  }
  .report-header-right {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 6px;
  }
  .badge {
    font-family: 'Inter', sans-serif;
    font-size: 11px;
    font-weight: 500;
    background: #21262d;
    border: 1px solid #30363d;
    border-radius: 20px;
    padding: 4px 14px;
    color: #8b949e;
    white-space: nowrap;
  }
  .badge.ok    { background:#122312; border-color:#238636; color:#3fb950; }
  .badge.warn  { background:#2d1e00; border-color:#9e6a03; color:#e3b341; }
  .badge.info  { background:#0c2a45; border-color:#1f6feb; color:#58a6ff; }

  /* ── Terminal block ── */
  .terminal-wrap {
    background: #161b22;
    border: 1px solid #21262d;
    border-radius: 12px;
    overflow: hidden;
  }
  .terminal-titlebar {
    background: #21262d;
    border-bottom: 1px solid #30363d;
    padding: 10px 16px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .dot { width:12px; height:12px; border-radius:50%; display:inline-block; }
  .dot-red    { background:#f85149; }
  .dot-yellow { background:#e3b341; }
  .dot-green  { background:#3fb950; }
  .terminal-label {
    font-family: 'Inter', sans-serif;
    font-size: 11px;
    color: #8b949e;
    margin-left: 6px;
  }
  pre {
    padding: 24px 28px;
    white-space: pre-wrap;
    word-break: break-word;
    line-height: 1.78;
    tab-size: 4;
  }

  /* ── ANSI color classes ── */
  .b  { font-weight: 700; }
  .d  { opacity: 0.5; }
  .fw { color: #f0f6fc; }
  .fc { color: #39d5e0; }
  .fb { color: #58a6ff; }
  .fg { color: #3fb950; }
  .fy { color: #e3b341; }
  .fr { color: #f85149; }
  .fm { color: #bc8cff; }
  .fo { color: #f0883e; }
  .fz { color: #8b949e; }
  .bgb { background:#1f3a5c; border-radius:3px; padding:1px 5px; }
  .bgd { background:#1c2128; border-radius:3px; padding:1px 5px; }

  /* ── Footer ── */
  .footer {
    margin-top: 32px;
    text-align: center;
    font-family: 'Inter', sans-serif;
    font-size: 11px;
    color: #484f58;
  }

  /* Scrollbar */
  ::-webkit-scrollbar { width: 8px; height: 8px; }
  ::-webkit-scrollbar-track { background: #0d1117; }
  ::-webkit-scrollbar-thumb { background: #30363d; border-radius: 4px; }
  ::-webkit-scrollbar-thumb:hover { background: #484f58; }
</style>
</head>
<body>
<div class="page-wrap">

  <div class="report-header">
    <div class="report-header-left">
      <h1><span class="shield">🛡</span> WordPress Remediation Report</h1>
      <p>Automated malware scan &amp; remediation — Multi-User Edition</p>
    </div>
    <div class="report-header-right">
      <span class="badge info">Generated: ${gen_time}</span>
      <span class="badge">Report: wp_report_${TIMESTAMP}.html</span>
    </div>
  </div>

  <div class="terminal-wrap">
    <div class="terminal-titlebar">
      <span class="dot dot-red"></span>
      <span class="dot dot-yellow"></span>
      <span class="dot dot-green"></span>
      <span class="terminal-label">bash — wp_remediation.sh</span>
    </div>
    <pre>
HTMLHEAD

    # ── ANSI → HTML conversion via Python3 ────────────────────────────────────
    python3 - "$ANSI_LOG" >> "$HTML_FILE" << 'PYEOF'
import sys, re, html as htmllib

# Map ANSI codes → CSS classes
CODE_MAP = {
    '1':        'b',    # bold
    '2':        'd',    # dim
    '97':       'fw',   # white
    '96':       'fc',   # cyan
    '94':       'fb',   # blue
    '92':       'fg',   # green
    '93':       'fy',   # yellow
    '91':       'fr',   # red
    '95':       'fm',   # magenta
    '38;5;214': 'fo',   # orange
    '38;5;245': 'fz',   # gray
    '44':       'bgb',  # bg blue
    '48;5;235': 'bgd',  # bg dark
}

ESC_RE = re.compile(r'\x1b\[([0-9;]+)m')

def convert(text):
    out = []
    depth = 0
    last = 0
    for m in ESC_RE.finditer(text):
        raw = htmllib.escape(text[last:m.start()])
        out.append(raw)
        code = m.group(1)
        if code == '0':
            # Close all open spans
            out.append('</span>' * depth)
            depth = 0
        else:
            cls = CODE_MAP.get(code)
            if cls:
                out.append(f'<span class="{cls}">')
                depth += 1
        last = m.end()
    out.append(htmllib.escape(text[last:]))
    out.append('</span>' * depth)
    return ''.join(out)

with open(sys.argv[1], 'r', errors='replace') as f:
    content = f.read()

print(convert(content), end='')
PYEOF

    # ── Close HTML ────────────────────────────────────────────────────────────
    cat >> "$HTML_FILE" << HTMLFOOT
</pre>
  </div>

  <div class="footer">
    Generated by wp_remediation.sh &nbsp;•&nbsp; ${gen_time}
  </div>

</div>
</body>
</html>
HTMLFOOT
}

# ══════════════════════════════════════════════════════════════════════════════
#  PRINT HELPERS
# ══════════════════════════════════════════════════════════════════════════════

print_banner() {
    echo -e ""
    echo -e "${BOLD}${BG_BLUE}${C_WHITE}                                                                    ${RESET}"
    echo -e "${BOLD}${BG_BLUE}${C_WHITE}      WordPress Malware Remediation Script — Multi-User Edition      ${RESET}"
    echo -e "${BOLD}${BG_BLUE}${C_WHITE}                                                                    ${RESET}"
    echo -e "${DIM}${C_GRAY}  TXT Report : ${REPORT_FILE}${RESET}"
    echo -e "${DIM}${C_GRAY}  HTML Report: ${HTML_FILE}${RESET}"
    echo -e "${DIM}${C_GRAY}  Started    : $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e ""
}

print_section()    { echo -e "  ${BOLD}${C_CYAN}$1${RESET}${C_WHITE} $2${RESET}"; }
print_ok()         { echo -e "    ${C_GREEN}✔  ${RESET}$1"; }
print_warn()       { echo -e "    ${C_YELLOW}⚠  ${RESET}$1"; }
print_info()       { echo -e "    ${C_BLUE}ℹ  ${RESET}$1"; }
print_error()      { echo -e "    ${C_RED}✖  ${RESET}$1"; }
print_item()       { echo -e "    ${C_GRAY}•  ${RESET}$1"; }
print_action()     { echo -e "    ${C_MAGENTA}→  ${RESET}$1"; }

print_subheading() {
    echo -e ""
    echo -e "    ${BOLD}${C_YELLOW}$1${RESET}"
    echo -e "    ${C_GRAY}$(printf '·%.0s' {1..60})${RESET}"
}

print_user_header() {
    local user=$1
    echo -e ""
    echo -e "${BOLD}${C_ORANGE}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${C_ORANGE}║  cPanel User: ${C_WHITE}${user}$(printf '%*s' $((51 - ${#user})) '')${C_ORANGE}║${RESET}"
    echo -e "${BOLD}${C_ORANGE}╚══════════════════════════════════════════════════════════════════╝${RESET}"
}

print_site_header() {
    echo -e ""
    echo -e "  ${BOLD}${BG_DARK}${C_CYAN}  ▌ Installation [$2/$3]: ${C_WHITE}$1  ${RESET}"
    echo -e "  ${C_GRAY}$(printf '─%.0s' {1..66})${RESET}"
}

print_user_summary() {
    echo -e ""
    echo -e "  ${C_GRAY}$(printf '─%.0s' {1..66})${RESET}"
    echo -e "  ${BOLD}${C_GREEN}✔  Finished scanning $2 installation(s) for user: ${C_WHITE}$1${RESET}"
}

print_final_summary() {
    echo -e ""
    echo -e "${BOLD}${C_ORANGE}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${C_ORANGE}║                        SCAN COMPLETE                            ║${RESET}"
    echo -e "${BOLD}${C_ORANGE}╚══════════════════════════════════════════════════════════════════╝${RESET}"
    echo -e ""
    print_section "Users Processed :" "$1"
    print_section "Total WP Sites  :" "$2"
    print_section "TXT Report      :" "${REPORT_FILE}"
    print_section "HTML Report     :" "${HTML_FILE}"
    echo -e "  ${DIM}${C_GRAY}Finished: $(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e ""
}

# ══════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════════════

validate_user() {
    if ! id -u "$1" >/dev/null 2>&1; then
        print_error "Invalid username: '${1}' — skipping."
        return 1
    fi
    return 0
}

is_cache_path() {
    local path="$1"
    local cache_patterns=(
        "wp-content/cache"
        "wp-content/w3tc-cache"
        "wp-content/wp-rocket-config"
        "wp-content/litespeed"
        "wp-content/wpo-cache"
        "wp-content/breeze-config"
        "/cache/"
    )
    for pattern in "${cache_patterns[@]}"; do
        [[ "$path" == *"$pattern"* ]] && return 0
    done
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
#  SCAN A SINGLE WP INSTALLATION
# ══════════════════════════════════════════════════════════════════════════════

scan_wp_installation() {
    local docroot="$1" cpuser="$2" idx="$3" total="$4"

    print_site_header "$docroot" "$idx" "$total"

    # ── WP Version ────────────────────────────────────────────────────────────
    local version
    version=$(grep -s '^\$wp_version' "${docroot}/wp-includes/version.php" 2>/dev/null | cut -d\' -f2)
    if [[ -z "$version" ]]; then
        print_warn "Could not detect WordPress version. Skipping."
        return
    fi
    print_section "WordPress Version :" "$version"

    # ── Core Checksum ─────────────────────────────────────────────────────────
    print_subheading "CORE FILE INTEGRITY"
    local checksum_output unwanted_files modified_files
    checksum_output=$(su - "$cpuser" -s /bin/bash -c "cd \"$docroot\" && wp core verify-checksums 2>&1")
    unwanted_files=$(echo "$checksum_output" | grep 'File should not exist' | awk '{print $6}')
    modified_files=$(echo "$checksum_output"  | grep 'File was modified'    | awk '{print $5}')

    if [[ -z "$unwanted_files" && -z "$modified_files" ]]; then
        print_ok "Core checksum passed — no unexpected or modified files found."
    else
        if [[ -n "$unwanted_files" ]]; then
            print_warn "Files that should NOT exist in core:"
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                print_item "${C_RED}${f}${RESET}"
            done <<< "$unwanted_files"
        fi
        if [[ -n "$modified_files" ]]; then
            print_warn "Core files that have been modified:"
            while IFS= read -r f; do
                [[ -z "$f" ]] && continue
                print_item "${C_YELLOW}${f}${RESET}"
            done <<< "$modified_files"
        fi
    fi

    # ── PHP Files in Uploads ───────────────────────────────────────────────────
    print_subheading "PHP FILES IN UPLOADS DIRECTORY"
    local php_uploads
    php_uploads=$(su - "$cpuser" -s /bin/bash -c \
        "find \"${docroot}/wp-content/uploads/\" -type f -iname '*.php' 2>/dev/null")

    if [[ -z "$php_uploads" ]]; then
        print_ok "No PHP files found in uploads."
    else
        print_error "PHP files found in uploads (should not exist):"
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            print_item "${C_RED}${f}${RESET}"
        done <<< "$php_uploads"
    fi

    # ── Plugin Status ─────────────────────────────────────────────────────────
    print_subheading "PLUGIN STATUS"

    local plugin_checksum_fail
    plugin_checksum_fail=$(su - "$cpuser" -s /bin/bash -c \
        "cd \"$docroot\" && wp plugin verify-checksums --all --format=csv 2>/dev/null \
         | grep 'File was added' | cut -d, -f1 | sort -u")

    if [[ -z "$plugin_checksum_fail" ]]; then
        print_ok "All plugins passed checksum verification."
    else
        print_warn "Plugins with extra/added files (manual review recommended):"
        while IFS= read -r p; do
            [[ -z "$p" ]] && continue
            print_item "${C_YELLOW}${p}${RESET}"
        done <<< "$plugin_checksum_fail"
    fi

    local plugin_updates
    plugin_updates=$(su - "$cpuser" -s /bin/bash -c \
        "cd \"$docroot\" && wp plugin list --update=available \
         --fields=name,version,update_version --format=csv 2>/dev/null | tail -n +2")

    if [[ -z "$plugin_updates" ]]; then
        print_ok "All plugins are up to date."
    else
        print_warn "Plugins with available updates:"
        printf "    ${BOLD}${C_GRAY}%-35s %-15s %-15s${RESET}\n" "Plugin" "Current" "Available"
        printf "    ${C_GRAY}%-35s %-15s %-15s${RESET}\n" \
            "$(printf '─%.0s' {1..33})" "$(printf '─%.0s' {1..13})" "$(printf '─%.0s' {1..13})"
        while IFS=',' read -r name cur avail; do
            printf "    ${C_WHITE}%-35s${RESET} ${C_YELLOW}%-15s${RESET} ${C_GREEN}%-15s${RESET}\n" \
                "$name" "$cur" "$avail"
        done <<< "$plugin_updates"
    fi

    # ── Theme Status ──────────────────────────────────────────────────────────
    print_subheading "THEME STATUS"

    local theme_updates
    theme_updates=$(su - "$cpuser" -s /bin/bash -c \
        "cd \"$docroot\" && wp theme list --update=available \
         --fields=name,version,update_version --format=csv 2>/dev/null | tail -n +2")

    if [[ -z "$theme_updates" ]]; then
        print_ok "All themes are up to date."
    else
        print_warn "Themes with available updates:"
        printf "    ${BOLD}${C_GRAY}%-35s %-15s %-15s${RESET}\n" "Theme" "Current" "Available"
        printf "    ${C_GRAY}%-35s %-15s %-15s${RESET}\n" \
            "$(printf '─%.0s' {1..33})" "$(printf '─%.0s' {1..13})" "$(printf '─%.0s' {1..13})"
        while IFS=',' read -r name cur avail; do
            printf "    ${C_WHITE}%-35s${RESET} ${C_YELLOW}%-15s${RESET} ${C_GREEN}%-15s${RESET}\n" \
                "$name" "$cur" "$avail"
        done <<< "$theme_updates"
    fi

    # ── Admin Users ───────────────────────────────────────────────────────────
    print_subheading "ADMINISTRATOR ACCOUNTS"
    local admins
    admins=$(su - "$cpuser" -s /bin/bash -c \
        "cd \"$docroot\" && wp user list --role=administrator \
         --fields=ID,user_login,user_email,user_registered --format=csv 2>/dev/null | tail -n +2")

    if [[ -z "$admins" ]]; then
        print_warn "No administrator accounts found (or WP-CLI could not connect)."
    else
        printf "    ${BOLD}${C_GRAY}%-6s %-25s %-35s %-20s${RESET}\n" \
            "ID" "Username" "Email" "Registered"
        printf "    ${C_GRAY}%-6s %-25s %-35s %-20s${RESET}\n" \
            "$(printf '─%.0s' {1..4})" "$(printf '─%.0s' {1..23})" \
            "$(printf '─%.0s' {1..33})" "$(printf '─%.0s' {1..18})"
        while IFS=',' read -r id login email reg; do
            printf "    ${C_WHITE}%-6s${RESET} ${C_CYAN}%-25s${RESET} ${C_GRAY}%-35s %-20s${RESET}\n" \
                "$id" "$login" "$email" "$reg"
        done <<< "$admins"
    fi

    # ── Remediation Actions ───────────────────────────────────────────────────
    print_subheading "REMEDIATION ACTIONS"

    print_action "Re-downloading WordPress core v${version} (force overwrite)..."
    su - "$cpuser" -s /bin/bash -c \
        "cd \"$docroot\" && wp core download --force --version=\"$version\" --quiet 2>&1" \
        && print_ok "Core files restored." \
        || print_error "Core download failed."

    print_action "Setting PHP file permissions to 644..."
    su - "$cpuser" -s /bin/bash -c \
        "find \"$docroot\" -type f -iname '*.php' -exec chmod 644 {} \;" 2>/dev/null \
        && print_ok "Permissions updated." \
        || print_error "Permission update failed."

    print_action "Updating WordPress database..."
    su - "$cpuser" -s /bin/bash -c \
        "cd \"$docroot\" && wp core update-db --quiet 2>&1" \
        && print_ok "Database updated." \
        || print_error "Database update failed."

    print_action "Shuffling wp-config salts..."
    su - "$cpuser" -s /bin/bash -c \
        "cd \"$docroot\" && wp config shuffle-salts 2>&1" \
        && print_ok "Salts refreshed." \
        || print_error "Salt shuffle failed."

    echo -e ""
}

# ══════════════════════════════════════════════════════════════════════════════
#  PROCESS ALL INSTALLATIONS FOR ONE CPANEL USER
# ══════════════════════════════════════════════════════════════════════════════

process_user() {
    local cpuser="$1"
    print_user_header "$cpuser"

    local doctroots=()
    while IFS= read -r wpdir; do
        local dir
        dir=$(dirname "$wpdir")
        if is_cache_path "$dir"; then
            print_info "Skipping cache path: $dir"
            continue
        fi
        doctroots+=("$dir")
    done < <(find "/home/${cpuser}/" -type d -name 'wp-content' 2>/dev/null | sort -u)

    local total=${#doctroots[@]}

    if [[ $total -eq 0 ]]; then
        print_warn "No WordPress installations found for user: ${cpuser}"
        print_user_summary "$cpuser" 0
        echo 0 >> "$_SITE_COUNT_FILE"
        return
    fi

    print_info "Found ${total} WordPress installation(s). Starting scan..."

    local idx=0
    for docroot in "${doctroots[@]}"; do
        idx=$((idx + 1))
        scan_wp_installation "$docroot" "$cpuser" "$idx" "$total"
    done

    print_user_summary "$cpuser" "$total"
    echo "$total" >> "$_SITE_COUNT_FILE"
}

# ══════════════════════════════════════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════

print_banner

_SITE_COUNT_FILE=$(mktemp)

# ── Accept usernames ──────────────────────────────────────────────────────────
# Mode 1: ./script.sh user1 user2 user3 ...
# Mode 2: run with no args → paste usernames (space or newline separated), Ctrl+D when done
cpusers=()

if [[ $# -gt 0 ]]; then
    cpusers=("$@")
else
    echo -e "${BOLD}${C_CYAN}Enter cPanel username(s).${RESET}"
    echo -e "${C_GRAY}  Space-separated on one line, or paste a block then press Ctrl+D:${RESET}"
    while IFS= read -r line; do
        for token in $line; do
            cpusers+=("$token")
        done
    done
fi

if [[ ${#cpusers[@]} -eq 0 ]]; then
    print_error "No usernames provided. Exiting."
    exit 1
fi

print_info "Total usernames received: ${#cpusers[@]}"

# ── Process each user ─────────────────────────────────────────────────────────
total_users_processed=0

for cpuser in "${cpusers[@]}"; do
    cpuser=$(echo "$cpuser" | tr -d '[:space:]\r')
    [[ -z "$cpuser" ]] && continue
    if ! validate_user "$cpuser"; then
        continue
    fi
    process_user "$cpuser"
    total_users_processed=$((total_users_processed + 1))
done

# ── Grand total ───────────────────────────────────────────────────────────────
grand_total_sites=0
while IFS= read -r n; do
    grand_total_sites=$((grand_total_sites + n))
done < "$_SITE_COUNT_FILE"

print_final_summary "$total_users_processed" "$grand_total_sites"
# EXIT trap fires here → _build_html runs → HTML file is written
