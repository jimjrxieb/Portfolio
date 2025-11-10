import React, { useState, useMemo } from 'react';

// Types
interface Project {
  title: string;
  description: string;
  status: string;
  icon: string;
  highlights: string[];
  repoUrl?: string;
}

interface Tool {
  name: string;
  description: string;
  level: 'Intermediate' | 'Advanced' | 'Expert';
}

interface ToolCategory {
  title: string;
  icon: string;
  tools: Tool[];
}

type ProjectKey = 'gpcopilot' | 'interview' | 'jade';
type CategoryKey = 'languages' | 'aiml' | 'cloud' | 'security' | 'devops';

// Constants
const FEATURED_PROJECTS: Record<ProjectKey, Project> = {
  gpcopilot: {
    title: 'GP-Copilot - AI Security Automation',
    description: '6-phase consulting workflow with 20+ integrated scanners',
    status: 'Production',
    icon: '🔒',
    highlights: [
      'RAG with ChromaDB (2,656+ vectors) for security pattern search',
      'Ollama + Qwen2.5-Coder for automated code remediation',
      'Gitleaks, Trivy, Bandit, Semgrep, Checkov, Kubescape integration',
      'OPA/Rego policy generation + Conftest validation',
      'Gatekeeper admission control for Kubernetes',
      'SOC2, ISO 27001, PCI-DSS compliance mapping',
      'JSON scan results → AI fixes → compliance reports → executive summaries',
    ],
  },
  interview: {
    title: 'AI-Powered Interview Platform',
    description: 'Secure cloud architecture with AWS services',
    status: 'Deployed',
    icon: '🚀',
    repoUrl: 'https://github.com/jimjrxieb/ai-powered-project',
    highlights: [
      'Next.js + TypeScript + Drizzle ORM + AWS SDK',
      'S3 + KMS encryption, DynamoDB sessions, Secrets Manager',
      'GitHub Actions: secrets scan → SAST → audit → container scan → deploy',
      'Proper .gitignore, environment vars, IAM least privilege',
      'ArgoCD GitOps deployment with branch-based environments',
      'LocalStack for cost-free AWS service mocking',
    ],
  },
  jade: {
    title: 'Portfolio AI Assistant - Sheyla',
    description: 'RAG-powered portfolio chatbot with production deployment',
    status: 'Active',
    icon: '🤖',
    highlights: [
      'FastAPI backend + Claude API (Anthropic) + ChromaDB',
      'Semantic search with 2,656+ embedded document vectors',
      'React frontend with real-time chat interface',
      'Kubernetes deployment with Cloudflare Tunnel',
      'Response validation and anti-hallucination detection',
      'Production deployment at https://linksmlm.com',
    ],
  },
} as const;

