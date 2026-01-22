# Practice Makes Perfect

Daily DevOps / AWS Cloud Security / AI Engineer interview prep.

## Structure

```
PracticeMakesPerfect/
├── 00-dailytask/                    # Daily tickets
│   ├── task-generator-config.json   # Config for generating new tasks
│   ├── day1.md, day2.md, ...        # Daily ticket simulations
├── 01-myresponses/                  # Your answers
│   ├── TEMPLATE-response.md
│   └── dayN-response.md
├── 02-validation/                   # Claude Code feedback
│   ├── TEMPLATE-validation.md
│   ├── validate_responses.py        # Validation script
│   ├── gaps_to_training.py          # Convert gaps to training data
│   └── dayN-validation.md
└── 03-jadesresponses/               # JADE's answers (for comparison)
    ├── jade_daily_task.py           # JADE answering script
    └── dayN-jade-response.md
```

## Daily Workflow

### Step 1: Get Tasks
```bash
# Tasks are in 00-dailytask/dayN.md
cat 00-dailytask/day2.md
```

### Step 2: You Answer
```bash
cp 01-myresponses/TEMPLATE-response.md 01-myresponses/day2-response.md
# Fill out your responses, time yourself
```

### Step 3: JADE Answers
```bash
cd 03-jadesresponses
python jade_daily_task.py day2
# Creates: day2-jade-response.md
```

### Step 4: Claude Validates Both
```bash
cd 02-validation
python validate_responses.py day2
# Creates: day2-validation-prompt.md
# Copy to Claude Code and ask for validation
```

### Step 5: Generate Training Data from Gaps
```bash
cd 02-validation
python gaps_to_training.py day2
# Creates: day2-training-prompt.md
# Copy to Claude Code to generate training data
# Output: GP-SAGEMAKER/1-GP-GLUE/01-raw-data-lake/YYYYMMDD_gaps-training-day2.jsonl
```

## Scripts

### `jade_daily_task.py` - JADE Responder
```bash
python jade_daily_task.py day2           # Process day2 tasks
python jade_daily_task.py day2 --verbose # With debug output
python jade_daily_task.py day2 --model jade:v0.8  # Different model
```

### `validate_responses.py` - Generate Validation Prompt
```bash
python validate_responses.py day2            # Both user + JADE
python validate_responses.py day2 --user-only
python validate_responses.py day2 --jade-only
python validate_responses.py day2 --output   # Print to stdout
```

### `gaps_to_training.py` - Generate Training Data
```bash
python gaps_to_training.py day2              # Create prompt
python gaps_to_training.py day2 --output     # Print to stdout
```

## Grading Rubric

| Category | Weight |
|----------|--------|
| Technical Accuracy | 40% |
| Completeness | 25% |
| Communication | 20% |
| Security Awareness | 15% |

Passing: 70/100

## Training Data Pipeline

```
Practice Session
      │
      ├─→ Your Response ─────┐
      │                      │
      └─→ JADE Response ─────┼─→ Claude Validates ─→ Gaps Identified
                             │                              │
                             │                              ▼
                             │                    Training Data Generated
                             │                              │
                             ▼                              ▼
                    02-validation/              GP-SAGEMAKER/1-GP-GLUE/
                    dayN-validation.md          01-raw-data-lake/
                                                YYYYMMDD_gaps-training-dayN.jsonl
```

## Quick Start Tomorrow

```bash
# Morning routine
cd PracticeMakesPerfect

# 1. Read today's tickets
cat 00-dailytask/day2.md

# 2. Copy template and answer (2 hours)
cp 01-myresponses/TEMPLATE-response.md 01-myresponses/day2-response.md

# 3. Have JADE answer too
python 03-jadesresponses/jade_daily_task.py day2

# 4. Get Claude to validate both
python 02-validation/validate_responses.py day2
# Then tell Claude: "validate based on the prompt file"

# 5. Generate training data from gaps
python 02-validation/gaps_to_training.py day2
# Then tell Claude: "generate training data from the gaps"
```