#!/usr/bin/env python3
"""
RAG PREPARATION SCRIPT (Stage 1) - Best Practices Edition
==========================================================

Prepares raw documents for RAG ingestion using industry best practices:
- Semantic chunking with configurable overlap
- Token counting (not just characters)
- Content deduplication via hashing
- Proper encoding detection and fixing
- Metadata preservation for traceability
- Auto-moves raw files to processed after preparation

FLOW:
  00-new-rag-data/*.md,json,jsonl,txt  -->  [chunk, sanitize, dedupe]
                                       -->  02-prepared-rag-data/prepared_{timestamp}.jsonl
                                       -->  [move raw]  -->  04-processed-rag-data/

Output:
  - prepared_{timestamp}.jsonl  (all chunks in JSONL format, timestamped)
  - chunk_manifest.json         (metadata about the preparation run)

Usage:
  cd rag-pipeline/02-prepared-rag-data
  pip install -r ../requirements.txt
  python prepare_data.py

  # With custom settings:
  python prepare_data.py --chunk-size 512 --overlap 50 --verbose

After this script runs:
  1. Review the prepared JSONL in 02-prepared-rag-data/
  2. When ready, run: cd ../03-ingest-rag-data && python ingest_data.py

Author: Jimmie Coleman
Date: 2026-01-05 (Rewritten with RAG best practices)
Updated: 2026-01-07 (Timestamped output, auto-move to processed)
"""

import json
import hashlib
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple
from dataclasses import dataclass, field, asdict

# =============================================================================
# Dependency imports with graceful fallbacks
# =============================================================================

try:
    from langchain_text_splitters import RecursiveCharacterTextSplitter
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("Warning: langchain-text-splitters not installed. Using basic splitting.")

try:
    import tiktoken
    TIKTOKEN_AVAILABLE = True
except ImportError:
    TIKTOKEN_AVAILABLE = False
    print("Warning: tiktoken not installed. Using word-based token estimation.")

try:
    import ftfy
    FTFY_AVAILABLE = True
except ImportError:
    FTFY_AVAILABLE = False
    print("Warning: ftfy not installed. Using basic encoding fixes.")

try:
    import chardet
    CHARDET_AVAILABLE = True
except ImportError:
    CHARDET_AVAILABLE = False
    print("Warning: chardet not installed. Assuming UTF-8 encoding.")

try:
    import nltk
    from nltk.tokenize import sent_tokenize
    # Download punkt tokenizer if not present
    try:
        nltk.data.find('tokenizers/punkt')
    except LookupError:
        nltk.download('punkt', quiet=True)
    try:
        nltk.data.find('tokenizers/punkt_tab')
    except LookupError:
        nltk.download('punkt_tab', quiet=True)
    NLTK_AVAILABLE = True
except ImportError:
    NLTK_AVAILABLE = False
    print("Warning: nltk not installed. Using basic sentence splitting.")


# =============================================================================
# Configuration
# =============================================================================

@dataclass
class PrepConfig:
    """Configuration for the preparation pipeline"""
    # Chunking settings
    chunk_size: int = 512          # Target tokens per chunk
    chunk_overlap: int = 50        # Overlap tokens between chunks
    min_chunk_size: int = 100      # Minimum tokens to keep a chunk

    # Model settings (for token counting)
    tokenizer_model: str = "cl100k_base"  # OpenAI tokenizer (works for most models)
    target_embedding_model: str = "nomic-embed-text"
    embedding_dims: int = 768
    max_tokens: int = 8192         # Max tokens for embedding model

    # Processing settings
    deduplicate: bool = True       # Remove duplicate chunks
    preserve_headers: bool = True  # Keep markdown headers with chunks
    verbose: bool = False


# =============================================================================
# Data Classes
# =============================================================================

@dataclass
class Chunk:
    """A prepared chunk ready for embedding"""
    chunk_id: str                  # Unique ID (hash of content)
    content: str                   # The actual text
    token_count: int               # Number of tokens
    char_count: int                # Number of characters

    # Source tracking
    source_file: str               # Original filename
    source_title: str              # Document title
    chunk_index: int               # Position in source document
    total_chunks: int              # Total chunks from this document

    # Metadata
    created_at: str                # ISO timestamp
    content_hash: str              # SHA256 for deduplication


@dataclass
class PrepStats:
    """Statistics from a preparation run"""
    files_processed: int = 0
    files_failed: int = 0
    total_chunks: int = 0
    duplicate_chunks_removed: int = 0
    total_tokens: int = 0
    avg_chunk_size: float = 0.0
    processing_time_seconds: float = 0.0


