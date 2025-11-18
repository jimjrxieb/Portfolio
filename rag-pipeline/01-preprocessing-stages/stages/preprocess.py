#!/usr/bin/env python3
"""
Stage 2: Preprocess Files
Validate, parse, and convert file formats
"""

from pathlib import Path
from typing import Dict, Any, Optional
import json
import sys

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

# Import validators
try:
    from stages.validators import FormatValidator
    HAS_VALIDATORS = True
except ImportError:
    HAS_VALIDATORS = False

def preprocess_file(file_path: Path, category: str) -> Optional[Dict[str, Any]]:
    """
    Preprocess a single file based on its type and category

    Returns:
        {
            'file': Path,
            'category': str,
            'format': str,
            'data': Any,
            'valid': bool,
            'error': Optional[str],
            'formatted_data': Any,  # Cleaned/validated data
            'validation_warnings': List[str]
        }
    """
    try:
        # Determine file type
        suffix = file_path.suffix.lower()

        if suffix == '.jsonl':
            data = parse_jsonl(file_path)
            valid = validate_jsonl_structure(data)

        elif suffix == '.json':
            data = parse_json(file_path)
            valid = validate_json_structure(data, category)

        elif suffix in ['.md', '.txt']:
            data = parse_text(file_path)
            valid = bool(data.strip())

        else:
            return {
                'file': file_path,
                'category': category,
                'format': suffix,
                'data': None,
                'valid': False,
                'error': f'Unsupported file type: {suffix}'
            }

        result = {
            'file': file_path,
            'category': category,
            'format': suffix,
            'data': data,
            'valid': valid,
            'error': None
        }

        # Run format validators if available
        if HAS_VALIDATORS and valid:
            validator = FormatValidator()
            validation_result = validator.validate_all(data, suffix, category)

            result['formatted_data'] = validation_result['formatted']
            result['validation_warnings'] = validation_result['warnings']

            if not validation_result['valid']:
                result['valid'] = False
                result['error'] = '; '.join(validation_result['errors'])
        else:
            result['formatted_data'] = data
            result['validation_warnings'] = []

        return result

    except Exception as e:
        return {
            'file': file_path,
            'category': category,
            'format': file_path.suffix,
            'data': None,
            'valid': False,
            'error': str(e),
            'formatted_data': None,
            'validation_warnings': []
        }


def parse_jsonl(file_path: Path) -> list:
    """Parse JSONL file (one JSON object per line)"""
    data = []
    with open(file_path, 'r', encoding='utf-8') as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                data.append(obj)
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON on line {line_num}: {e}")
    return data


def parse_json(file_path: Path) -> Any:
    """Parse JSON file"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def parse_text(file_path: Path) -> str:
    """Parse text/markdown file"""
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        return f.read()


def validate_jsonl_structure(data: list) -> bool:
    """
    Validate JSONL structure for training and knowledge data

    Accepts any JSON object (dict) with at least 2 keys and some meaningful content.
    This lenient validation allows diverse knowledge formats while filtering out
    empty or malformed data.

    Common formats include:
    - Training: {"messages": [...]}
    - Instruction: {"instruction": "...", "output": "..."}
    - Q&A: {"question": "...", "answer": "..."}
    - Documents: {"doc_id": "...", "text": "..."}
    - Troubleshooting: {"problem": "...", "solution": "..."}
    - Entities: {"entity_id": "...", "type": "..."}
    - Relationships: {"head": "...", "relation": "...", "tail": "..."}
    - And many more...
    """
    if not data:
        return False

    for item in data:
        # Must be a dictionary
        if not isinstance(item, dict):
            return False

        # Must have at least one key
        if len(item) < 1:
            return False

        # Must have at least one non-empty value (meaningful content)
        has_content = False
        for value in item.values():
            if isinstance(value, str) and value.strip():
                has_content = True
                break
            elif isinstance(value, (list, dict)) and value:
                has_content = True
                break

        if not has_content:
            return False

    return True


def validate_json_structure(data: Any, category: str) -> bool:
    """
    Validate JSON structure based on category

    For scan results (category='sync'):
        - Should have 'findings' or 'results' key
        - Should have 'metadata' key
    """
    if category == 'sync':
        # Scan results validation
        if isinstance(data, dict):
            has_findings = 'findings' in data or 'results' in data
            has_metadata = 'metadata' in data
            return has_findings or has_metadata
        return False

    # General JSON validation (just check it's valid JSON)
    return data is not None


def preprocess_batch(discovered: Dict[str, list]) -> list:
    """Preprocess all discovered files"""
    preprocessed = []

    for category, files in discovered.items():
        for file_path in files:
            result = preprocess_file(file_path, category)
            if result:
                preprocessed.append(result)

    return preprocessed


if __name__ == "__main__":
    # Test preprocessing
    from pathlib import Path
    import sys
    sys.path.insert(0, str(Path(__file__).parent))
    from stages import discover

    discovered = discover.discover_files()
    preprocessed = preprocess_batch(discovered)

    print(f"\n🔧 Preprocessing Report")
    print(f"{'='*60}")
    print(f"Files preprocessed: {len(preprocessed)}")
    print(f"Valid: {sum(1 for p in preprocessed if p['valid'])}")
    print(f"Invalid: {sum(1 for p in preprocessed if not p['valid'])}")
    print(f"{'='*60}\n")

    # Show errors
    errors = [p for p in preprocessed if not p['valid']]
    if errors:
        print("❌ Errors:")
        for item in errors[:5]:
            print(f"  - {item['file'].name}: {item['error']}")
