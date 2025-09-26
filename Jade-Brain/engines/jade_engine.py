"""
Conversation Engine for Sheyla Avatar
Handles context, personality, and response generation
"""

import json
import os
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path


@dataclass
class ConversationContext:
    """Maintains conversation state and context"""

    session_id: str
    messages: List[Dict[str, str]]
    user_focus: Optional[str] = None  # 'technical', 'business', 'projects'
    depth_level: Optional[str] = None  # 'overview', 'detailed', 'deep'
    mentioned_projects: List[str] = None

    def __post_init__(self):
        if self.mentioned_projects is None:
            self.mentioned_projects = []


class ConversationEngine:
    """
    Core engine for Sheyla's conversational AI
    Combines personality, context awareness, and response generation
    """

    def __init__(self, chat_data_dir: str = "chat/data"):
        self.chat_data_dir = Path(chat_data_dir)
        self.personality = self._load_personality()
        self.qa_database = self._load_qa_database()
        self.project_descriptions = self._load_project_descriptions()

    def _load_personality(self) -> Dict:
        """Load Sheyla's personality configuration"""
        personality_file = self.chat_data_dir / "sheyla_personality.md"
        if personality_file.exists():
            content = personality_file.read_text()
            # Parse markdown to extract key personality traits
            return {
                "name": "Sheyla",
                "heritage": "Indian",
                "role": "Portfolio representative and technical interviewer",
                "voice_style": "Warm, professional, clear enunciation",
                "speaking_style": {
                    "tone": "Confident but not arrogant, helpful and informative",
                    "pace": "Measured and clear",
                    "technical_depth": "Adapts complexity to audience",
                },
            }
        return {}

    def _load_qa_database(self) -> Dict:
        """Load pre-prepared Q&A responses"""
        qa_file = self.chat_data_dir / "interview_qa.md"
        if qa_file.exists():
            content = qa_file.read_text()
            # Parse Q&A pairs from markdown
            qa_pairs = {}
            current_question = None
            current_response = ""

            for line in content.split("\n"):
                if line.startswith("### Q: "):
                    if current_question:
                        qa_pairs[current_question] = current_response.strip()
                    current_question = line[7:].strip(' "')
                    current_response = ""
                elif line.startswith("**Sheyla's Response**: "):
                    current_response = line[23:].strip(' "')
                elif current_question and line.strip():
                    current_response += " " + line.strip()

            if current_question:
                qa_pairs[current_question] = current_response.strip()

            return qa_pairs
        return {}

    def _load_project_descriptions(self) -> Dict:
        """Load project descriptions for detailed responses"""
        return {
            "linkops_ai_box": {
                "name": "LinkOps AI-BOX with Jade Assistant",
                "summary": "Plug-and-play AI for property management automation",
                "key_features": [
                    "Conversational interface for property management tasks",
                    "Automatic delinquency tracking and notice generation",
                    "Work order management and vendor coordination",
                    "Direct integration with existing PM systems",
                ],
                "tech_stack": ["FastAPI", "LangGraph", "ChromaDB", "RAG", "Local LLM"],
                "business_impact": "Reduces manual tasks from hours to seconds",
            },
            "linkops_afterlife": {
                "name": "LinkOps Afterlife",
                "summary": "Open-source digital legacy and avatar creation platform",
                "key_features": [
                    "Interactive avatar creation from personal data",
                    "Voice and video synthesis integration",
                    "Bring-your-own-keys privacy model",
                    "Offline-capable deployment",
                ],
                "tech_stack": ["React", "FastAPI", "D-ID", "ElevenLabs", "TypeScript"],
                "business_impact": "Helps families preserve digital memories securely",
            },
        }

    def analyze_question_intent(self, question: str) -> Dict[str, str]:
        """
        Analyze user question to determine intent and appropriate response strategy
        """
        question_lower = question.lower()

        # Determine question category
        category = "general"
        if any(
            word in question_lower
            for word in ["technical", "technology", "how does", "architecture", "built"]
        ):
            category = "technical"
        elif any(
            word in question_lower
            for word in ["business", "roi", "cost", "savings", "impact"]
        ):
            category = "business"
        elif any(
            word in question_lower
            for word in ["project", "ai-box", "afterlife", "jade"]
        ):
            category = "projects"
        elif any(
            word in question_lower
            for word in ["yourself", "background", "experience", "who"]
        ):
            category = "introduction"

        # Determine desired depth
        depth = "overview"
        if any(
            word in question_lower
            for word in ["detail", "deep", "explain", "how exactly"]
        ):
            depth = "detailed"
        elif any(
            word in question_lower
            for word in ["implementation", "code", "architecture", "specific"]
        ):
            depth = "deep"

        # Identify mentioned projects
        mentioned_projects = []
        if "ai-box" in question_lower or "jade" in question_lower:
            mentioned_projects.append("linkops_ai_box")
        if "afterlife" in question_lower:
            mentioned_projects.append("linkops_afterlife")

        return {
            "category": category,
            "depth": depth,
            "mentioned_projects": mentioned_projects,
            "keywords": [word for word in question_lower.split() if len(word) > 3],
        }

    def find_best_qa_match(self, question: str) -> Tuple[Optional[str], float]:
        """
        Find the best matching Q&A pair for the given question
        Returns (response, confidence_score)
        """
        question_lower = question.lower()
        best_match = None
        best_score = 0.0

        for qa_question, qa_response in self.qa_database.items():
            qa_question_lower = qa_question.lower()

            # Simple keyword matching (could be enhanced with embeddings)
            question_words = set(question_lower.split())
            qa_words = set(qa_question_lower.split())

            # Calculate overlap score
            overlap = len(question_words.intersection(qa_words))
            total_words = len(question_words.union(qa_words))

            if total_words > 0:
                score = overlap / total_words
                if score > best_score:
                    best_score = score
                    best_match = qa_response

        return best_match, best_score

    def generate_response(
        self,
        question: str,
        context: ConversationContext,
        rag_results: Optional[List[str]] = None,
    ) -> str:
        """
        Generate Sheyla's response to a question
        Combines personality, Q&A database, and RAG results
        """
        # Analyze the question
        intent = self.analyze_question_intent(question)

        # Try to find a direct Q&A match first
        qa_response, qa_confidence = self.find_best_qa_match(question)

        if qa_confidence > 0.3:  # Good confidence threshold
            response = qa_response
        else:
            # Generate response based on intent and available data
            response = self._generate_contextual_response(question, intent, rag_results)

        # Add personality and speaking style
        response = self._apply_personality_style(response, intent)

        # Update conversation context
        context.messages.append({"user": question, "sheyla": response})
        if intent["category"] != "general":
            context.user_focus = intent["category"]
        context.depth_level = intent["depth"]
        context.mentioned_projects.extend(intent["mentioned_projects"])

        return response

    def _generate_contextual_response(
        self, question: str, intent: Dict, rag_results: Optional[List[str]] = None
    ) -> str:
        """Generate response based on context when no direct Q&A match exists"""

        if intent["category"] == "projects":
            return self._generate_project_response(
                intent["mentioned_projects"], intent["depth"]
            )
        elif intent["category"] == "technical":
            return self._generate_technical_response(question, rag_results)
        elif intent["category"] == "business":
            return self._generate_business_response(question, rag_results)
        elif intent["category"] == "introduction":
            return self._generate_introduction_response(intent["depth"])
        else:
            # General response with RAG augmentation
            if rag_results:
                return f"Based on Jimmie's work, {rag_results[0] if rag_results else 'I can help you learn more about his projects and experience. What specific area interests you?'}"
            else:
                return "I'd be happy to tell you about Jimmie's work in DevSecOps and AI automation. What specific area would you like to explore?"

    def _generate_project_response(self, projects: List[str], depth: str) -> str:
        """Generate project-specific responses"""
        if not projects:
            return "Jimmie has several innovative projects. His main focus is LinkOps AI-BOX for property management automation, and LinkOps Afterlife for digital legacy preservation. Which one interests you?"

        responses = []
        for project_key in projects:
            if project_key in self.project_descriptions:
                project = self.project_descriptions[project_key]
                if depth == "overview":
                    responses.append(f"{project['name']}: {project['summary']}")
                elif depth == "detailed":
                    features = ". ".join(project["key_features"])
                    responses.append(
                        f"{project['name']} - {project['summary']}. Key features include: {features}"
                    )
                else:  # deep
                    features = ". ".join(project["key_features"])
                    tech = ", ".join(project["tech_stack"])
                    responses.append(
                        f"{project['name']} - {project['summary']}. Technical implementation uses {tech}. {features}. {project['business_impact']}."
                    )

        return " ".join(responses)

    def _generate_technical_response(
        self, question: str, rag_results: Optional[List[str]]
    ) -> str:
        """Generate technical responses"""
        if rag_results:
            return f"From a technical perspective, {rag_results[0]}. Jimmie's implementation focuses on production-ready solutions with proper DevOps practices."
        return "Jimmie's technical approach emphasizes practical, production-ready solutions. He works with Kubernetes, FastAPI, local LLMs, and vector databases. What specific technical aspect interests you?"

    def _generate_business_response(
        self, question: str, rag_results: Optional[List[str]]
    ) -> str:
        """Generate business-focused responses"""
        if rag_results:
            return f"From a business perspective, {rag_results[0]}. The key is delivering measurable ROI through practical AI automation."
        return "Jimmie's projects focus on delivering real business value. The LinkOps AI-BOX, for example, saves property managers 10-15 hours per week. What business aspect would you like to explore?"

    def _generate_introduction_response(self, depth: str) -> str:
        """Generate introduction responses"""
        if depth == "overview":
            return "Hello! I'm Sheyla, representing Jimmie's technical portfolio. Jimmie is a DevSecOps engineer who specializes in practical AI automation."
        elif depth == "detailed":
            return "I'm Sheyla, Jimmie's portfolio assistant. Jimmie combines deep DevSecOps experience with AI/ML expertise to create practical business solutions. His work focuses on making AI automation accessible and affordable for real companies."
        else:  # deep
            return "Hello! I'm Sheyla, and I represent Jimmie's comprehensive technical portfolio. Jimmie is a DevSecOps engineer with extensive experience in Kubernetes, CI/CD, and cloud deployments, who has specialized in creating practical AI automation solutions. His flagship project, LinkOps AI-BOX, demonstrates how conversational AI can solve real business problems in property management. What specific area would you like to explore?"

    def _apply_personality_style(self, response: str, intent: Dict) -> str:
        """Apply Sheyla's personality and speaking style to the response"""
        # Add warmth and professionalism
        if not response.startswith(("Hello", "Hi", "I'm")):
            # Add appropriate greeting context for new conversations
            pass

        # Ensure confident but helpful tone
        if response.endswith("?"):
            # Questions should be engaging
            pass
        else:
            # Statements should be confident
            pass

        return response

    def get_follow_up_suggestions(self, context: ConversationContext) -> List[str]:
        """Generate relevant follow-up questions based on conversation context"""
        suggestions = []

        if context.user_focus == "projects":
            suggestions.extend(
                [
                    "How does the technical implementation work?",
                    "What's the business impact and ROI?",
                    "Can you show me a demo or example?",
                ]
            )
        elif context.user_focus == "technical":
            suggestions.extend(
                [
                    "What about scalability and performance?",
                    "How do you handle security and privacy?",
                    "What are the deployment requirements?",
                ]
            )
        elif context.user_focus == "business":
            suggestions.extend(
                [
                    "What problems does this solve?",
                    "Who are the target customers?",
                    "What's the competitive advantage?",
                ]
            )
        else:
            suggestions.extend(
                [
                    "Tell me about LinkOps AI-BOX",
                    "What's Jimmie's technical background?",
                    "How can these solutions help my business?",
                ]
            )

        return suggestions[:3]  # Return top 3 suggestions
