#!/usr/bin/env bash
# setup.sh — 按 setup.config 在当前用户/设备上安装并配置 Unlock Briefing
# 可复现：任意 macOS 用户克隆仓库后执行 ./setup.sh 即可。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
CONFIG_FILE="${REPO_ROOT}/setup.config"

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--config PATH] [--dry-run] [--no-open] [--help]

  --config PATH   安装配置文件（默认：仓库内 setup.config）
  --dry-run       只打印将要执行的步骤，不改系统
  --no-open       跳过打开 Hammerspoon.app（覆盖配置 OPEN_APP_AFTER_SETUP）
  --help          显示帮助

跨设备复现：
  1. git clone <repo> && cd todo-alert-mac
  2. 按需编辑 setup.config（路径均为 $HOME / 相对仓库，勿写死用户名）
  3. ./setup.sh
  4. 按提示授予 辅助功能（Accessibility）
  5. 菜单栏锤子 → Reload Config；锁屏再解锁验证
EOF
}

DRY_RUN=false
FORCE_NO_OPEN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:?--config requires a path}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-open)
      FORCE_NO_OPEN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: config not found: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Expand ~ in config dir if someone wrote literal ~
HAMMERSPOON_CONFIG_DIR="${HAMMERSPOON_CONFIG_DIR/#\~/$HOME}"

