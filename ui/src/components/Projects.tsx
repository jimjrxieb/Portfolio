import React, { useState } from 'react';

const featuredProjects = {
  linkops: {
    title: "LinkOps AI-BOX",
    description: "Plug-and-play AI system for enterprise property management",
    status: "Active Development",
    icon: "🚀",
    highlights: [
      "Dual-speed CI/CD (2min content, 10min full)",
      "RAG-powered Jade Assistant", 
      "Security-first DevSecOps",
      ">90% golden set accuracy"
    ]
  },
  portfolio: {
    title: "3D Portfolio Platform", 
    description: "VRM avatar with TTS lip-sync and real-time interaction",
    status: "Live Demo",
    icon: "🎭",
    highlights: [
      "3D Gojo avatar with VRM",
      "Azure TTS lip-sync",
      "Three.js integration",
      "Real-time viseme mapping"
    ]
  },
  aibox: {
    title: "Enterprise AI Framework",
    description: "Comprehensive AI infrastructure for business automation",
    status: "Production Ready",
    icon: "🏢",
    highlights: [
      "Kubernetes orchestration",
      "Multi-tenant RAG system",
      "Advanced monitoring",
      "Cloud-native architecture"
    ]
  }
};

const toolCategories = {
  devops: {
    title: "DevSecOps Tools",
    icon: "🚀",
    tools: [
      { name: "Kubernetes", description: "Container orchestration", level: "Expert" },
      { name: "Docker", description: "Containerization platform", level: "Expert" },
      { name: "Terraform", description: "Infrastructure as Code", level: "Expert" },
      { name: "Ansible", description: "Configuration management", level: "Advanced" },
      { name: "GitHub Actions", description: "CI/CD automation", level: "Expert" },
      { name: "SonarQube", description: "Code quality analysis", level: "Advanced" },
      { name: "Vault", description: "Secret management", level: "Advanced" },
      { name: "Prometheus", description: "Monitoring & alerting", level: "Advanced" }
    ]
  },
  aiml: {
    title: "AI/ML Technologies",
    icon: "🤖",
    tools: [
      { name: "OpenAI GPT-4o", description: "Large language models", level: "Expert" },
      { name: "ChromaDB", description: "Vector database", level: "Expert" },
      { name: "LangChain", description: "LLM application framework", level: "Advanced" },
      { name: "Jupyter", description: "Interactive computing", level: "Expert" },
      { name: "Python", description: "ML/AI development", level: "Expert" },
      { name: "FastAPI", description: "High-performance APIs", level: "Expert" },
      { name: "RAG Pipelines", description: "Retrieval-augmented generation", level: "Expert" },
      { name: "Azure Speech", description: "Text-to-speech services", level: "Advanced" }
    ]
  },
  security: {
    title: "Security & Compliance",
    icon: "🛡️",
    tools: [
      { name: "SAST/DAST", description: "Static/Dynamic analysis", level: "Advanced" },
      { name: "Trivy", description: "Vulnerability scanning", level: "Advanced" },
      { name: "OWASP ZAP", description: "Security testing", level: "Advanced" },
      { name: "Falco", description: "Runtime security", level: "Intermediate" },
      { name: "OPA Gatekeeper", description: "Policy enforcement", level: "Advanced" },
      { name: "CIS Benchmarks", description: "Security standards", level: "Advanced" },
      { name: "RBAC/ABAC", description: "Access control", level: "Expert" },
      { name: "Network Policies", description: "Network security", level: "Advanced" }
    ]
  }
};

export default function Projects() {
  const [selectedCategory, setSelectedCategory] = useState<string | null>(null);
  const [selectedProject, setSelectedProject] = useState<string | null>('linkops');

  return (
    <div className="space-y-4" data-dev="projects">
      {/* Project Selector Dropdown */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">Featured Projects</h4>
        <div className="space-y-2">
          {Object.entries(featuredProjects).map(([key, project]) => (
            <button
              key={key}
              onClick={() => setSelectedProject(selectedProject === key ? null : key)}
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
                        <span className="text-gojo-secondary text-xs">{highlight}</span>
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
              onClick={() => setSelectedCategory(selectedCategory === key ? null : key)}
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
                    <div key={index} className="flex items-center justify-between py-2 border-b border-white/5 last:border-b-0">
                      <div>
                        <div className="text-gojo-primary font-medium text-sm">
                          {tool.name}
                        </div>
                        <div className="text-gojo-secondary text-xs">
                          {tool.description}
                        </div>
                      </div>
                      <div className="text-right">
                        <span className={`text-xs px-2 py-1 rounded-full ${
                          tool.level === 'Expert' 
                            ? 'bg-crystal-500/20 text-crystal-300'
                            : tool.level === 'Advanced'
                            ? 'bg-gold-500/20 text-gold-300'
                            : 'bg-jade-500/20 text-jade-300'
                        }`}>
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

      {/* Summary Stats */}
      <div className="bg-snow/10 border border-white/10 rounded-lg p-4">
        <h4 className="text-gojo-primary font-semibold mb-3">Methodology Focus</h4>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <div className="text-crystal-400 font-semibold">Security-First</div>
            <div className="text-gojo-secondary text-xs">DevSecOps practices</div>
          </div>
          <div>
            <div className="text-gold-400 font-semibold">Automation</div>
            <div className="text-gojo-secondary text-xs">CI/CD pipelines</div>
          </div>
          <div>
            <div className="text-jade-400 font-semibold">Scalability</div>
            <div className="text-gojo-secondary text-xs">Cloud-native design</div>
          </div>
          <div>
            <div className="text-crystal-300 font-semibold">Innovation</div>
            <div className="text-gojo-secondary text-xs">AI/ML integration</div>
          </div>
        </div>
      </div>
    </div>
  );
}