# =============================================================================
# Directories
# =============================================================================

SCRIPT_DIR = Path(__file__).parent
PIPELINE_ROOT = SCRIPT_DIR.parent
RAW_DATA_DIR = PIPELINE_ROOT / "00-new-rag-data"
OUTPUT_DIR = SCRIPT_DIR
PROCESSED_DIR = PIPELINE_ROOT / "04-processed-rag-data"

SUPPORTED_EXTENSIONS = {'.md', '.txt', '.json', '.jsonl'}


# =============================================================================
# Token Counting
# =============================================================================

class TokenCounter:
    """Count tokens using tiktoken or fallback to word estimation"""

    def __init__(self, model: str = "cl100k_base"):
        self.model = model
        self._encoder = None

        if TIKTOKEN_AVAILABLE:
            try:
                self._encoder = tiktoken.get_encoding(model)
            except Exception:
                # Fall back to cl100k_base if model not found
                self._encoder = tiktoken.get_encoding("cl100k_base")

    def count(self, text: str) -> int:
        """Count tokens in text"""
        if self._encoder:
            return len(self._encoder.encode(text))
        else:
            # Rough estimation: ~4 characters per token for English
            return len(text) // 4

    def truncate_to_tokens(self, text: str, max_tokens: int) -> str:
        """Truncate text to fit within token limit"""
        if self._encoder:
            tokens = self._encoder.encode(text)
            if len(tokens) <= max_tokens:
                return text
            return self._encoder.decode(tokens[:max_tokens])
        else:
            # Rough estimation
            max_chars = max_tokens * 4
            return text[:max_chars]


# =============================================================================
# Text Sanitization
# =============================================================================

def detect_encoding(filepath: Path) -> str:
    """Detect file encoding"""
    if CHARDET_AVAILABLE:
        with open(filepath, 'rb') as f:
            raw = f.read(10000)  # Read first 10KB
            result = chardet.detect(raw)
            return result.get('encoding', 'utf-8') or 'utf-8'
    return 'utf-8'


def sanitize_text(text: str) -> str:
    """
    Sanitize text content using best practices:
    - Fix encoding issues (mojibake, etc.)
    - Remove null bytes and control characters
    - Normalize whitespace
    - Remove excessive blank lines
    """
    # Fix encoding issues (mojibake like "â€™" -> "'")
    if FTFY_AVAILABLE:
        text = ftfy.fix_text(text)

    # Remove null bytes and control characters (keep newlines, tabs)
    text = ''.join(char for char in text if ord(char) >= 32 or char in '\n\t\r')

    # Normalize line endings
    text = text.replace('\r\n', '\n').replace('\r', '\n')

    # Remove excessive blank lines (max 2 consecutive)
    while '\n\n\n' in text:
        text = text.replace('\n\n\n', '\n\n')

    # Strip leading/trailing whitespace
    text = text.strip()

    return text


def extract_title(content: str, filename: str) -> str:
    """Extract document title from content or filename"""
    # Try to find markdown H1 header
    for line in content.split('\n')[:10]:
        line = line.strip()
        if line.startswith('# '):
            return line[2:].strip()

    # Fall back to filename
    title = filename.replace('.md', '').replace('.txt', '')
    title = title.replace('-', ' ').replace('_', ' ')
    return title.title()


# =============================================================================
# Chunking
# =============================================================================

def create_text_splitter(config: PrepConfig) -> Any:
    """Create a text splitter based on available libraries"""

    if LANGCHAIN_AVAILABLE:
        # Use LangChain's recursive splitter - best for semantic chunking
        return RecursiveCharacterTextSplitter(
            chunk_size=config.chunk_size * 4,  # Convert tokens to ~chars
            chunk_overlap=config.chunk_overlap * 4,
            length_function=len,
            separators=[
                "\n## ",      # Markdown H2
                "\n### ",     # Markdown H3
                "\n#### ",    # Markdown H4
                "\n\n",       # Paragraphs
                "\n",         # Lines
                ". ",         # Sentences
                ", ",         # Clauses
                " ",          # Words
                ""            # Characters
            ],
            keep_separator=True
        )
    else:
        return None


