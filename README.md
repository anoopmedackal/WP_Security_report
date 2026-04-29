# 🛡️ WordPress Malware Remediation Script — Multi-User Edition

A powerful Bash script for cPanel server administrators to **scan, verify, and remediate WordPress installations** across multiple cPanel accounts in a single run. Outputs a color-coded terminal report and automatically generates a shareable **HTML report** and a plain-text log.

---

## ✨ Features

- **Multi-user support** — scan any number of cPanel accounts in one go, passed as arguments or pasted interactively
- **Auto-discovers all WordPress installations** under each cPanel user's home directory
- **Cache-aware** — automatically skips WordPress instances found inside caching plugin directories (W3TC, WP Rocket, LiteSpeed, Breeze, etc.)
- **Core file integrity check** — detects files that shouldn't exist and modified core files via `wp core verify-checksums`
- **PHP file detection in uploads** — flags any `.php` files hiding in `wp-content/uploads/`
- **Plugin checksum audit** — lists plugins with extra/added files (checksum mismatch) for manual review — does **not** auto-delete
- **Plugin & theme update audit** — lists available updates with current vs. available version in a clean table — does **not** auto-update
- **Admin user listing** — displays all WordPress administrator accounts per site for suspicious account review
- **Automated remediation actions:**
  - Re-downloads the correct WordPress core version (force overwrite) to restore tampered files
  - Resets all PHP file permissions to `644`
  - Runs WordPress database updates
  - Shuffles `wp-config.php` security salts
- **Dual report output** — saves a plain `.txt` log and a fully styled `.html` report automatically on every run

---

## 📋 Requirements

| Requirement | Details |
|-------------|---------|
| OS | CentOS / AlmaLinux / CloudLinux (standard cPanel environment) |
| Privileges | Must be run as **root** |
| WP-CLI | Must be installed and available system-wide (`/usr/local/bin/wp`) |
| Python 3 | Required for ANSI → HTML conversion (pre-installed on all cPanel servers) |
| Shell | Bash 4.0+ |

---

## 🚀 Usage

### Make the script executable

```bash
wget https://raw.githubusercontent.com/anoopmedackal/WP_Security_report/main/wp_remediation.sh
chmod +x wp_remediation.sh
```

### Option 1 — Pass usernames as arguments

```bash
./wp_remediation.sh user1 user2 user3
```

### Option 2 — Interactive mode (paste a list, then Ctrl+D)

```bash
./wp_remediation.sh
```

```
Enter cPanel username(s).
  Space-separated on one line, or paste a block then press Ctrl+D:
user1 user2 user3 user4
user5 user6
^D
```

Both modes accept any number of usernames, space-separated, newline-separated, or mixed.

---

## 📁 Output Files

Every run automatically saves two report files to `/root/wp_remediation_reports/`:

```
/root/wp_remediation_reports/
├── wp_report_2025-01-15_14-30-00.txt    ← Plain text log (ANSI stripped)
└── wp_report_2025-01-15_14-30-00.html  ← Styled HTML report for sharing
```

The **HTML report** uses a dark terminal-style theme with all colors, icons, and formatting preserved — ready to send directly to a customer to open in any browser.

---

## 🗂️ What Gets Scanned Per Site

For every WordPress installation found, the script reports on:

```
▌ Installation [1/3]: /home/username/public_html
────────────────────────────────────────────────────────────────────
  WordPress Version : 6.4.3

  CORE FILE INTEGRITY
  ···················
  ✔  Core checksum passed — no unexpected or modified files found.

  PHP FILES IN UPLOADS DIRECTORY
  ···············~~~~~~~~~~~~~~~~
  ✖  PHP files found in uploads (should not exist):
     •  /home/username/public_html/wp-content/uploads/2024/shell.php

  PLUGIN STATUS
  ·············
  ⚠  Plugins with extra/added files (manual review recommended):
     •  contact-form-7
  ⚠  Plugins with available updates:
     Plugin                              Current         Available
     ─────────────────────────────────── ─────────────── ───────────────
     woocommerce                         8.3.0           8.4.1
     yoast-seo                           21.5            21.9

  THEME STATUS
  ············
  ✔  All themes are up to date.

  ADMINISTRATOR ACCOUNTS
  ──────────────────────
  ID     Username                  Email                               Registered
  ────── ───────────────────────── ─────────────────────────────────── ──────────────────
  1      admin                     admin@example.com                   2022-03-10 09:15:00

  REMEDIATION ACTIONS
  ───────────────────
  →  Re-downloading WordPress core v6.4.3 (force overwrite)...
  ✔  Core files restored.
  →  Setting PHP file permissions to 644...
  ✔  Permissions updated.
  →  Updating WordPress database...
  ✔  Database updated.
  →  Shuffling wp-config salts...
  ✔  Salts refreshed.
```

---

## ⚠️ What the Script Does NOT Do

| Action | Reason |
|--------|--------|
| Update plugins or themes | Listed for review only — updates should be done manually after review |
| Delete plugin files that failed checksum | Listed for manual review — auto-deletion could break sites |
| Remove PHP files from uploads | Flagged only — admin must verify and remove manually |
| Modify `wp-config.php` beyond salt shuffle | Only salts are touched |

---

## 🗃️ Cache Paths Excluded

The script automatically skips WordPress installs found inside these directories:

- `wp-content/cache`
- `wp-content/w3tc-cache`
- `wp-content/wp-rocket-config`
- `wp-content/litespeed`
- `wp-content/wpo-cache`
- `wp-content/breeze-config`
- Any path containing `/cache/`

---

## 🔐 Security Notes

- Run **only as root** on a cPanel server — the script uses `su - <user>` to run WP-CLI with correct file ownership
- All WP-CLI commands run as the cPanel user, not root, to avoid file permission issues
- Salts are shuffled on every run, which will log out all active WordPress sessions for that site

---

## 📄 License

MIT — free to use, modify, and distribute. Attribution appreciated.
