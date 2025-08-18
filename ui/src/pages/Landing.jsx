import AvatarPanel from "../components/AvatarPanel.tsx";
import ChatPanel from "../components/ChatPanel.tsx";
import Projects from "../components/Projects.tsx";

export default function Landing() {
  return (
    <div className="p-4 grid md:grid-cols-2 gap-4 min-h-screen" data-dev="landing">
      <div className="space-y-4">
        <AvatarPanel />
        <div className="rounded-2xl border p-3">
          <ChatPanel />
        </div>
      </div>
      <div className="space-y-4">
        <Projects />
      </div>
    </div>
  );
}