def split_by_sentences(text: str) -> List[str]:
    """Split text into sentences using NLTK or basic splitting"""
    if NLTK_AVAILABLE:
        try:
            return sent_tokenize(text)
        except Exception:
            pass

    # Basic sentence splitting
    import re
    sentences = re.split(r'(?<=[.!?])\s+', text)
    return [s.strip() for s in sentences if s.strip()]


def chunk_document(
    content: str,
    config: PrepConfig,
    token_counter: TokenCounter
) -> List[Tuple[str, int]]:
    """
    Chunk a document into semantic pieces with overlap.

    Returns:
        List of (chunk_text, token_count) tuples
    """
    splitter = create_text_splitter(config)

    if splitter:
        # Use LangChain splitter
        raw_chunks = splitter.split_text(content)
    else:
        # Fallback: split by paragraphs, then combine to target size
        paragraphs = content.split('\n\n')
        raw_chunks = []
        current_chunk = ""

        for para in paragraphs:
            para = para.strip()
            if not para:
                continue

            test_chunk = current_chunk + "\n\n" + para if current_chunk else para
            test_tokens = token_counter.count(test_chunk)

            if test_tokens > config.chunk_size and current_chunk:
                raw_chunks.append(current_chunk)
                current_chunk = para
            else:
                current_chunk = test_chunk

        if current_chunk:
            raw_chunks.append(current_chunk)

    # Filter and count tokens
    chunks_with_tokens = []
    for chunk in raw_chunks:
        chunk = chunk.strip()
        if not chunk:
            continue

        token_count = token_counter.count(chunk)

        # Skip chunks that are too small
        if token_count < config.min_chunk_size:
            continue

        # Truncate chunks that are too large
        if token_count > config.max_tokens:
            chunk = token_counter.truncate_to_tokens(chunk, config.max_tokens)
            token_count = token_counter.count(chunk)

        chunks_with_tokens.append((chunk, token_count))

    return chunks_with_tokens


# =============================================================================
# Deduplication
# =============================================================================

def content_hash(text: str) -> str:
    """Generate SHA256 hash of content for deduplication"""
    # Normalize whitespace for consistent hashing
    normalized = ' '.join(text.split())
    return hashlib.sha256(normalized.encode('utf-8')).hexdigest()[:16]


# =============================================================================
# Main Processing
# =============================================================================

def process_file(
    filepath: Path,
    config: PrepConfig,
    token_counter: TokenCounter,
    seen_hashes: set
) -> Tuple[List[Chunk], int]:
    """
    Process a single file into chunks.

    Returns:
        (list of Chunk objects, number of duplicates removed)
    """
    # Detect and read with proper encoding
    encoding = detect_encoding(filepath)

    try:
        with open(filepath, 'r', encoding=encoding, errors='replace') as f:
            raw_content = f.read()
    except Exception as e:
        print(f"  Error reading {filepath.name}: {e}")
        return [], 0

    # Handle JSONL files (training data format)
    if filepath.suffix == '.jsonl':
        chunks = []
        duplicates = 0

        for line_num, line in enumerate(raw_content.split('\n')):
            line = line.strip()
            if not line:
                continue

            try:
                data = json.loads(line)
                # Extract content from common JSONL formats
                # Handle Q&A format (question/answer pairs for RAG)
                if 'question' in data and 'answer' in data:
                    text = f"Q: {data['question']}\n\nA: {data['answer']}"
                # Handle instruction/output format (fine-tuning format)
                elif 'instruction' in data and 'output' in data:
                    instruction = data['instruction']
                    if data.get('input'):
                        instruction = f"{instruction}\n{data['input']}"
                    text = f"Q: {instruction}\n\nA: {data['output']}"
                else:
                    text = data.get('content') or data.get('text') or data.get('output') or str(data)
                text = sanitize_text(text)

                if len(text) < 50:
                    continue

                chunk_hash = content_hash(text)
                if config.deduplicate and chunk_hash in seen_hashes:
                    duplicates += 1
                    continue
                seen_hashes.add(chunk_hash)

                token_count = token_counter.count(text)

                # Use question/instruction as title for Q&A pairs, otherwise fall back to title field or filename
                if 'question' in data:
                    title = data['question'][:80] + ('...' if len(data['question']) > 80 else '')
                elif 'instruction' in data:
                    title = data['instruction'][:80] + ('...' if len(data['instruction']) > 80 else '')
                else:
                    title = data.get('title', filepath.stem)

                chunk = Chunk(
                    chunk_id=f"{filepath.stem}_{line_num}_{chunk_hash[:8]}",
                    content=text,
                    token_count=token_count,
                    char_count=len(text),
                    source_file=filepath.name,
                    source_title=title,
                    chunk_index=line_num,
                    total_chunks=-1,  # Unknown for JSONL
                    created_at=datetime.now().isoformat(),
                    content_hash=chunk_hash
                )
                chunks.append(chunk)

            except json.JSONDecodeError:
                continue

        return chunks, duplicates

    # Handle regular text/markdown files
    content = sanitize_text(raw_content)

    if len(content) < 50:
        print(f"  Skipping {filepath.name}: too short ({len(content)} chars)")
        return [], 0

    title = extract_title(content, filepath.name)

    # Chunk the document
    chunk_tuples = chunk_document(content, config, token_counter)

    if not chunk_tuples:
        print(f"  Warning: No chunks generated from {filepath.name}")
        return [], 0

    # Create Chunk objects with deduplication
    chunks = []
    duplicates = 0

    for idx, (chunk_text, token_count) in enumerate(chunk_tuples):
        chunk_hash = content_hash(chunk_text)

        # Deduplicate
        if config.deduplicate and chunk_hash in seen_hashes:
            duplicates += 1
            continue
        seen_hashes.add(chunk_hash)

        chunk = Chunk(
            chunk_id=f"{filepath.stem}_{idx}_{chunk_hash[:8]}",
            content=chunk_text,
            token_count=token_count,
            char_count=len(chunk_text),
            source_file=filepath.name,
            source_title=title,
            chunk_index=idx,
            total_chunks=len(chunk_tuples),
            created_at=datetime.now().isoformat(),
            content_hash=chunk_hash
        )
        chunks.append(chunk)

    return chunks, duplicates


