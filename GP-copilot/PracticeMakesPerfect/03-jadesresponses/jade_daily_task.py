#!/usr/bin/env python3
"""
JADE Daily Task Responder
Calls JADE v0.9 with RAG to answer daily practice tickets.

Usage:
    python jade_daily_task.py day2
    python jade_daily_task.py day3 --verbose
"""

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

# Add shared modules to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent.parent.parent.parent / "GP-copilot" / "JADE-AI"))
sys.path.insert(0, str(Path(__file__).parent.parent.parent.parent.parent.parent.parent / "GP-copilot" / "GP-OPENSEARCH" / "04-ingesting"))

try:
    from langchain_community.llms import Ollama
    from langchain.prompts import PromptTemplate
    from langchain.chains import LLMChain
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("Warning: LangChain not available, using direct Ollama calls")

try:
    import chromadb
    RAG_AVAILABLE = True
except ImportError:
    RAG_AVAILABLE = False
    print("Warning: ChromaDB not available, RAG disabled")


class JADEDailyTaskResponder:
    """JADE-powered daily task responder with RAG support."""

    def __init__(self, model: str = "jade:v0.9", verbose: bool = False):
        self.model = model
        self.verbose = verbose
        self.base_path = Path(__file__).parent.parent
        self.tasks_path = self.base_path / "00-dailytask"
        self.output_path = self.base_path / "03-jadesresponses"

        # Initialize LLM
        if LANGCHAIN_AVAILABLE:
            self.llm = Ollama(model=model, temperature=0.1)
        else:
            self.llm = None

        # Initialize RAG
        self.chroma_client = None
        self.collection = None
        if RAG_AVAILABLE:
            self._init_rag()

    def _init_rag(self):
        """Initialize ChromaDB RAG connection."""
        try:
            chroma_path = Path(__file__).parent.parent.parent.parent.parent.parent.parent / "GP-copilot" / "GP-OPENSEARCH" / "05-ragged-data" / "chroma_db"
            if chroma_path.exists():
                self.chroma_client = chromadb.PersistentClient(path=str(chroma_path))
                # Try to get security-knowledge collection
                try:
                    self.collection = self.chroma_client.get_collection("security-knowledge")
                    if self.verbose:
                        print(f"RAG initialized with {self.collection.count()} documents")
                except:
                    if self.verbose:
                        print("RAG collection not found, continuing without RAG")
        except Exception as e:
            if self.verbose:
                print(f"RAG initialization failed: {e}")

    def _rag_query(self, query: str, n_results: int = 3) -> str:
        """Query RAG for relevant context."""
        if not self.collection:
            return ""

        try:
            results = self.collection.query(query_texts=[query], n_results=n_results)
            if results and results['documents']:
                context = "\n\n".join(results['documents'][0])
                return f"\n\n**Relevant Knowledge:**\n{context}"
        except Exception as e:
            if self.verbose:
                print(f"RAG query failed: {e}")
        return ""

    def _call_jade(self, prompt: str) -> str:
        """Call JADE model with prompt."""
        if LANGCHAIN_AVAILABLE and self.llm:
            return self.llm.invoke(prompt)
        else:
            # Fallback to subprocess
            import subprocess
            result = subprocess.run(
                ["ollama", "run", self.model, prompt],
                capture_output=True,
                text=True,
                timeout=120
            )
            return result.stdout

    def parse_tasks(self, day: str) -> list:
        """Parse tickets from dayN.md file."""
        task_file = self.tasks_path / f"{day}.md"
        if not task_file.exists():
            raise FileNotFoundError(f"Task file not found: {task_file}")

        content = task_file.read_text()

        # Extract tickets using regex
        ticket_pattern = r'### (TICKET-\d+)\s*\|\s*([^\|]+)\|\s*([^\n]+)\n(.*?)(?=### TICKET-|\Z|## ⏱️)'
        matches = re.findall(ticket_pattern, content, re.DOTALL)

        tickets = []
        for match in matches:
            ticket_id, priority, domain, body = match
            tickets.append({
                "id": ticket_id.strip(),
                "priority": priority.strip(),
                "domain": domain.strip(),
                "body": body.strip()
            })

        return tickets

    def answer_ticket(self, ticket: dict) -> str:
        """Generate JADE's answer for a single ticket."""
        # Build RAG context
        rag_context = self._rag_query(f"{ticket['domain']} {ticket['body'][:200]}")

        # Build prompt
        prompt = f"""You are JADE, a DevSecOps AI assistant. Answer this ticket with CODE FIRST, then brief explanation.

**TICKET:** {ticket['id']} | {ticket['priority']} | {ticket['domain']}

{ticket['body']}

{rag_context}

**Instructions:**
1. Provide working code/YAML snippets FIRST
2. Keep explanations brief (1-2 sentences per point)
3. Address ALL deliverables listed
4. Be production-ready

**Your Response:**"""

        if self.verbose:
            print(f"\n{'='*60}")
            print(f"Processing {ticket['id']}...")

        response = self._call_jade(prompt)
        return response

    def run(self, day: str) -> Path:
        """Run JADE on all tickets for a day and save results."""
        tickets = self.parse_tasks(day)

        if not tickets:
            raise ValueError(f"No tickets found in {day}.md")

        print(f"Found {len(tickets)} tickets in {day}.md")

        # Build output
        output_lines = [
            f"# {day.capitalize()} - JADE v0.9 Responses",
            f"**Model:** {self.model}",
            f"**Date:** {datetime.now().strftime('%Y-%m-%d')}",
            f"**RAG:** {'Enabled' if self.collection else 'Disabled'}",
            "",
            "---",
            ""
        ]

        for ticket in tickets:
            print(f"  Processing {ticket['id']}...")
            response = self.answer_ticket(ticket)

            output_lines.extend([
                f"## {ticket['id']} | {ticket['domain']}",
                "",
                response,
                "",
                "---",
                ""
            ])

        # Save output
        output_file = self.output_path / f"{day}-jade-response.md"
        output_file.write_text("\n".join(output_lines))

        print(f"\nSaved to: {output_file}")
        return output_file


def main():
    parser = argparse.ArgumentParser(description="JADE Daily Task Responder")
    parser.add_argument("day", help="Day to process (e.g., day2, day3)")
    parser.add_argument("--model", default="jade:v0.9", help="JADE model to use")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")

    args = parser.parse_args()

    responder = JADEDailyTaskResponder(model=args.model, verbose=args.verbose)

    try:
        output_file = responder.run(args.day)
        print(f"\nDone! JADE responses saved to: {output_file}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
