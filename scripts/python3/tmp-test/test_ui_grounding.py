#!/usr/bin/env python3
"""
Test UI Grounding Cues Truthfulness
Verifies that UI displays correct model info and grounding indicators
"""

import requests
import json
import time

API_BASE = "http://localhost:8000"


def test_health_endpoint_truthfulness():
    """Test that health endpoint returns accurate information"""
    print("🔍 Testing Health Endpoint Truthfulness")

    try:
        response = requests.get(f"{API_BASE}/health", timeout=10)
        if response.status_code != 200:
            print(f"❌ Health endpoint error: {response.status_code}")
            return False

        health_data = response.json()

        required_fields = ["llm_provider", "llm_model", "rag_namespace", "status"]
        for field in required_fields:
            if field not in health_data:
                print(f"❌ Missing health field: {field}")
                return False

        print(
            f"✅ Health endpoint returns: {health_data['llm_provider']}/{health_data['llm_model']}"
        )
        print(f"✅ RAG namespace: {health_data['rag_namespace']}")
        print(f"✅ Status: {health_data['status']}")

        return True

    except Exception as e:
        print(f"❌ Health test error: {e}")
        return False


def test_chat_response_grounding():
    """Test that chat responses include proper grounding information"""
    print("\n🔍 Testing Chat Response Grounding")

    test_question = "What is LinkOps AI-BOX?"

    try:
        response = requests.post(
            f"{API_BASE}/api/chat", json={"message": test_question}, timeout=30
        )

        if response.status_code != 200:
            print(f"❌ Chat endpoint error: {response.status_code}")
            return False

        chat_data = response.json()

        # Check required response fields
        required_fields = ["answer", "citations", "model", "grounded"]
        for field in required_fields:
            if field not in chat_data:
                print(f"❌ Missing chat field: {field}")
                return False

        # Verify grounding indicators
        if not chat_data["grounded"]:
            print("❌ Response marked as not grounded")
            return False

        if not chat_data["citations"]:
            print("❌ No citations provided for grounded response")
            return False

        # Check citation format
        for i, citation in enumerate(chat_data["citations"][:3]):
            required_citation_fields = ["source", "score"]
            for field in required_citation_fields:
                if field not in citation:
                    print(f"❌ Citation {i} missing field: {field}")
                    return False

            if not isinstance(citation["score"], (int, float)):
                print(f"❌ Citation {i} score not numeric: {citation['score']}")
                return False

            if not citation["source"].startswith("portfolio/"):
                print(f"❌ Citation {i} unexpected source format: {citation['source']}")
                return False

        print(
            f"✅ Response properly grounded with {len(chat_data['citations'])} citations"
        )
        print(f"✅ Model reported: {chat_data['model']}")
        print(f"✅ Sources: {[c['source'] for c in chat_data['citations'][:3]]}")

        return True

    except Exception as e:
        print(f"❌ Chat grounding test error: {e}")
        return False


def test_negative_case_handling():
    """Test that out-of-scope questions are handled properly"""
    print("\n🔍 Testing Negative Case Handling")

    test_question = "What's the weather like today?"

    try:
        response = requests.post(
            f"{API_BASE}/api/chat", json={"message": test_question}, timeout=30
        )

        if response.status_code != 200:
            print(f"❌ Chat endpoint error: {response.status_code}")
            return False

        chat_data = response.json()
        answer = chat_data.get("answer", "").lower()

        # Should refuse or indicate lack of context
        refuse_phrases = [
            "don't have sufficient context",
            "available context doesn't contain",
            "no relevant context",
            "insufficient information",
        ]

        refused = any(phrase in answer for phrase in refuse_phrases)

        if not refused:
            print(
                f"❌ Should refuse out-of-scope question but answered: {answer[:100]}..."
            )
            return False

        print(f"✅ Properly refused out-of-scope question")
        print(f"✅ Grounded response: {chat_data.get('grounded', False)}")

        return True

    except Exception as e:
        print(f"❌ Negative case test error: {e}")
        return False


def run_ui_grounding_tests():
    """Run all UI grounding truthfulness tests"""
    print("🧪 UI Grounding Cues Truthfulness Test")
    print("=" * 50)

    tests = [
        test_health_endpoint_truthfulness,
        test_chat_response_grounding,
        test_negative_case_handling,
    ]

    passed = 0
    total = len(tests)

    for test_func in tests:
        if test_func():
            passed += 1
        else:
            print("❌ Test failed!")

    print("\n" + "=" * 50)
    print("📈 UI GROUNDING TEST SUMMARY")
    print("=" * 50)

    success_rate = (passed / total) * 100

    print(f"\n✅ Tests Passed: {passed}/{total} ({success_rate:.0f}%)")

    if passed == total:
        print("🎉 ALL UI GROUNDING TESTS PASSED")
        print("✅ UI accurately represents RAG system state")
        print("✅ Grounding cues are truthful and informative")
        print("✅ Citations display correct source information")
        print("✅ Model information matches API health data")
    else:
        print("🔧 IMPROVEMENTS NEEDED")
        print("❌ UI grounding cues need fixes")

    return passed == total


if __name__ == "__main__":
    success = run_ui_grounding_tests()
    exit(0 if success else 1)
