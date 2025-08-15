export default function Projects() {
  return (
    <div data-dev="projects-list" className="space-y-6">
      <section data-dev="project-zrs">
        <h2 className="text-xl font-semibold text-jade">ZRS Management — LinkOps AIBOX (Jade)</h2>
        <p className="text-sm text-zinc-300 mt-1">
          Offline-first AI assistant for ZRS Management (Orlando, FL). Fine-tuned Phi‑3 (Colab) on ZRS policies
          and housing laws. RAG over tenant/vendor/workflow data. RPA for onboarding and work-order completion.
          MCP tools to send emails and reports to the right parties automatically.
        </p>
      </section>

      <section data-dev="project-afterlife">
        <h2 className="text-xl font-semibold text-jade">LinkOps Afterlife — Open Source Avatar</h2>
        <p className="text-sm text-zinc-300 mt-1">
          Avatar creation center for loved ones who have passed. Upload multiple photos for accuracy, add a 30‑second
          voice sample, and a personality description to guide responses. RAG ensures grounded, respectful answers.
        </p>
      </section>

      <section data-dev="project-portfolio">
        <h2 className="text-xl font-semibold text-jade">This Portfolio — Local LLM + RAG</h2>
        <p className="text-sm text-zinc-300 mt-1">
          Interactive demo powered by a small local model and ChromaDB for grounded answers about my DevSecOps, RAG,
          and LangGraph work.
        </p>
      </section>
    </div>
  )
}