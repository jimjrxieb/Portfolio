#!/usr/bin/env python3
"""
Gaps to Training Data Converter
Analyzes validation files and generates training data from identified gaps.

Usage:
    python gaps_to_training.py day2
    python gaps_to_training.py day2 --output

Note: This script generates a prompt for Claude Code to create training data.
      The training data corrects JADE's gaps with proper "code-first" examples.
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


class GapsToTrainingConverter:
    """Converts validation gaps into JADE training data."""

    def __init__(self, day: str):
        self.day = day
        self.base_path = Path(__file__).parent.parent
        self.tasks_path = self.base_path / "00-dailytask"
        self.validation_path = self.base_path / "02-validation"
        self.jade_responses_path = self.base_path / "03-jadesresponses"
        self.user_responses_path = self.base_path / "01-myresponses"
        self.training_output_path = Path("/home/jimmie/linkops-industries/GP-copilot/GP-SAGEMAKER/1-GP-GLUE/01-raw-data-lake")

    def load_validation(self) -> str:
        """Load the validation file."""
        validation_file = self.validation_path / f"{self.day}-validation.md"
        if not validation_file.exists():
            raise FileNotFoundError(f"Validation not found: {validation_file}")
        return validation_file.read_text()

    def load_tasks(self) -> str:
        """Load the original tasks."""
        task_file = self.tasks_path / f"{self.day}.md"
        if not task_file.exists():
            raise FileNotFoundError(f"Tasks not found: {task_file}")
        return task_file.read_text()

    def load_jade_response(self) -> str:
        """Load JADE's response."""
        try:
            response_file = self.jade_responses_path / f"{self.day}-jade-response.md"
            return response_file.read_text()
        except:
            return "JADE response not available"

    def load_user_response(self) -> str:
        """Load user's response for reference (correct answers)."""
        patterns = [
            f"{self.day}-response.md",
            f"{self.day}-responses.md",
            f"{self.day}fix.md"
        ]
        for pattern in patterns:
            response_file = self.user_responses_path / pattern
            if response_file.exists():
                return response_file.read_text()
        return "User response not available"

    def generate_training_prompt(self) -> str:
        """Generate prompt for Claude Code to create training data from gaps."""
        validation = self.load_validation()
        tasks = self.load_tasks()
        jade_response = self.load_jade_response()
        user_response = self.load_user_response()

        prompt = f"""# Training Data Generation Request

**Day:** {self.day}
**Date:** {datetime.now().strftime('%Y-%m-%d')}
**Output Path:** {self.training_output_path}

## Context

You are analyzing JADE's performance gaps to generate training data that will improve JADE v0.10.

## Validation Results (Gaps Identified)

```markdown
{validation}
```

## Original Tasks

```markdown
{tasks}
```

## JADE's Responses (What JADE Actually Said)

```markdown
{jade_response}
```

## User's Responses (Reference for Correct Answers)

```markdown
{user_response}
```

---

## Training Data Generation Instructions

For each gap identified in the validation, create a training example that teaches JADE the correct behavior.

### Format (JSONL)

Each line should be a JSON object:

```json
{{"instruction": "What to do", "input": "Context/scenario", "output": "CODE FIRST, then brief explanation", "metadata": {{"domain": "...", "task_type": "...", "skill_level": "...", "source": "practice-{self.day}"}}}}
```

### Rules

1. **Code First** - Output must start with code block, explanation after
2. **Complete** - Include ALL deliverables asked for in the ticket
3. **Concise** - Keep explanations to 1-2 sentences
4. **Correct** - Use the validation feedback and user responses as reference
5. **Varied** - Create multiple examples per gap (different angles)

### Gap Categories to Address

1. **Missing Code** - JADE explained but didn't provide working code
2. **Incomplete Deliverables** - JADE missed some requested items
3. **Wrong Format** - JADE over-explained instead of code-first
4. **Incorrect Solution** - JADE's answer was technically wrong

### Output

Create a file: `{self.training_output_path / f'{datetime.now().strftime("%Y%m%d")}_gaps-training-{self.day}.jsonl'}`

Generate 10-20 training examples from the identified gaps.

### Example Training Entry

```json
{{"instruction": "Fix Kubernetes OOMKilled error", "input": "Pod in CrashLoopBackOff, exit code 137, resources: {{}}", "output": "```yaml\\nresources:\\n  requests:\\n    memory: \\"256Mi\\"\\n  limits:\\n    memory: \\"512Mi\\"\\n```\\n\\n**Why:** Exit 137 = OOM. Add limits to prevent kernel kill.", "metadata": {{"domain": "kubernetes", "task_type": "troubleshooting", "skill_level": "D-rank", "source": "practice-{self.day}"}}}}
```

Now generate the training data based on the gaps identified above.
"""
        return prompt

    def save_training_prompt(self) -> Path:
        """Save the training generation prompt."""
        prompt = self.generate_training_prompt()

        output_file = self.validation_path / f"{self.day}-training-prompt.md"
        output_file.write_text(prompt)

        return output_file


def main():
    parser = argparse.ArgumentParser(description="Generate training data from validation gaps")
    parser.add_argument("day", help="Day to process (e.g., day2)")
    parser.add_argument("--output", "-o", action="store_true", help="Print prompt to stdout")

    args = parser.parse_args()

    converter = GapsToTrainingConverter(args.day)

    try:
        if args.output:
            print(converter.generate_training_prompt())
        else:
            output_file = converter.save_training_prompt()
            print(f"Training prompt saved to: {output_file}")
            print(f"\nNext steps:")
            print(f"1. Open {output_file}")
            print(f"2. Copy contents to Claude Code")
            print(f"3. Ask Claude to generate training data")
            print(f"4. Training data will be saved to: {converter.training_output_path}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
