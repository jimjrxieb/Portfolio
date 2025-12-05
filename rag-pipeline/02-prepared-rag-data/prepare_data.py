#!/usr/bin/env python3
"""
PREPARE DATA SCRIPT - Meal Prep Station
========================================

Takes raw ingredients from 00-new-rag-data/ and prepares them for cooking.
Like cutting vegetables, measuring ingredients, and getting everything ready.

FLOW:
  00-new-rag-data/  -->  [sanitize, validate, format]  -->  02-prepared-rag-data/

What this does:
  1. DISCOVER - Find all raw files (.md, .txt, .json, .jsonl)
  2. SANITIZE - Clean encoding, remove garbage, fix whitespace
  3. FORMAT   - Standardize structure, extract metadata

Output:
  - Prepared .md files ready for inspection
  - .meta.json sidecar files with metadata

Usage:
  cd rag-pipeline/02-prepared-rag-data
  python prepare_data.py

Author: Jimmie Coleman
Date: 2025-12-05
"""

import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any

# Directories (relative to this script)
SCRIPT_DIR = Path(__file__).parent
PIPELINE_ROOT = SCRIPT_DIR.parent
RAW_DATA_DIR = PIPELINE_ROOT / "00-new-rag-data"
OUTPUT_DIR = SCRIPT_DIR  # Output to same directory as this script

# Supported file types
SUPPORTED_EXTENSIONS = {'.md', '.txt', '.json', '.jsonl'}


def print_header(title: str):
    """Print formatted header"""
    print(f"\n{'='*70}")
    print(f"  {title}")
    print(f"{'='*70}\n")


def print_stage(stage_num: int, stage_name: str):
    """Print stage indicator"""
    print(f"\n{'─'*70}")
    print(f"  STAGE {stage_num}: {stage_name}")
    print(f"{'─'*70}\n")


# =============================================================================
# STAGE 1: DISCOVER - Find raw files
# =============================================================================

def discover_raw_files() -> List[Path]:
    """Find all processable files in raw data directory"""
    if not RAW_DATA_DIR.exists():
        print(f"  !! Raw data directory not found: {RAW_DATA_DIR}")
        return []

    files = []
    for ext in SUPPORTED_EXTENSIONS:
        files.extend(RAW_DATA_DIR.glob(f"*{ext}"))

    return sorted(files)


# =============================================================================
# STAGE 2: SANITIZE - Clean and validate content
# =============================================================================

def sanitize_content(content: str) -> str:
    """
    Sanitize text content:
    - Remove null bytes and control characters
    - Fix encoding issues
    - Normalize whitespace
    - Remove excessive blank lines
    """
    # Remove null bytes and control characters (keep newlines and tabs)
    content = ''.join(char for char in content if ord(char) >= 32 or char in '\n\t')

    # Fix encoding issues
    content = content.encode('utf-8', errors='ignore').decode('utf-8')

    # Remove excessive blank lines (max 2)
    while '\n\n\n' in content:
        content = content.replace('\n\n\n', '\n\n')

    # Strip leading/trailing whitespace
    content = content.strip()

    return content


def validate_content(content: str, filepath: Path) -> Dict[str, Any]:
    """
    Validate content quality

    Returns:
        {
            'valid': bool,
            'status': 'PASS' | 'REPAIR' | 'FAIL',
            'issues': List[str],
            'word_count': int
        }
    """
    issues = []
    status = 'PASS'

    # Check minimum content length
    if len(content) < 50:
        issues.append(f"Content too short ({len(content)} chars)")
        status = 'FAIL'

    # Check for meaningful content
    word_count = len(content.split())
    if word_count < 10:
        issues.append(f"Too few words ({word_count})")
        status = 'FAIL'

    # Check for binary/garbage content
    non_printable = sum(1 for c in content if ord(c) > 127 and c not in 'äöüßéèêëàâîïôûùçñ')
    if non_printable > len(content) * 0.1:  # More than 10% non-printable
        issues.append(f"Possible binary content ({non_printable} non-printable chars)")
        status = 'FAIL'

    # Check for proper structure (markdown)
    if filepath.suffix == '.md':
        if not content.startswith('#') and '# ' not in content[:500]:
            issues.append("Markdown file missing headers")
            if status == 'PASS':
                status = 'REPAIR'  # Not fatal, but noted

    return {
        'valid': status != 'FAIL',
        'status': status,
        'issues': issues,
        'word_count': word_count
    }


