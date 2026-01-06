import React from 'react';

const REPO_BASE = 'https://github.com/jimjrxieb/Portfolio';

interface SkillItem {
  name: string;
  description: string;
  path: string;
  isFile?: boolean;
  lineNumber?: number;
}

interface SkillSection {
  id: string;
  icon: string;
  title: string;
  items: SkillItem[];
}

const skillSections: SkillSection[] = [
  {
    id: 'ai_ml',
    icon: '🤖',
    title: 'AI/ML Architecture',
    items: [
      { name: 'RAG Pipeline', description: 'Retrieval-Augmented Generation', path: 'rag-pipeline' },
      { name: 'ChromaDB Vectors', description: '2,656+ embeddings', path: 'rag-pipeline/03-ingest-rag-data' },
      { name: 'Ollama Embeddings', description: 'nomic-embed-text 768-dim', path: 'rag-pipeline' },
      { name: 'Claude API', description: 'Production LLM', path: 'api/main.py', isFile: true },
      { name: 'Sheyla AI', description: 'Portfolio chatbot', path: 'ui/src/components/ChatBoxFixed.tsx', isFile: true },
    ],
  },
  {
    id: 'security_scanning',
    icon: '🔍',
    title: 'Security Scanning',
    items: [
      { name: 'Trivy', description: 'Container vulnerabilities', path: '.github/workflows/main.yml', isFile: true, lineNumber: 310 },
      { name: 'Semgrep', description: 'SAST analysis', path: '.github/workflows/main.yml', isFile: true, lineNumber: 60 },
      { name: 'detect-secrets', description: 'Secret detection', path: '.github/workflows/main.yml', isFile: true, lineNumber: 131 },
      { name: 'Bandit', description: 'Python security', path: '.github/workflows/main.yml', isFile: true, lineNumber: 104 },
      { name: 'Safety', description: 'Dependency CVEs', path: '.github/workflows/main.yml', isFile: true, lineNumber: 110 },
    ],
  },
  {
    id: 'policy_as_code',
    icon: '📜',
    title: 'Policy-as-Code',
    items: [
      { name: 'OPA/Conftest', description: '13 policies, 11 tests', path: 'GP-copilot/conftest-policies' },
      { name: 'Gatekeeper', description: 'Runtime admission', path: 'GP-copilot/gatekeeper-temps' },
      { name: 'Policy Tests', description: 'CI validation', path: '.github/workflows/main.yml', isFile: true, lineNumber: 369 },
    ],
  },
  {
    id: 'deployment',
    icon: '🚀',
    title: 'Deployment Methods',
    items: [
      { name: 'kubectl Manifests', description: 'Simple deployments', path: 'infrastructure/method1-simple-kubectl' },
      { name: 'Terraform', description: 'Infrastructure as Code', path: 'infrastructure/method2-terraform-localstack' },
      { name: 'Helm Charts', description: 'Production packaging', path: 'infrastructure/method3-helm-argocd/helm-chart' },
      { name: 'ArgoCD GitOps', description: 'Continuous delivery', path: 'infrastructure/method3-helm-argocd/argocd' },
    ],
  },
  {
    id: 'cicd',
    icon: '⚙️',
    title: 'CI/CD Pipeline',
    items: [
      { name: 'GitHub Actions', description: 'Full workflow', path: '.github/workflows/main.yml', isFile: true },
      { name: 'Parallel Scans', description: '7 tools in parallel', path: '.github/workflows/main.yml', isFile: true, lineNumber: 46 },
      { name: 'Multi-env Deploy', description: 'Dev → Staging → Prod', path: '.github/workflows/main.yml', isFile: true, lineNumber: 411 },
    ],
  },
  {
    id: 'hardening',
    icon: '🛡️',
    title: 'Hardening',
    items: [
      { name: 'NetworkPolicies', description: 'Zero-trust networking', path: 'infrastructure/method1-simple-kubectl/k8s-security/network-policies' },
      { name: 'RBAC', description: 'Least privilege', path: 'infrastructure/method1-simple-kubectl/k8s-security/rbac' },
      { name: 'Pod Security', description: 'Restricted profile', path: 'infrastructure/method1-simple-kubectl/k8s-security/pod-security' },
      { name: 'Non-root Containers', description: 'USER directive', path: 'ui/Dockerfile', isFile: true },
    ],
  },
  {
    id: 'infrastructure',
    icon: '🏗️',
    title: 'Infrastructure',
    items: [
      { name: 'Kubernetes', description: 'Full cluster config', path: 'infrastructure' },
      { name: 'FastAPI Backend', description: 'Async API', path: 'api/main.py', isFile: true },
      { name: 'React/Vite Frontend', description: 'Modern UI', path: 'ui/src' },
      { name: 'Docker Multi-stage', description: 'Optimized builds', path: 'api/Dockerfile', isFile: true },
    ],
  },
];

function buildGitHubUrl(item: SkillItem): string {
  const baseType = item.isFile ? 'blob' : 'tree';
  const lineAnchor = item.lineNumber ? `#L${item.lineNumber}` : '';
  return `${REPO_BASE}/${baseType}/main/${item.path}${lineAnchor}`;
}

export default function PortfolioBuild() {
  return (
    <div className="bg-snow/5 backdrop-blur-sm rounded-2xl border border-white/10 p-6">
      {/* Welcome Section */}
      <div className="mb-8 pb-6 border-b border-white/10">
        <h2 className="text-xl font-bold text-white mb-4">
          Welcome to My Portfolio Platform
        </h2>
        <p className="text-text-secondary text-sm leading-relaxed">
          I built this React application from scratch using Claude Code. Below you'll find{' '}
          <span className="text-crystal-400 font-medium">Sheyla</span>, my AI-powered chatbox
          where you can ask any question about my DevSecOps and AI/ML experience — simulating
          building a conversational assistant for a company and its policies.
        </p>
      </div>

      {/* Skills Section */}
      <h3 className="text-lg font-bold text-white mb-4">
        This Portfolio is Built With
      </h3>
      <p className="text-text-secondary text-sm mb-6">
        Every skill links to actual code in the repo as proof.
      </p>

      <div className="space-y-6">
        {skillSections.map((section) => (
          <div key={section.id}>
            <h3 className="flex items-center gap-2 text-white font-semibold mb-3">
              <span>{section.icon}</span>
              <span>{section.title}</span>
            </h3>
            <ul className="space-y-2 pl-1">
              {section.items.map((item) => (
                <li key={item.name} className="flex items-start gap-2 text-sm">
                  <span className="text-crystal-400 mt-0.5">•</span>
                  <div className="flex-1">
                    <a
                      href={buildGitHubUrl(item)}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-crystal-400 hover:text-crystal-300 transition-colors font-medium inline-flex items-center gap-1"
                    >
                      {item.name}
                      <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                      </svg>
                    </a>
                    <span className="text-text-secondary ml-1">— {item.description}</span>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </div>
  );
}
