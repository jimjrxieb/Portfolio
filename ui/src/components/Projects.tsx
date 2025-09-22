import React, { useState } from 'react';

const featuredProjects = {
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
    title: 'Jade BOX',
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
    title: 'WHIS BOX',
    description: 'SOAR cybersecurity copilot',
    status: 'Guardpoint Deployment',
    icon: '🛡️',
    highlights: [
      'Security orchestration & automated response',
      'Splunk & LimaCharlie log analysis',
      'Threat intelligence integration',
      'Incident response automation',
      'Best practice action recommendations',
    ],
  },
  portfolio: {
    title: 'Interactive Portfolio',
    description: '3D avatar portfolio platform',
    status: 'Live Demo',
    icon: '🎭',
    highlights: [
      '3D Gojo avatar with VRM technology',
      'Real-time TTS lip-sync animation',
      'DevOps & AI/ML showcase',
      'Modern web technologies (React, Three.js)',
      'Demonstrates full-stack capabilities',
    ],
  },
};

const toolCategories = {
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
};

export default function Projects() {
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [selectedProject, setSelectedProject] = useState<string | null>(
    'linkops'
  );

  return (
    <div className="space-y-4" data-dev="projects">
      {/* Project Selector Dropdown */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">
          Featured Projects
        </h4>
        <div className="space-y-2">
          {Object.entries(featuredProjects).map(([key, project]) => (
            <button
              key={key}
              onClick={() =>
                setSelectedProject(selectedProject === key ? null : key)
              }
              className={`w-full text-left p-3 rounded-lg border transition-colors ${
                selectedProject === key
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
                    {selectedProject === key ? '▼' : '▶'}
                  </div>
                </div>
              </div>

              {selectedProject === key && (
                <div className="mt-3 pt-3 border-t border-white/10">
                  <div className="grid grid-cols-1 gap-2">
                    {project.highlights.map((highlight, index) => (
                      <div key={index} className="flex items-center gap-2">
                        <span className="text-crystal-400">•</span>
                        <span className="text-gojo-secondary text-xs">
                          {highlight}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </button>
          ))}
        </div>
      </div>
      {/* Category Selection */}
      <div className="grid grid-cols-1 gap-3">
        {Object.entries(toolCategories).map(([key, category]) => (
          <div key={key}>
            <button
              onClick={() =>
                setSelectedCategory(selectedCategory === key ? null : key)
              }
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
                <div className="text-gojo-secondary">
                  {selectedCategory === key ? '▼' : '▶'}
                </div>
              </div>
            </button>

            {/* Expanded Tool Details */}
            {selectedCategory === key && (
              <div className="mt-3 bg-snow/5 border border-white/10 rounded-lg p-4">
                <div className="grid grid-cols-1 gap-3">
                  {category.tools.map((tool, index) => (
                    <div
                      key={index}
                      className="flex items-center justify-between py-2 border-b border-white/5 last:border-b-0"
                    >
                      <div>
                        <div className="text-gojo-primary font-medium text-sm">
                          {tool.name}
                        </div>
                        <div className="text-gojo-secondary text-xs">
                          {tool.description}
                        </div>
                      </div>
                      <div className="text-right">
                        <span
                          className={`text-xs px-2 py-1 rounded-full ${
                            tool.level === 'Expert'
                              ? 'bg-crystal-500/20 text-crystal-300'
                              : tool.level === 'Advanced'
                                ? 'bg-gold-500/20 text-gold-300'
                                : 'bg-jade-500/20 text-jade-300'
                          }`}
                        >
                          {tool.level}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Journey & Passion */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">
          Development Journey
        </h4>
        <div className="text-gojo-secondary text-sm mb-3">
          4 months of intensive AI & DevOps learning, combining traditional
          DevOps practices with cutting-edge AI capabilities.
        </div>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <div className="text-crystal-400 font-semibold">Passion-Driven</div>
            <div className="text-gojo-secondary text-xs">
              AI capabilities & innovation
            </div>
          </div>
          <div>
            <div className="text-gold-400 font-semibold">Rapid Learning</div>
            <div className="text-gojo-secondary text-xs">Modern tech stack</div>
          </div>
          <div>
            <div className="text-jade-400 font-semibold">Practical Focus</div>
            <div className="text-gojo-secondary text-xs">
              Real-world applications
            </div>
          </div>
          <div>
            <div className="text-crystal-300 font-semibold">Integration</div>
            <div className="text-gojo-secondary text-xs">DevOps + AI/ML</div>
          </div>
        </div>
      </div>
    </div>
  );
}