const TOOL_CATEGORIES: Record<CategoryKey, ToolCategory> = {
  languages: {
    title: 'Languages & Frameworks',
    icon: '💻',
    tools: [
      { name: 'Python', description: 'Primary language for AI/ML & automation', level: 'Expert' },
      { name: 'TypeScript', description: 'Type-safe JavaScript for production apps', level: 'Advanced' },
      { name: 'Rego (OPA)', description: 'Policy-as-Code for compliance automation', level: 'Advanced' },
      { name: 'Bash', description: 'Shell scripting & automation', level: 'Advanced' },
      { name: 'YAML', description: 'Configuration & Infrastructure-as-Code', level: 'Expert' },
    ],
  },
  aiml: {
    title: 'AI/ML Stack',
    icon: '🧠',
    tools: [
      { name: 'ChromaDB', description: 'Vector database (2,656+ embeddings)', level: 'Expert' },
      { name: 'Ollama', description: 'Local LLM inference engine', level: 'Advanced' },
      { name: 'Qwen2.5-Coder', description: 'Code generation & remediation', level: 'Advanced' },
      { name: 'sentence-transformers', description: 'Text embeddings & semantic search', level: 'Advanced' },
      { name: 'LangGraph', description: 'Workflow orchestration for agents', level: 'Intermediate' },
      { name: 'RAG Systems', description: 'Retrieval-augmented generation architecture', level: 'Expert' },
    ],
  },
  cloud: {
    title: 'Cloud & Infrastructure',
    icon: '☁️',
    tools: [
      { name: 'Kubernetes (CKA)', description: 'Container orchestration', level: 'Expert' },
      { name: 'Docker', description: 'Containerization & microservices', level: 'Expert' },
      { name: 'Helm', description: 'Kubernetes package manager', level: 'Advanced' },
      { name: 'Terraform', description: 'Infrastructure-as-Code provisioning', level: 'Advanced' },
      { name: 'AWS (S3/KMS/DynamoDB)', description: 'Cloud services & storage', level: 'Advanced' },
      { name: 'LocalStack', description: 'Local AWS testing (cost-conscious)', level: 'Intermediate' },
    ],
  },
  security: {
    title: 'Security & Compliance',
    icon: '🛡️',
    tools: [
      { name: '20+ Security Scanners', description: 'Gitleaks, Trivy, Bandit, Semgrep, etc.', level: 'Expert' },
      { name: 'OPA/Conftest', description: 'Policy-as-Code enforcement', level: 'Expert' },
      { name: 'Gatekeeper', description: 'Kubernetes admission control', level: 'Advanced' },
      { name: 'CIS Benchmarks', description: 'Security hardening standards', level: 'Advanced' },
      { name: 'CVE Analysis', description: 'Vulnerability assessment', level: 'Advanced' },
      { name: 'CompTIA Security+', description: 'Certified security professional', level: 'Expert' },
    ],
  },
  devops: {
    title: 'DevOps & CI/CD',
    icon: '⚙️',
    tools: [
      { name: 'GitHub Actions', description: 'Multi-stage CI/CD pipelines', level: 'Expert' },
      { name: 'ArgoCD', description: 'GitOps continuous deployment', level: 'Advanced' },
      { name: 'GitOps', description: 'Branch-based multi-environment workflows', level: 'Advanced' },
      { name: 'PostgreSQL', description: 'Relational database', level: 'Intermediate' },
      { name: 'SQLite', description: 'Embedded database', level: 'Advanced' },
      { name: 'DynamoDB', description: 'NoSQL cloud database', level: 'Intermediate' },
    ],
  },
} as const;