log()  { printf '==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run() {
  if $DRY_RUN; then
    info "(dry-run) $*"
    return 0
  fi
  "$@"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# --- 0. 环境 ------------------------------------------------------------------
log "Repo:    $REPO_ROOT"
log "Config:  $CONFIG_FILE"
log "User:    ${USER:-unknown}  HOME=$HOME"
log "Host:    $(hostname -s 2>/dev/null || hostname)  arch=$(uname -m)"
if $DRY_RUN; then
  log "Mode:    dry-run"
fi

# --- 1. Homebrew --------------------------------------------------------------
BREW_BIN=""
if need_cmd brew; then
  BREW_BIN="$(command -v brew)"
elif [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_BIN="/usr/local/bin/brew"
fi

if [[ -z "$BREW_BIN" ]]; then
  if [[ "${REQUIRE_BREW:-true}" == "true" ]]; then
    die "Homebrew not found. Install from https://brew.sh then re-run ./setup.sh"
  else
    warn "Homebrew not found; skipping package installs"
  fi
else
  info "brew: $BREW_BIN"
  # Ensure brew env for non-interactive shells
  eval "$("$BREW_BIN" shellenv)" 2>/dev/null || true
fi

# --- 2. Install Hammerspoon ---------------------------------------------------
if [[ "${INSTALL_HAMMERSPOON:-true}" == "true" ]]; then
  if [[ -d "${HAMMERSPOON_APP:-/Applications/Hammerspoon.app}" ]]; then
    log "Hammerspoon already installed: $HAMMERSPOON_APP"
  else
    if [[ -z "$BREW_BIN" ]]; then
      die "Cannot install Hammerspoon without Homebrew"
    fi
    log "Installing Hammerspoon (brew cask ${HAMMERSPOON_CASK})..."
    run "$BREW_BIN" install --cask "${HAMMERSPOON_CASK}"
  fi
  if [[ ! -d "${HAMMERSPOON_APP}" ]] && ! $DRY_RUN; then
    die "Hammerspoon.app not found at $HAMMERSPOON_APP after install"
  fi
else
  log "INSTALL_HAMMERSPOON=false; skip app install"
fi

# --- 3. Install Lua (optional, for tests) -------------------------------------
if [[ "${INSTALL_LUA:-false}" == "true" ]]; then
  if need_cmd lua; then
    log "Lua already available: $(command -v lua) ($(lua -v 2>&1 | head -1))"
  else
    if [[ -z "$BREW_BIN" ]]; then
      warn "Cannot install Lua without brew; skip"
    else
      log "Installing Lua (brew ${LUA_FORMULA})..."
      run "$BREW_BIN" install "${LUA_FORMULA}"
    fi
  fi
fi

# --- 4. Seed personal content.json from example (never committed) -------------
CONTENT_EXAMPLE="${CONTENT_EXAMPLE:-content.example.json}"
CONTENT_FILE="${CONTENT_FILE:-content.json}"
example_src="${REPO_ROOT}/${CONTENT_EXAMPLE}"
content_src="${REPO_ROOT}/${CONTENT_FILE}"
if [[ ! -f "$content_src" ]]; then
  if [[ ! -f "$example_src" ]]; then
    die "Missing ${CONTENT_EXAMPLE}; cannot seed ${CONTENT_FILE}"
  fi
  log "Seed ${CONTENT_FILE} from ${CONTENT_EXAMPLE} (personal; gitignored)"
  run cp "$example_src" "$content_src"
else
  info "${CONTENT_FILE} already exists (kept as-is)"
fi

# --- 5. Deploy config files ---------------------------------------------------
log "Deploy mode=${DEPLOY_MODE} → ${HAMMERSPOON_CONFIG_DIR}"
run mkdir -p "${HAMMERSPOON_CONFIG_DIR}"

TS="$(date +%Y%m%d%H%M%S)"
for rel in ${DEPLOY_FILES}; do
  src="${REPO_ROOT}/${rel}"
  dst="${HAMMERSPOON_CONFIG_DIR}/$(basename "$rel")"
  if [[ ! -e "$src" ]]; then
    die "Missing source file: $src"
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    # Already correct symlink?
    if [[ -L "$dst" ]]; then
      target="$(readlink "$dst")"
      # resolve relative link
      if [[ "$target" != /* ]]; then
        target="$(cd "$(dirname "$dst")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")"
      fi
      src_abs="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
      if [[ "$target" == "$src_abs" ]] || [[ "$(readlink "$dst")" == "$src_abs" ]] || [[ "$(readlink "$dst")" == "$src" ]]; then
        info "ok (already linked): $dst"
        continue
      fi
    fi

    case "${ON_EXISTING:-backup}" in
      backup)
        bak="${dst}${BACKUP_SUFFIX_PREFIX:-.bak}.${TS}"
        info "backup existing → $bak"
        run mv "$dst" "$bak"
        ;;
      overwrite)
        info "overwrite: $dst"
        run rm -f "$dst"
        ;;
      skip)
        info "skip existing: $dst"
        continue
        ;;
      *)
        die "Unknown ON_EXISTING=$ON_EXISTING"
        ;;
    esac
  fi

  case "${DEPLOY_MODE}" in
    symlink)
      info "ln -sf $src → $dst"
      run ln -sf "$src" "$dst"
      ;;
    copy)
      info "cp $src → $dst"
      run cp "$src" "$dst"
      ;;
    *)
      die "Unknown DEPLOY_MODE=$DEPLOY_MODE (use symlink|copy)"
      ;;
  esac
done

# --- 6. Verify deploy ---------------------------------------------------------
if [[ "${VERIFY_DEPLOY:-true}" == "true" ]] && ! $DRY_RUN; then
  log "Verifying deploy..."
  for rel in ${DEPLOY_FILES}; do
    dst="${HAMMERSPOON_CONFIG_DIR}/$(basename "$rel")"
    if [[ ! -e "$dst" ]]; then
      die "Missing after deploy: $dst"
    fi
    info "present: $dst$( [[ -L "$dst" ]] && printf ' -> %s' "$(readlink "$dst")" )"
  done
fi

# --- 7. Launch at login (best-effort) -----------------------------------------
if [[ "${ENABLE_LAUNCH_AT_LOGIN:-false}" == "true" ]]; then
  log "Enable launch at login (best-effort)..."
  APP="${HAMMERSPOON_APP}"
  if $DRY_RUN; then
    info "(dry-run) would register login item for $APP"
  else
    if [[ -d "$APP" ]]; then
      # Modern macOS may require Automation permission for System Events.
      if osascript <<OSA 2>/dev/null
tell application "System Events"
  if not (exists login item "${LOGIN_ITEM_NAME}") then
    make login item at end with properties {path:"${APP}", hidden:false, name:"${LOGIN_ITEM_NAME}"}
  end if
end tell
OSA
      then
        info "login item registered (or already present)"
      else
        warn "Could not set login item automatically. Enable in Hammerspoon menu: Launch Hammerspoon at login"
      fi
    fi
  fi
fi

# --- 8. Open app --------------------------------------------------------------
SHOULD_OPEN="${OPEN_APP_AFTER_SETUP:-true}"
if $FORCE_NO_OPEN; then
  SHOULD_OPEN=false
fi
if [[ "$SHOULD_OPEN" == "true" ]]; then
  log "Opening Hammerspoon..."
  if [[ -d "${HAMMERSPOON_APP}" ]]; then
    run open -a Hammerspoon || run open "${HAMMERSPOON_APP}"
  else
    warn "App not found; skip open"
  fi
fi

# --- 9. Optional tests --------------------------------------------------------
if [[ "${RUN_TESTS_AFTER_SETUP:-false}" == "true" ]]; then
  if need_cmd lua; then
    log "Running tests..."
    (cd "$REPO_ROOT" && run lua tests/test_briefing.lua && run lua tests/test_load.lua)
  else
    warn "lua not on PATH; skip tests"
  fi
fi

# --- 10. Accessibility hint ----------------------------------------------------
if [[ "${PRINT_ACCESSIBILITY_HINT:-true}" == "true" ]]; then
  cat <<EOF

------------------------------------------------------------------------------
安装与配置已按 setup.config 完成。

【必须手动一次】辅助功能权限（macOS 无法静默代授）：
  系统设置 → 隐私与安全性 → 辅助功能 → 启用 Hammerspoon

【建议】
  菜单栏锤子图标 → Reload Config
  可选：锤子菜单 → Launch Hammerspoon at login（若自动登录项失败）

【验证】
  1. 看到短暂提示「每日简报已启动」
  2. Ctrl+Cmd+Q 锁屏 → 解锁 → 约 0.8s 后出现待办+倒计时
  3. 再解锁一次：当天应不再弹（onlyFirstUnlockOfDay=true）

【改待办 / 倒计时】
  只改本地 content.json（已 gitignore，不会进仓库）
  仓库模板：content.example.json
  行为/UI：config.lua → Reload Config

【另一台设备复现】
  git clone <repo> && cd mac-unlock-briefing && ./setup.sh
  （首次会从 content.example.json 生成 content.json）
------------------------------------------------------------------------------
EOF
fi

log "Done."
