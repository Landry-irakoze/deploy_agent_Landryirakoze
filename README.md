# deploy_agent_Landryirakoze
## Student Attendance Tracker — Automated Project Bootstrapper

`setup_project.sh` is a shell script that builds the entire **Student Attendance Tracker** workspace automatically in one command — creating folders, generating all files, updating configuration, and validating the environment.

---

## Project Structure Created by the Script

```
attendance_tracker_{name}/
├── attendance_checker.py     ← main Python application
├── Helpers/
│   ├── assets.csv            ← student data (Names, Email, Attendance Count)
│   └── config.json           ← thresholds, run mode, total sessions
└── reports/
    └── reports.log           ← output alert log
```

---

## How to Run the Script

### Step 1 — Make it executable (first time only)
```bash
chmod +x setup_project.sh
```

### Step 2 — Run it with a project name
```bash
./setup_project.sh cohort_2024
```
Only letters, numbers, underscores and hyphens are allowed in the name.

### Step 3 — Answer the prompts
The script will ask if you want to update the attendance thresholds:
- **Warning %** — students below this get a WARNING alert (default: 75)
- **Failure %** — students below this get an URGENT alert (default: 50)
- **Total sessions** — total number of classes held (default: 15)
- **Run mode** — type `live` to write alerts to the log, or `dry` to preview only

Press **Enter** on each to keep the defaults.

### Step 4 — Run the tracker app
```bash
cd attendance_tracker_cohort_2024
python3 attendance_checker.py
```

---

## How the Config File Works

The script uses `sed` to edit `Helpers/config.json` in-place. The file controls:

```json
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
```

| Setting | Meaning |
|---|---|
| `warning` | Attendance % below this triggers a WARNING message |
| `failure` | Attendance % below this triggers an URGENT FAIL message |
| `run_mode` | `live` = write alerts to log file. `dry` = only print to screen |
| `total_sessions` | Total number of classes held in the semester |

---

## How the Attendance Checker Works

The Python app reads `assets.csv` which contains:

| Column | Description |
|---|---|
| `Email` | Student email address |
| `Names` | Student full name |
| `Attendance Count` | Number of classes attended |
| `Absence Count` | Number of classes missed |

It calculates each student's attendance percentage:
```
attendance % = (Attendance Count / total_sessions) × 100
```

Then compares it to the thresholds:
- **Below failure %** → URGENT alert
- **Below warning % but above failure %** → WARNING alert
- **Above warning %** → No alert (student is fine)

Results are saved to `reports/reports.log`.

---

## How to Trigger the Archive Feature (Ctrl+C)

If you press **Ctrl+C** at any point during setup, the script catches the signal and:

1. Bundles everything created so far into a compressed archive:
   ```
   attendance_tracker_{name}_archive.tar.gz
   ```
2. Deletes the incomplete project folder to keep your workspace clean
3. Exits safely

### To test it:
```bash
./setup_project.sh testarchive
```
When it asks **"Update attendance thresholds? [y/N]:"** — press **Ctrl+C**

You will see:
```
[WARN]  Interrupt received — bundling current state before exit…
[OK]    Archive created: attendance_tracker_testarchive_archive.tar.gz
[OK]    Incomplete directory 'attendance_tracker_testarchive' removed.
Setup aborted by user.
```

### To recover the archived files:
```bash
tar -xzf attendance_tracker_testarchive_archive.tar.gz
```

---

## Environment Health Check

Before finishing, the script automatically:
- Runs `python3 --version` to confirm Python 3 is installed
- Verifies all 4 required files exist in the correct locations
- Reports success or failure for each check

---

## Error Handling

| Situation | What happens |
|---|---|
| No project name given | Prints usage instructions and exits |
| Invalid characters in name | Rejects the name and exits |
| Directory already exists | Stops to prevent overwriting existing work |
| Non-numeric threshold input | Loops and asks again until valid |
| Failure % ≥ Warning % | Keeps defaults and warns the user |
| Python 3 not installed | Warns user with download link, continues setup |
| Missing files after creation | Lists which files are missing and exits |

---

## Requirements

- `bash` 4+
- `python3` (any version 3.x)
- `sed`, `tar` (built into macOS and Linux)

---

## Author
Landry Rwema Irakoze  
GitHub: [Landry-irakoze](https://github.com/Landry-irakoze)