def main():
    """Run the preparation pipeline"""
    parser = argparse.ArgumentParser(description="Prepare documents for RAG ingestion")
    parser.add_argument("--chunk-size", type=int, default=512, help="Target tokens per chunk")
    parser.add_argument("--overlap", type=int, default=50, help="Overlap tokens between chunks")
    parser.add_argument("--min-chunk", type=int, default=100, help="Minimum tokens to keep chunk")
    parser.add_argument("--no-dedupe", action="store_true", help="Disable deduplication")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    config = PrepConfig(
        chunk_size=args.chunk_size,
        chunk_overlap=args.overlap,
        min_chunk_size=args.min_chunk,
        deduplicate=not args.no_dedupe,
        verbose=args.verbose
    )

    print("\n" + "=" * 70)
    print("  RAG PREPARATION PIPELINE")
    print("=" * 70)
    print(f"\n  Source:      {RAW_DATA_DIR}")
    print(f"  Output:      {OUTPUT_DIR}")
    print(f"  Chunk size:  {config.chunk_size} tokens")
    print(f"  Overlap:     {config.chunk_overlap} tokens")
    print(f"  Deduplicate: {config.deduplicate}")

    # Check dependencies
    print("\n  Dependencies:")
    print(f"    langchain:  {'Yes' if LANGCHAIN_AVAILABLE else 'No (basic splitting)'}")
    print(f"    tiktoken:   {'Yes' if TIKTOKEN_AVAILABLE else 'No (word estimation)'}")
    print(f"    ftfy:       {'Yes' if FTFY_AVAILABLE else 'No (basic encoding)'}")
    print(f"    chardet:    {'Yes' if CHARDET_AVAILABLE else 'No (assuming UTF-8)'}")
    print(f"    nltk:       {'Yes' if NLTK_AVAILABLE else 'No (basic sentences)'}")

    # Initialize
    token_counter = TokenCounter(config.tokenizer_model)
    seen_hashes: set = set()
    all_chunks: List[Chunk] = []
    stats = PrepStats()

    start_time = datetime.now()

    # Discover files
    print("\n" + "-" * 70)
    print("  STAGE 1: DISCOVER")
    print("-" * 70)

    if not RAW_DATA_DIR.exists():
        print(f"\n  Error: Raw data directory not found: {RAW_DATA_DIR}")
        return

    raw_files = []
    for ext in SUPPORTED_EXTENSIONS:
        raw_files.extend(RAW_DATA_DIR.glob(f"*{ext}"))
    raw_files = sorted(raw_files)

    if not raw_files:
        print(f"\n  No files found in {RAW_DATA_DIR}")
        print(f"  Add .md, .txt, .json, or .jsonl files to get started.")
        return

    print(f"\n  Found {len(raw_files)} files:")
    for f in raw_files:
        print(f"    - {f.name}")

    # Process files
    print("\n" + "-" * 70)
    print("  STAGE 2: CHUNK & SANITIZE")
    print("-" * 70)

    for filepath in raw_files:
        print(f"\n  Processing: {filepath.name}")

        chunks, duplicates = process_file(filepath, config, token_counter, seen_hashes)

        if chunks:
            all_chunks.extend(chunks)
            stats.files_processed += 1
            stats.duplicate_chunks_removed += duplicates

            total_tokens = sum(c.token_count for c in chunks)
            print(f"    Chunks: {len(chunks)} | Tokens: {total_tokens} | Dupes removed: {duplicates}")
        else:
            stats.files_failed += 1
            print(f"    Failed or empty")

    # Calculate stats
    stats.total_chunks = len(all_chunks)
    stats.total_tokens = sum(c.token_count for c in all_chunks)
    stats.avg_chunk_size = stats.total_tokens / stats.total_chunks if stats.total_chunks > 0 else 0
    stats.processing_time_seconds = (datetime.now() - start_time).total_seconds()

    # Write output
    print("\n" + "-" * 70)
    print("  STAGE 3: WRITE OUTPUT")
    print("-" * 70)

    # Generate timestamp-based filename to avoid duplicates
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    chunks_filename = f"prepared_{timestamp}.jsonl"
    chunks_file = OUTPUT_DIR / chunks_filename

    # Write chunks as JSONL (one chunk per line)
    with open(chunks_file, 'w', encoding='utf-8') as f:
        for chunk in all_chunks:
            f.write(json.dumps(asdict(chunk), ensure_ascii=False) + '\n')
    print(f"\n  Wrote: {chunks_file.name} ({stats.total_chunks} chunks)")

    # Write manifest
    manifest = {
        "created_at": datetime.now().isoformat(),
        "output_file": chunks_filename,
        "config": {
            "chunk_size": config.chunk_size,
            "chunk_overlap": config.chunk_overlap,
            "min_chunk_size": config.min_chunk_size,
            "deduplicate": config.deduplicate,
            "tokenizer_model": config.tokenizer_model,
            "target_embedding_model": config.target_embedding_model
        },
        "stats": asdict(stats),
        "source_files": [f.name for f in raw_files],
        "dependencies": {
            "langchain": LANGCHAIN_AVAILABLE,
            "tiktoken": TIKTOKEN_AVAILABLE,
            "ftfy": FTFY_AVAILABLE,
            "chardet": CHARDET_AVAILABLE,
            "nltk": NLTK_AVAILABLE
        }
    }

    manifest_file = OUTPUT_DIR / "chunk_manifest.json"
    with open(manifest_file, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"  Wrote: {manifest_file.name}")

    # Move raw files to processed directory
    print("\n" + "-" * 70)
    print("  STAGE 4: MOVE RAW FILES TO PROCESSED")
    print("-" * 70)

    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    moved_count = 0
    for filepath in raw_files:
        try:
            dest = PROCESSED_DIR / filepath.name
            # If file exists, add timestamp to avoid overwriting
            if dest.exists():
                stem = filepath.stem
                suffix = filepath.suffix
                dest = PROCESSED_DIR / f"{stem}_{timestamp}{suffix}"
            filepath.rename(dest)
            print(f"  Moved: {filepath.name} -> 04-processed-rag-data/")
            moved_count += 1
        except Exception as e:
            print(f"  Error moving {filepath.name}: {e}")

    print(f"\n  Moved {moved_count} files to 04-processed-rag-data/")

    # Summary
    print("\n" + "=" * 70)
    print("  PREPARATION COMPLETE")
    print("=" * 70)
    print(f"""
  Results:
    Files processed:     {stats.files_processed}
    Files failed:        {stats.files_failed}
    Total chunks:        {stats.total_chunks}
    Duplicates removed:  {stats.duplicate_chunks_removed}
    Total tokens:        {stats.total_tokens:,}
    Avg chunk size:      {stats.avg_chunk_size:.1f} tokens
    Processing time:     {stats.processing_time_seconds:.2f}s
    Files moved:         {moved_count}

  Output:
    02-prepared-rag-data/{chunks_filename}

  Raw files moved to:
    04-processed-rag-data/

  Next step:
    1. Review the prepared JSONL: cat {chunks_file}
    2. When ready, run: cd ../03-ingest-rag-data && python ingest_data.py
""")


if __name__ == "__main__":
    main()
