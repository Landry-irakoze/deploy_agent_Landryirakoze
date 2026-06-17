

set -euo pipefail

# ── Color helpers ────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${BOLD}${BLUE}==> $*${NC}"; }

# ── Input validation ─────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    error "Usage: $0 <project_name>"
    echo  "       Example: $0 cohort_2024"
    exit 1
fi

INPUT="$1"

if [[ ! "$INPUT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    error "Project name may only contain letters, digits, underscores, and hyphens."
    exit 1
fi

PROJECT_DIR="attendance_tracker_${INPUT}"
HELPERS_DIR="${PROJECT_DIR}/Helpers"
REPORTS_DIR="${PROJECT_DIR}/reports"
ARCHIVE_NAME="attendance_tracker_${INPUT}_archive"

# ── Signal trap ──────────────────────────────────────────────
cleanup_on_interrupt() {
    echo ""
    warn "Interrupt received — bundling current state before exit…"

    if [[ -d "$PROJECT_DIR" ]]; then
        tar -czf "${ARCHIVE_NAME}.tar.gz" "$PROJECT_DIR" 2>/dev/null \
            && success "Archive created: ${ARCHIVE_NAME}.tar.gz" \
            || warn "Archiving failed."

        rm -rf "$PROJECT_DIR"
        success "Incomplete directory '${PROJECT_DIR}' removed."
    else
        info "Nothing to archive — project directory was not yet created."
    fi

    echo -e "${RED}Setup aborted by user.${NC}"
    exit 130
}

trap cleanup_on_interrupt SIGINT SIGTERM

# ════════════════════════════════════════════════════════════
#  PHASE 1 — Directory architecture
# ════════════════════════════════════════════════════════════
header "Phase 1: Creating directory structure"

if [[ -d "$PROJECT_DIR" ]]; then
    error "Directory '${PROJECT_DIR}' already exists. Remove it or choose a different name."
    exit 1
fi

mkdir -p "$HELPERS_DIR" "$REPORTS_DIR" \
    && success "Directory tree created: ${PROJECT_DIR}/"

# ════════════════════════════════════════════════════════════
#  PHASE 2 — Generate source files
# ════════════════════════════════════════════════════════════
header "Phase 2: Generating project files"

# ── attendance_checker.py ────────────────────────────────────
cat > "${PROJECT_DIR}/attendance_checker.py" << 'PYEOF'
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)

    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']

        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")

        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])

            # Simple Math: (Attended / Total) * 100
            attendance_pct = (attended / total_sessions) * 100

            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."

            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
PYEOF
success "Created attendance_checker.py"

# ── assets.csv ───────────────────────────────────────────────
cat > "${HELPERS_DIR}/assets.csv" << 'CSVEOF'
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
CSVEOF
success "Created Helpers/assets.csv"

# ── config.json ──────────────────────────────────────────────
cat > "${HELPERS_DIR}/config.json" << 'JSONEOF'
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
JSONEOF
success "Created Helpers/config.json"

# ── reports.log ──────────────────────────────────────────────
cat > "${REPORTS_DIR}/reports.log" << 'LOGEOF'
--- Attendance Report Run: 2026-02-06 18:10:01.468726 ---
[2026-02-06 18:10:01.469363] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your attendance is 46.7%. You will fail this class.
[2026-02-06 18:10:01.469424] ALERT SENT TO charlie@example.com: URGENT: Charlie Davis, your attendance is 26.7%. You will fail this class.
LOGEOF
success "Created reports/reports.log"

# ════════════════════════════════════════════════════════════
#  PHASE 3 — Dynamic configuration via sed
# ════════════════════════════════════════════════════════════
header "Phase 3: Dynamic Configuration"

echo -e "Current defaults → Warning: ${YELLOW}75%${NC}  |  Failure: ${YELLOW}50%${NC}  |  Total Sessions: ${YELLOW}15${NC}"
echo ""
read -rp "$(echo -e "${BOLD}Update attendance thresholds? [y/N]:${NC} ")" UPDATE_CHOICE