// Components
const ProjectCard: React.FC<{
  project: Project;
  projectKey: string;
  isSelected: boolean;
  onToggle: () => void;
}> = ({ project, isSelected, onToggle }) => (
  <button
    onClick={onToggle}
    className={`w-full text-left p-3 rounded-lg border transition-colors ${
      isSelected
        ? 'bg-crystal-500/20 border-crystal-500/30'
        : 'bg-snow/5 border-white/10 hover:bg-snow/10'
    }`}
  >
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-3">
        <span className="text-xl">{project.icon}</span>
        <div>
          <div className="text-gojo-primary font-medium text-sm">
            {project.title}
          </div>
          <div className="text-gojo-secondary text-xs">
            {project.description}
          </div>
        </div>
      </div>
      <div className="text-right">
        <div className="text-xs text-crystal-400 font-medium">
          {project.status}
        </div>
        <div className="text-gojo-secondary text-xs">
          {isSelected ? '▼' : '▶'}
        </div>
      </div>
    </div>

    {isSelected && (
      <div className="mt-3 pt-3 border-t border-white/10">
        <div className="grid grid-cols-1 gap-2">
          {project.highlights.map((highlight, index) => (
            <div key={index} className="flex items-start gap-2">
              <span className="text-crystal-400 mt-1">•</span>
              <span className="text-gojo-secondary text-xs">{highlight}</span>
            </div>
          ))}
        </div>
        {project.repoUrl && (
          <div className="mt-3 pt-3 border-t border-white/10">
            <a
              href={project.repoUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-crystal-400 hover:text-crystal-300 text-xs underline"
            >
              <span>📂</span> View Repository on GitHub
            </a>
          </div>
        )}
      </div>
    )}
  </button>
);

const ToolItem: React.FC<{ tool: Tool }> = ({ tool }) => {
  const levelStyles = useMemo(() => {
    const styles = {
      Expert: 'bg-crystal-500/20 text-crystal-300',
      Advanced: 'bg-gold-500/20 text-gold-300',
      Intermediate: 'bg-jade-500/20 text-jade-300',
    };
    return styles[tool.level];
  }, [tool.level]);

  return (
    <div className="flex items-center justify-between py-2 border-b border-white/5 last:border-b-0">
      <div>
        <div className="text-gojo-primary font-medium text-sm">{tool.name}</div>
        <div className="text-gojo-secondary text-xs">{tool.description}</div>
      </div>
      <span className={`text-xs px-2 py-1 rounded-full ${levelStyles}`}>
        {tool.level}
      </span>
    </div>
  );
};

const CategorySection: React.FC<{
  category: ToolCategory;
  categoryKey: string;
  isSelected: boolean;
  onToggle: () => void;
}> = ({ category, isSelected, onToggle }) => (
  <div>
    <button
      onClick={onToggle}
      className="w-full text-left bg-snow/10 hover:bg-snow/20 border border-white/10 rounded-lg p-4 transition-colors"
    >
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <span className="text-2xl">{category.icon}</span>
          <div>
            <h3 className="text-gojo-primary font-semibold">
              {category.title}
            </h3>
            <p className="text-gojo-secondary text-sm">
              {category.tools.length} tools • Click to expand
            </p>
          </div>
        </div>
        <div className="text-gojo-secondary">{isSelected ? '▼' : '▶'}</div>
      </div>
    </button>

    {isSelected && (
      <div className="mt-3 bg-snow/5 border border-white/10 rounded-lg p-4">
        <div className="grid grid-cols-1 gap-3">
          {category.tools.map(tool => (
            <ToolItem key={tool.name} tool={tool} />
          ))}
        </div>
      </div>
    )}
  </div>
);

// Main Component
export default function Projects() {
  const [selectedCategory, setSelectedCategory] = useState<CategoryKey | null>(
    null
  );
  const [selectedProject, setSelectedProject] = useState<ProjectKey | null>(
    'gpcopilot'
  );

  const toggleCategory = (key: CategoryKey) => {
    setSelectedCategory(prev => (prev === key ? null : key));
  };

  const toggleProject = (key: ProjectKey) => {
    setSelectedProject(prev => (prev === key ? null : key));
  };

  return (
    <div className="space-y-4" data-dev="projects">
      {/* Certifications Banner */}
      <div className="bg-gradient-to-r from-crystal-500/10 to-gold-500/10 border border-crystal-500/20 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-2 flex items-center gap-2">
          <span>🎓</span> Certifications
        </h4>
        <div className="text-sm space-y-1">
          <div className="text-gojo-primary">✅ CKA (Certified Kubernetes Administrator)</div>
          <div className="text-gojo-primary">✅ CompTIA Security+</div>
          <div className="text-crystal-400">🔄 AWS AI Practitioner (In Progress)</div>
        </div>
      </div>

      {/* Project Selector */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">
          Featured Projects
        </h4>
        <div className="space-y-2">
          {(Object.entries(FEATURED_PROJECTS) as [ProjectKey, Project][]).map(
            ([key, project]) => (
              <ProjectCard
                key={key}
                project={project}
                projectKey={key}
                isSelected={selectedProject === key}
                onToggle={() => toggleProject(key)}
              />
            )
          )}
        </div>
      </div>

      {/* Tool Categories */}
      <div className="grid grid-cols-1 gap-3">
        {(Object.entries(TOOL_CATEGORIES) as [CategoryKey, ToolCategory][]).map(
          ([key, category]) => (
            <CategorySection
              key={key}
              category={category}
              categoryKey={key}
              isSelected={selectedCategory === key}
              onToggle={() => toggleCategory(key)}
            />
          )
        )}
      </div>

      {/* Best Practices */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">
          Demonstrated Practices
        </h4>
        <div className="grid grid-cols-1 gap-2 text-xs">
          {[
            'Production-grade error handling & logging',
            'Secrets management (never commit credentials)',
            'Git branching with intentional vulnerabilities for testing',
            'Automated security scanning in CI/CD',
            'Infrastructure-as-Code (Terraform, K8s manifests)',
            'Compliance evidence generation',
            'Cost-conscious development (LocalStack before AWS)',
            'Comprehensive documentation',
          ].map((practice, index) => (
            <div key={index} className="flex items-start gap-2">
              <span className="text-jade-400">✅</span>
              <span className="text-gojo-secondary">{practice}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
