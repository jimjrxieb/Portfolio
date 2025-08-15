#!/usr/bin/env python3
"""
Golden Answer Tests - Prevent RAG answer drift

Tests key questions to ensure RAG system returns current, accurate answers
about Jimmie's work priorities and technical stack.
"""

import requests
import json
import sys
from typing import Dict, List

# Test cases with expected key terms that should appear in answers
GOLDEN_TESTS = [
    {
        "question": "What AI/ML work are you currently focused on?",
        "must_contain": ["RAG", "LangGraph", "HuggingFace", "enterprise"],
        "should_not_contain": ["legacy", "old"],
        "description": "Should emphasize current RAG/LangGraph work"
    },
    {
        "question": "What's your DevOps pipeline?", 
        "must_contain": ["GitHub Actions", "Azure"],
        "should_not_contain": ["Jenkins only", "primarily Jenkins"],
        "description": "Should lead with GHA/Azure, not Jenkins"
    },
    {
        "question": "Tell me about the Jade project",
        "must_contain": ["ZRS", "financial", "business intelligence"],
        "should_not_contain": ["unknown", "not sure"],
        "description": "Should know about Jade @ ZRS project"
    },
    {
        "question": "What model powers this portfolio?",
        "must_contain": ["Qwen2.5-1.5B", "HuggingFace", "ChromaDB"],
        "should_not_contain": ["GPT", "OpenAI"],
        "description": "Should correctly identify local HF model + RAG"
    },
    {
        "question": "What's your current tech stack?",
        "must_contain": ["GitHub Actions", "Azure", "Kubernetes", "HuggingFace"],
        "should_not_contain": ["Jenkins-first", "primarily Jenkins"],
        "description": "Should reflect current modern stack"
    }
]

def test_answer(question: str, answer: str, test_case: Dict) -> Dict:
    """Test an answer against golden criteria"""
    result = {
        "question": question,
        "answer": answer[:200] + "..." if len(answer) > 200 else answer,
        "passed": True,
        "issues": []
    }
    
    # Check required terms
    answer_lower = answer.lower()
    for term in test_case["must_contain"]:
        if term.lower() not in answer_lower:
            result["passed"] = False
            result["issues"].append(f"Missing required term: '{term}'")
    
    # Check forbidden terms  
    for term in test_case["should_not_contain"]:
        if term.lower() in answer_lower:
            result["passed"] = False
            result["issues"].append(f"Contains forbidden term: '{term}'")
    
    return result

def run_golden_tests(api_url: str = "http://localhost:8000") -> bool:
    """Run all golden answer tests"""
    print("🧪 Running Golden Answer Tests...")
    print("=" * 50)
    
    all_passed = True
    results = []
    
    for i, test_case in enumerate(GOLDEN_TESTS, 1):
        question = test_case["question"]
        print(f"\n[{i}/{len(GOLDEN_TESTS)}] {test_case['description']}")
        print(f"Q: {question}")
        
        try:
            # Call the API
            response = requests.post(
                f"{api_url}/api/chat",
                json={"message": question, "use_rag": True},
                timeout=30
            )
            
            if response.status_code != 200:
                print(f"❌ API Error: {response.status_code}")
                all_passed = False
                continue
                
            data = response.json()
            answer = data.get("answer", "")
            
            # Test the answer
            result = test_answer(question, answer, test_case)
            results.append(result)
            
            if result["passed"]:
                print(f"✅ PASS")
                print(f"A: {result['answer']}")
            else:
                print(f"❌ FAIL")
                print(f"A: {result['answer']}")
                for issue in result["issues"]:
                    print(f"   - {issue}")
                all_passed = False
                
        except Exception as e:
            print(f"❌ ERROR: {e}")
            all_passed = False
    
    # Summary
    print("\n" + "=" * 50)
    passed_count = sum(1 for r in results if r["passed"])
    total_count = len(results)
    
    if all_passed:
        print(f"🎉 ALL TESTS PASSED ({passed_count}/{total_count})")
        print("RAG system is returning current, accurate answers!")
    else:
        print(f"💥 TESTS FAILED ({passed_count}/{total_count})")
        print("RAG needs attention - answers may be drifting or outdated")
    
    return all_passed

if __name__ == "__main__":
    api_url = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000"
    success = run_golden_tests(api_url)
    sys.exit(0 if success else 1)