import ChatBox from "../components/ChatBox";
import AvatarPanel from "../components/AvatarPanel";
import Projects from "../components/Projects";

export default function Landing() {
  return (
    <div className="p-4 grid md:grid-cols-2 gap-4 min-h-screen" data-dev="landing">
      <div className="space-y-4">
        <AvatarPanel />
        <div className="rounded-2xl border p-3">
          <ChatBox />
        </div>
      </div>
      <div className="space-y-4">
        <Projects />
      </div>
    </div>
  );
}