# =============================================================================
# STAGE 3: FORMAT - Standardize for RAG ingestion
# =============================================================================

def format_for_rag(content: str, filepath: Path) -> Dict[str, Any]:
    """
    Format content for RAG ingestion

    Returns:
        {
            'content': str,        # Formatted content
            'metadata': dict,      # Metadata for ChromaDB
            'format': str          # Output format
        }
    """
    filename = filepath.name

    # Extract title from markdown headers or filename
    title = filename.replace('.md', '').replace('.txt', '').replace('-', ' ').replace('_', ' ').title()

    # Look for actual title in content
    lines = content.split('\n')
    for line in lines[:5]:
        if line.startswith('# '):
            title = line[2:].strip()
            break

    metadata = {
        'source': filename,
        'title': title,
        'prepared_at': datetime.now().isoformat(),
        'word_count': len(content.split()),
        'char_count': len(content),
        'original_format': filepath.suffix,
        'embedding_model': 'nomic-embed-text',  # Target embedding model
        'embedding_dims': 768
    }

    return {
        'content': content,
        'metadata': metadata,
        'format': 'markdown'
    }


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Run the preparation pipeline"""
    print_header("RAG PIPELINE: PREPARE DATA")
    print("  Taking raw ingredients from 00-new-rag-data/")
    print("  Sanitizing, validating, and formatting for cooking...\n")

    # Stage 1: Discover
    print_stage(1, "DISCOVER - Finding raw files")
    raw_files = discover_raw_files()

    if not raw_files:
        print("  !! No files found in 00-new-rag-data/")
        print(f"     Add .md, .txt, .json, or .jsonl files to: {RAW_DATA_DIR}")
        return

    print(f"  Found {len(raw_files)} files:")
    for f in raw_files:
        print(f"     - {f.name}")

    # Process each file
    stats = {'processed': 0, 'passed': 0, 'failed': 0, 'repaired': 0}

    for filepath in raw_files:
        print_stage(2, f"SANITIZE - {filepath.name}")

        try:
            # Read content
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                raw_content = f.read()

            print(f"  Read {len(raw_content)} chars")

            # Sanitize
            clean_content = sanitize_content(raw_content)
            print(f"  Sanitized: {len(raw_content)} -> {len(clean_content)} chars")

            # Validate
            validation = validate_content(clean_content, filepath)
            print(f"  Validation: {validation['status']} ({validation['word_count']} words)")

            if validation['issues']:
                for issue in validation['issues']:
                    print(f"     !! {issue}")

            if not validation['valid']:
                print(f"  FAILED - Skipping file")
                stats['failed'] += 1
                continue

            # Format for RAG
            print_stage(3, f"FORMAT - {filepath.name}")
            formatted = format_for_rag(clean_content, filepath)
            print(f"  Title: {formatted['metadata']['title']}")
            print(f"  Words: {formatted['metadata']['word_count']}")

            # Write to output directory (02-prepared-rag-data/)
            output_path = OUTPUT_DIR / filepath.name
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(formatted['content'])

            # Write metadata sidecar
            meta_path = OUTPUT_DIR / f"{filepath.stem}.meta.json"
            with open(meta_path, 'w', encoding='utf-8') as f:
                json.dump(formatted['metadata'], f, indent=2)

            print(f"  Saved: {filepath.name}")
            print(f"  Metadata: {filepath.stem}.meta.json")

            stats['processed'] += 1
            if validation['status'] == 'PASS':
                stats['passed'] += 1
            else:
                stats['repaired'] += 1

        except Exception as e:
            print(f"  ERROR processing {filepath.name}: {e}")
            stats['failed'] += 1

    # Summary
    print_header("PREPARATION COMPLETE")
    print(f"  Results:")
    print(f"     Processed: {stats['processed']}")
    print(f"     Passed:    {stats['passed']}")
    print(f"     Repaired:  {stats['repaired']}")
    print(f"     Failed:    {stats['failed']}")
    print(f"\n  Prepared files are in: 02-prepared-rag-data/")
    print(f"  Inspect them, then run: cd ../03-ingest-rag-data && python ingest_data.py")


if __name__ == "__main__":
    main()