if [[ "$UPDATE_CHOICE" =~ ^[Yy]$ ]]; then

    # ── Warning threshold ────────────────────────────────────
    while true; do
        read -rp "  Enter Warning threshold % (1-100, default 75): " WARNING_VAL
        WARNING_VAL="${WARNING_VAL:-75}"
        if [[ "$WARNING_VAL" =~ ^[0-9]+$ ]] && (( WARNING_VAL >= 1 && WARNING_VAL <= 100 )); then
            break
        fi
        error "Invalid input. Please enter a whole number between 1 and 100."
    done

    # ── Failure threshold ────────────────────────────────────
    while true; do
        read -rp "  Enter Failure threshold % (1-100, default 50): " FAILURE_VAL
        FAILURE_VAL="${FAILURE_VAL:-50}"
        if [[ "$FAILURE_VAL" =~ ^[0-9]+$ ]] && (( FAILURE_VAL >= 1 && FAILURE_VAL <= 100 )); then
            break
        fi
        error "Invalid input. Please enter a whole number between 1 and 100."
    done

    # ── Total sessions ───────────────────────────────────────
    while true; do
        read -rp "  Enter total number of sessions (default 15): " SESSIONS_VAL
        SESSIONS_VAL="${SESSIONS_VAL:-15}"
        if [[ "$SESSIONS_VAL" =~ ^[0-9]+$ ]] && (( SESSIONS_VAL >= 1 )); then
            break
        fi
        error "Invalid input. Please enter a positive whole number."
    done

    # ── Run mode ─────────────────────────────────────────────
    while true; do
        read -rp "  Enter run mode (live/dry, default live): " MODE_VAL
        MODE_VAL="${MODE_VAL:-live}"
        if [[ "$MODE_VAL" == "live" || "$MODE_VAL" == "dry" ]]; then
            break
        fi
        error "Invalid input. Please enter 'live' or 'dry'."
    done

    # Validate logical ordering of thresholds
    if (( FAILURE_VAL >= WARNING_VAL )); then
        warn "Failure threshold (${FAILURE_VAL}%) must be less than Warning threshold (${WARNING_VAL}%)."
        warn "Keeping defaults (Warning=75, Failure=50)."
    else
        sed -i.bak "s/\"warning\": [0-9]*/\"warning\": ${WARNING_VAL}/" "${HELPERS_DIR}/config.json"
        sed -i.bak "s/\"failure\": [0-9]*/\"failure\": ${FAILURE_VAL}/" "${HELPERS_DIR}/config.json"
        sed -i.bak "s/\"total_sessions\": [0-9]*/\"total_sessions\": ${SESSIONS_VAL}/" "${HELPERS_DIR}/config.json"
        sed -i.bak "s/\"run_mode\": \"[a-z]*\"/\"run_mode\": \"${MODE_VAL}\"/" "${HELPERS_DIR}/config.json"
        rm -f "${HELPERS_DIR}/config.json.bak"

        success "config.json updated:"
        success "  Warning: ${WARNING_VAL}%  |  Failure: ${FAILURE_VAL}%  |  Sessions: ${SESSIONS_VAL}  |  Mode: ${MODE_VAL}"
    fi
else
    info "Keeping default configuration."
fi

# ════════════════════════════════════════════════════════════
#  PHASE 4 — Environment / Health Check
# ════════════════════════════════════════════════════════════
header "Phase 4: Environment Health Check"

# ── Python 3 ─────────────────────────────────────────────────
if python3 --version &>/dev/null; then
    PY_VER=$(python3 --version 2>&1)
    success "Python 3 found: ${PY_VER}"
else
    warn "python3 not found on this system."
    warn "Install it from https://www.python.org/downloads/ before running the tracker."
fi

# ── Directory structure validation ───────────────────────────
info "Verifying directory structure…"
ALL_OK=true
REQUIRED_PATHS=(
    "${PROJECT_DIR}/attendance_checker.py"
    "${HELPERS_DIR}/assets.csv"
    "${HELPERS_DIR}/config.json"
    "${REPORTS_DIR}/reports.log"
)

for path in "${REQUIRED_PATHS[@]}"; do
    if [[ -e "$path" ]]; then
        success "  ✔  ${path}"
    else
        error  "  ✘  MISSING: ${path}"
        ALL_OK=false
    fi
done

if $ALL_OK; then
    success "All required files are in place."
else
    error "Some files are missing — re-run the script to fix."
    exit 1
fi

# ════════════════════════════════════════════════════════════
#  Done
# ════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗"
echo -e "║   Project '${PROJECT_DIR}' is ready!   ║"
echo -e "╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Run the tracker with:"
echo -e "  ${CYAN}cd ${PROJECT_DIR} && python3 attendance_checker.py${NC}"
echo ""
