#!/usr/bin/env python3
"""
Stage 1: Discover Files
Find all files in unprocessed/ directories
"""

from pathlib import Path
from typing import Dict, List
import sys

# Add parent directory to path for shared imports
sys.path.insert(0, str(Path(__file__).parent.parent))

def discover_files(base_path: Path = None) -> Dict[str, List[Path]]:
    """
    Scan unprocessed/ for new files to process

    Returns:
        Dictionary of files by category:
        {
            'domain-SME': [Path(...)],
            'projects-docs': [Path(...)],
            ...
        }
    """
    if base_path is None:
        # Default to JADE-HTC/unprocessed
        base_path = Path(__file__).parent.parent.parent / "unprocessed"

    # Categories to scan
    categories = {
        'domain-SME': 'Training data (JSONL Q&A pairs)',
        'projects-docs': 'Project documentation',
        'sessions': 'Session notes and summaries',
        'troubleshooting': 'Debugging guides',
        'sync': 'Security scan results',
        'client-intake': 'People, meetings, reports',
        'windows-sync': 'Windows sync data',
        'chat-session-docs': 'Chat session documentation',
        'session-docs': 'Session documentation',
        'night-learning': 'Night learning notes',
        'agent-research': 'Agent research outputs',
        'meeting-notes': 'Meeting notes',
        'build-sessions': 'Build session documentation',
        'ClaudeCode-session': 'Claude Code session documentation',
        'jade-chat-session': 'Jade chat session documentation'
    }

    discovered = {}

    for category, description in categories.items():
        category_path = base_path / category

        if not category_path.exists():
            discovered[category] = []
            continue

        # Find all files (recursively)
        files = []
        for pattern in ['**/*.jsonl', '**/*.json', '**/*.md', '**/*.txt']:
            files.extend(category_path.glob(pattern))

        # Filter out hidden files and directories
        files = [f for f in files if not any(part.startswith('.') for part in f.parts)]

        discovered[category] = sorted(files)

    return discovered


def print_discovery_report(discovered: Dict[str, List[Path]]):
    """Print summary of discovered files"""
    total_files = sum(len(files) for files in discovered.values())

    print(f"\n📂 Discovery Report")
    print(f"{'='*60}")
    print(f"Total files found: {total_files}")
    print()

    for category, files in discovered.items():
        if files:
            print(f"  {category}/: {len(files)} files")
            for file in files[:3]:  # Show first 3
                print(f"    - {file.name}")
            if len(files) > 3:
                print(f"    ... and {len(files) - 3} more")
            print()

    print(f"{'='*60}\n")


if __name__ == "__main__":
    # Test discovery
    discovered = discover_files()
    print_discovery_report(discovered)
