
set -euo pipefail


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

# Reject names with spaces or special characters
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
            || warn "Archiving failed (partial directory may be missing files)."

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
#!/usr/bin/env python3
"""Student Attendance Tracker — main application logic."""

import json
import csv
import os
from datetime import datetime

CONFIG_PATH  = os.path.join(os.path.dirname(__file__), "Helpers", "config.json")
ASSETS_PATH  = os.path.join(os.path.dirname(__file__), "Helpers", "assets.csv")
REPORTS_PATH = os.path.join(os.path.dirname(__file__), "reports", "reports.log")


def load_config():
    with open(CONFIG_PATH) as f:
        return json.load(f)


def load_students():
    students = []
    with open(ASSETS_PATH, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            students.append(row)
    return students


def evaluate_attendance(student, config):
    attended  = int(student["classes_attended"])
    total     = int(student["total_classes"])
    pct       = (attended / total * 100) if total > 0 else 0
    warning   = config["thresholds"]["warning_percentage"]
    failure   = config["thresholds"]["failure_percentage"]

    if pct >= warning:
        status = "PASS"
    elif pct >= failure:
        status = "WARNING"
    else:
        status = "FAIL"

    return round(pct, 2), status


def write_report(lines):
    os.makedirs(os.path.dirname(REPORTS_PATH), exist_ok=True)
    with open(REPORTS_PATH, "a") as f:
        f.write(f"\n--- Report Generated: {datetime.now().isoformat()} ---\n")
        for line in lines:
            f.write(line + "\n")


def main():
    config   = load_config()
    students = load_students()
    report   = []

    print(f"\n{'='*50}")
    print(f"  Student Attendance Tracker")
    print(f"  Warning threshold : {config['thresholds']['warning_percentage']}%")
    print(f"  Failure threshold : {config['thresholds']['failure_percentage']}%")
    print(f"{'='*50}\n")

    for s in students:
        pct, status = evaluate_attendance(s, config)
        line = f"{s['student_name']:<20} | {pct:>6.2f}% | {status}"
        print(line)
        report.append(line)

    write_report(report)
    print(f"\nReport appended to: {REPORTS_PATH}")


if __name__ == "__main__":
    main()
PYEOF
success "Created attendance_checker.py"

# ── assets.csv ───────────────────────────────────────────────
cat > "${HELPERS_DIR}/assets.csv" << 'CSVEOF'
student_name,classes_attended,total_classes
Alice Johnson,38,40
Bob Martinez,28,40
Carol White,35,40
David Lee,18,40
Eva Chen,40,40
Frank Brown,22,40
Grace Kim,31,40
Henry Davis,10,40
CSVEOF
success "Created Helpers/assets.csv"

# ── config.json ──────────────────────────────────────────────
cat > "${HELPERS_DIR}/config.json" << 'JSONEOF'
{
  "thresholds": {
    "warning_percentage": 75,
    "failure_percentage": 50
  },
  "app": {
    "name": "Student Attendance Tracker",
    "version": "1.0.0"
  }
}
JSONEOF
success "Created Helpers/config.json"

# ── reports.log ──────────────────────────────────────────────
cat > "${REPORTS_DIR}/reports.log" << 'LOGEOF'
# Attendance Tracker — Log File
# Created by setup_project.sh
LOGEOF
success "Created reports/reports.log"

# ════════════════════════════════════════════════════════════
#  PHASE 3 — Dynamic configuration via sed
# ════════════════════════════════════════════════════════════
header "Phase 3: Dynamic Configuration"

echo -e "Current defaults → Warning: ${YELLOW}75%${NC}  |  Failure: ${YELLOW}50%${NC}"
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

    # Validate logical ordering
    if (( FAILURE_VAL >= WARNING_VAL )); then
        warn "Failure threshold (${FAILURE_VAL}%) must be less than Warning threshold (${WARNING_VAL}%)."
        warn "Keeping defaults (Warning=75, Failure=50)."
    else
        # Perform in-place sed substitution (portable: works on Linux & macOS)
        sed -i.bak \
            "s/\"warning_percentage\": [0-9]*/\"warning_percentage\": ${WARNING_VAL}/" \
            "${HELPERS_DIR}/config.json"
        sed -i.bak \
            "s/\"failure_percentage\": [0-9]*/\"failure_percentage\": ${FAILURE_VAL}/" \
            "${HELPERS_DIR}/config.json"
        rm -f "${HELPERS_DIR}/config.json.bak"

        success "config.json updated → Warning: ${WARNING_VAL}%  |  Failure: ${FAILURE_VAL}%"
    fi
else
    info "Keeping default thresholds (Warning=75%, Failure=50%)."
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
