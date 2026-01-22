#!/usr/bin/env python3
"""
Claude Code Validation Script
Validates both user responses and JADE responses against daily tasks.

Usage:
    python validate_responses.py day2
    python validate_responses.py day2 --user-only
    python validate_responses.py day2 --jade-only

Note: This script generates a validation prompt for Claude Code.
      Run this, then paste the output to Claude Code for validation.
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path


class ResponseValidator:
    """Validates practice responses against task requirements."""

    def __init__(self, day: str):
        self.day = day
        self.base_path = Path(__file__).parent.parent
        self.tasks_path = self.base_path / "00-dailytask"
        self.user_responses_path = self.base_path / "01-myresponses"
        self.jade_responses_path = self.base_path / "03-jadesresponses"
        self.validation_path = self.base_path / "02-validation"

    def load_tasks(self) -> str:
        """Load the day's tasks."""
        task_file = self.tasks_path / f"{self.day}.md"
        if not task_file.exists():
            raise FileNotFoundError(f"Task file not found: {task_file}")
        return task_file.read_text()

    def load_user_response(self) -> str:
        """Load user's response file."""
        # Try common naming patterns
        patterns = [
            f"{self.day}-response.md",
            f"{self.day}-responses.md",
            f"{self.day}fix.md",
            f"{self.day}_response.md"
        ]

        for pattern in patterns:
            response_file = self.user_responses_path / pattern
            if response_file.exists():
                return response_file.read_text()

        # List available files
        available = list(self.user_responses_path.glob(f"{self.day}*.md"))
        if available:
            return available[0].read_text()

        raise FileNotFoundError(f"No user response found for {self.day}")

    def load_jade_response(self) -> str:
        """Load JADE's response file."""
        response_file = self.jade_responses_path / f"{self.day}-jade-response.md"
        if not response_file.exists():
            raise FileNotFoundError(f"JADE response not found: {response_file}")
        return response_file.read_text()

    def generate_validation_prompt(self, include_user: bool = True, include_jade: bool = True) -> str:
        """Generate a prompt for Claude Code to validate responses."""
        tasks = self.load_tasks()

        prompt_parts = [
            "# Validation Request",
            "",
            f"**Day:** {self.day}",
            f"**Date:** {datetime.now().strftime('%Y-%m-%d')}",
            "",
            "## Tasks (Reference)",
            "",
            "```markdown",
            tasks,
            "```",
            "",
        ]

        if include_user:
            try:
                user_response = self.load_user_response()
                prompt_parts.extend([
                    "## User Responses",
                    "",
                    "```markdown",
                    user_response,
                    "```",
                    "",
                ])
            except FileNotFoundError as e:
                prompt_parts.extend([
                    "## User Responses",
                    "",
                    f"**Not found:** {e}",
                    "",
                ])

        if include_jade:
            try:
                jade_response = self.load_jade_response()
                prompt_parts.extend([
                    "## JADE Responses",
                    "",
                    "```markdown",
                    jade_response,
                    "```",
                    "",
                ])
            except FileNotFoundError as e:
                prompt_parts.extend([
                    "## JADE Responses",
                    "",
                    f"**Not found:** {e}",
                    "",
                ])

        prompt_parts.extend([
            "---",
            "",
            "## Validation Instructions",
            "",
            "Please validate the responses above using this rubric:",
            "",
            "| Category | Weight |",
            "|----------|--------|",
            "| Technical Accuracy | 40% |",
            "| Completeness | 25% |",
            "| Communication | 20% |",
            "| Security Awareness | 15% |",
            "",
            "**For each ticket, provide:**",
            "1. Score (0-100)",
            "2. What they got right",
            "3. What they missed",
            "4. Better approach / Tips",
            "5. Grade: Pass / Needs Work",
            "",
            "**At the end, provide:**",
            "- Overall score for User",
            "- Overall score for JADE",
            "- Comparison: Who performed better and why",
            "- Training gaps identified (for JADE improvement)",
            "",
            f"Save the validation to: {self.validation_path / f'{self.day}-validation.md'}",
        ])

        return "\n".join(prompt_parts)

    def save_validation_prompt(self, include_user: bool = True, include_jade: bool = True) -> Path:
        """Save the validation prompt to a file."""
        prompt = self.generate_validation_prompt(include_user, include_jade)

        output_file = self.validation_path / f"{self.day}-validation-prompt.md"
        output_file.write_text(prompt)

        return output_file


def main():
    parser = argparse.ArgumentParser(description="Generate validation prompt for Claude Code")
    parser.add_argument("day", help="Day to validate (e.g., day2)")
    parser.add_argument("--user-only", action="store_true", help="Only validate user responses")
    parser.add_argument("--jade-only", action="store_true", help="Only validate JADE responses")
    parser.add_argument("--output", "-o", action="store_true", help="Print prompt to stdout")

    args = parser.parse_args()

    validator = ResponseValidator(args.day)

    include_user = not args.jade_only
    include_jade = not args.user_only

    try:
        if args.output:
            print(validator.generate_validation_prompt(include_user, include_jade))
        else:
            output_file = validator.save_validation_prompt(include_user, include_jade)
            print(f"Validation prompt saved to: {output_file}")
            print(f"\nNext steps:")
            print(f"1. Open {output_file}")
            print(f"2. Copy contents to Claude Code")
            print(f"3. Ask Claude to validate and save to {validator.validation_path / f'{args.day}-validation.md'}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
