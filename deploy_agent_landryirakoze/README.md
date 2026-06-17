# Attendance Tracker — Project Bootstrapper

`setup_project.sh` is a shell script that automates the full setup of the **Student Attendance Tracker** workspace in a single command.

---

## Requirements

| Dependency | Why |
|---|---|
| `bash` 4+ | Script interpreter |
| `python3` | Run the tracker app (detected automatically) |
| `sed` | In-place config updates |
| `tar` | Archive generation on interrupt |

---

## How to Run

```bash
# 1. Make the script executable (first time only)
chmod +x setup_project.sh

# 2. Run it with a project name (letters, digits, _ and - only)
./setup_project.sh cohort_2024
```

This creates the following workspace:

```
attendance_tracker_cohort_2024/
├── attendance_checker.py   ← main application
├── Helpers/
│   ├── assets.csv          ← student attendance data
│   └── config.json         ← thresholds configuration
└── reports/
    └── reports.log         ← output log
```

### Then run the tracker:

```bash
cd attendance_tracker_cohort_2024
python3 attendance_checker.py
```

---

## Dynamic Configuration (Thresholds)

During setup the script asks:

```
Update attendance thresholds? [y/N]:
```

- Enter `y` to set custom **Warning %** and **Failure %** thresholds.
- Input is validated to be a whole number between 1–100.
- The failure threshold must be strictly less than the warning threshold.
- Values are written directly into `Helpers/config.json` using `sed`.
- Press `Enter` to keep defaults (Warning = 75%, Failure = 50%).

---

## Triggering the Archive Feature (SIGINT / Ctrl+C)

If you press **Ctrl+C** at any point during setup, the trap handler activates:

1. The current (incomplete) project directory is bundled into:
   ```
   attendance_tracker_<name>_archive.tar.gz
   ```
2. The incomplete directory is **deleted** to keep your workspace clean.
3. The script exits with code 130.

**To test it:**

```bash
./setup_project.sh test_run
# When prompted for threshold update, press Ctrl+C
```

You will see:

```
[WARN]  Interrupt received — bundling current state before exit…
[OK]    Archive created: attendance_tracker_test_run_archive.tar.gz
[OK]    Incomplete directory 'attendance_tracker_test_run' removed.
Setup aborted by user.
```

To inspect or recover the archived state:

```bash
tar -tzf attendance_tracker_test_run_archive.tar.gz   # list contents
tar -xzf attendance_tracker_test_run_archive.tar.gz   # extract
```

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| No argument supplied | Prints usage and exits |
| Invalid characters in name | Rejects and exits |
| Directory already exists | Rejects and exits (no overwrite) |
| Invalid threshold input | Loops until valid number entered |
| Failure ≥ Warning | Keeps defaults, warns user |
| `python3` not installed | Warns user with install URL, continues |
| Missing files post-creation | Reports which paths are missing, exits non-zero |

---

## Repository Naming Convention

```
deploy_agent_<YourGitHubUsername>
```

Example: `deploy_agent_janedoe`
