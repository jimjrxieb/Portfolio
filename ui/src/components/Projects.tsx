import React, { useState, useMemo } from 'react';

// Types
interface Project {
  title: string;
  description: string;
  status: string;
  icon: string;
  highlights: string[];
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

type ProjectKey = 'linkops' | 'jade' | 'whis' | 'portfolio';
type CategoryKey = 'devops' | 'aiml' | 'security';

// Constants
const FEATURED_PROJECTS: Record<ProjectKey, Project> = {
  linkops: {
    title: 'LinkOps AI-BOX',
    description: 'Enterprise AI deployment platform',
    status: 'Product Ready',
    icon: '🚀',
    highlights: [
      'Turnkey AI solution for businesses',
      'Privacy-focused on-premise deployment',
      'Dual-speed CI/CD workflows',
      'Enterprise-grade security & compliance',
      'Scalable RAG architecture',
    ],
  },
  jade: {
    title: 'ZRS-COPILOT',
    description: 'AI property management assistant',
    status: 'ZRS Integration',
    icon: '🏠',
    highlights: [
      'Intelligent property management automation',
      'Tenant communication & screening',
      'Maintenance request processing',
      'Financial reporting & analytics',
      'Integration with existing property systems',
    ],
  },
  whis: {
    title: 'GP-COPILOT',
    description: 'Policy as Code Enforcement & Audit Automation',
    status: 'GuidePoint Deployment',
    icon: '🛡️',
    highlights: [
      'OPA (Open Policy Agent) policy enforcement automation',
      'Gatekeeper constraint validation & compliance checking',
      'Automated security audit report generation',
      'Policy-as-Code testing with OPA test framework',
      'Kubernetes admission control & governance',
      'Real-time compliance monitoring & alerting',
      'Infrastructure policy enforcement (IaC validation)',
    ],
  },
  portfolio: {
    title: 'Interactive Portfolio',
    description: 'RAG-powered AI portfolio platform',
    status: 'Live Demo',
    icon: '🎭',
    highlights: [
      'Jade AI assistant with RAG knowledge base',
      'LangChain-style batch processing pipeline',
      'ChromaDB vector storage (391+ documents)',
      'sentence-transformers embeddings',
      'OpenAI GPT-4o-mini integration',
      'React/TypeScript frontend with FastAPI backend',
      'Honest, grounded AI responses about experience',
    ],
  },
} as const;

const TOOL_CATEGORIES: Record<CategoryKey, ToolCategory> = {
  devops: {
    title: 'DevSecOps Stack',
    icon: '🚀',
    tools: [
      {
        name: 'Docker',
        description: 'Containerization & microservices',
        level: 'Advanced',
      },
      {
        name: 'Kubernetes',
        description: 'Container orchestration',
        level: 'Intermediate',
      },
      {
        name: 'GitHub Actions',
        description: 'CI/CD automation pipelines',
        level: 'Advanced',
      },
      {
        name: 'Trivy',
        description: 'Security vulnerability scanning',
        level: 'Intermediate',
      },
      {
        name: 'Cloudflare Tunnel',
        description: 'Secure networking & deployment',
        level: 'Intermediate',
      },
      {
        name: 'Linting Tools',
        description: 'Code quality & formatting',
        level: 'Advanced',
      },
    ],
  },
  aiml: {
    title: 'AI/ML Technologies',
    icon: '🤖',
    tools: [
      {
        name: 'OpenAI GPT-4o',
        description: 'Large language model integration',
        level: 'Advanced',
      },
      {
        name: 'ChromaDB',
        description: 'Vector database for RAG',
        level: 'Advanced',
      },
      {
        name: 'Python',
        description: 'AI/ML development & automation',
        level: 'Advanced',
      },
      {
        name: 'FastAPI',
        description: 'High-performance API backends',
        level: 'Advanced',
      },
      {
        name: 'RAG Systems',
        description: 'Retrieval-augmented generation',
        level: 'Intermediate',
      },
      {
        name: 'Azure TTS',
        description: 'Text-to-speech integration',
        level: 'Intermediate',
      },
    ],
  },
  security: {
    title: 'Security & Compliance',
    icon: '🛡️',
    tools: [
      {
        name: 'SAST/DAST',
        description: 'Static/Dynamic analysis',
        level: 'Advanced',
      },
      {
        name: 'Trivy',
        description: 'Vulnerability scanning',
        level: 'Advanced',
      },
      { name: 'OWASP ZAP', description: 'Security testing', level: 'Advanced' },
      { name: 'Falco', description: 'Runtime security', level: 'Intermediate' },
      {
        name: 'OPA Gatekeeper',
        description: 'Policy enforcement',
        level: 'Advanced',
      },
      {
        name: 'CIS Benchmarks',
        description: 'Security standards',
        level: 'Advanced',
      },
      { name: 'RBAC/ABAC', description: 'Access control', level: 'Expert' },
      {
        name: 'Network Policies',
        description: 'Network security',
        level: 'Advanced',
      },
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
            <div key={index} className="flex items-center gap-2">
              <span className="text-crystal-400">•</span>
              <span className="text-gojo-secondary text-xs">{highlight}</span>
            </div>
          ))}
        </div>
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
    'linkops'
  );

  const toggleCategory = (key: CategoryKey) => {
    setSelectedCategory(prev => (prev === key ? null : key));
  };

  const toggleProject = (key: ProjectKey) => {
    setSelectedProject(prev => (prev === key ? null : key));
  };

  return (
    <div className="space-y-4" data-dev="projects">
      {/* Project Selector */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">
          Copilot Projects
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

      {/* Journey Section */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">
          Development Journey
        </h4>
        <div className="text-gojo-secondary text-sm mb-3">
          4 months of intensive AI & DevOps learning, combining traditional
          DevOps practices with cutting-edge AI capabilities.
        </div>
        <div className="grid grid-cols-2 gap-4 text-sm">
          {[
            {
              title: 'Passion-Driven',
              subtitle: 'AI capabilities & innovation',
              color: 'crystal-400',
            },
            {
              title: 'Rapid Learning',
              subtitle: 'Modern tech stack',
              color: 'gold-400',
            },
            {
              title: 'Practical Focus',
              subtitle: 'Real-world applications',
              color: 'jade-400',
            },
            {
              title: 'Integration',
              subtitle: 'DevOps + AI/ML',
              color: 'crystal-300',
            },
          ].map((item, index) => (
            <div key={index}>
              <div className={`text-${item.color} font-semibold`}>
                {item.title}
              </div>
              <div className="text-gojo-secondary text-xs">{item.subtitle}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
