import AvatarPanel from "../components/AvatarPanel.jsx";
import ChatBox from "../components/ChatBox.jsx";

const intro = `Hi, I'm James. I build reliable systems and practical AI.
This portfolio runs a small LLM + RAG over my experience. Ask about my DevOps
pipeline, how this is deployed on Azure Kubernetes, or the Afterlife OSS project.`;

export default function Landing(){
  return (
    <div className="container">
      <h1 className="title">James — Portfolio</h1>
      <p className="subtitle">Avatar intro + RAG-grounded answers for interviews.</p>
      <div className="grid">
        <AvatarPanel script={intro}/>
        <ChatBox placeholder="Ask about my DevOps or AI/ML experience…"/>
      </div>
    </div>
  );
}