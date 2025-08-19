import React from 'react';
import projects from '../data/knowledge/jimmie/projects.json';

export default function Projects() {
  return (
    <div className="space-y-4" data-dev="projects">
      <h2 className="text-xl font-semibold text-jade-700">Projects</h2>
      <div className="grid md:grid-cols-2 gap-4">
        {projects.sections.map((p, i) => (
          <div
            key={i}
            className="rounded-2xl border border-jade-200 p-4 shadow-sm"
          >
            <div className="text-lg font-semibold">{p.title}</div>
            <div className="text-sm opacity-70">{p.subtitle}</div>
            <div className="mt-2 text-sm">{p.summary}</div>
            <ul className="mt-2 list-disc pl-5 text-sm">
              {p.highlights.map((h, j) => (
                <li key={j}>{h}</li>
              ))}
            </ul>
            <div className="mt-2 text-xs opacity-70">
              Stack: {p.stack.join(' · ')}
            </div>
            {p.links?.length ? (
              <div className="mt-3 flex gap-3 flex-wrap">
                {p.links.map((l, idx) => (
                  <a
                    key={idx}
                    className="text-sm underline"
                    href={l.href}
                    target="_blank"
                    rel="noreferrer"
                  >
                    {l.label}
                  </a>
                ))}
              </div>
            ) : null}
          </div>
        ))}
      </div>
    </div>
  );
}
