import os, glob, re, yaml
from engines.rag_engine import ingest, Doc

ROOT = os.path.abspath(os.path.dirname(__file__))
DATA = os.path.join(ROOT, "..", "data")

def md_chunks(path, tag):
    with open(path,"r",encoding="utf-8") as f: txt=f.read()
    parts = re.split(r"\n#{1,6}\s+", txt); docs=[]
    for i,p in enumerate(parts):
        p=p.strip()
        if not p: continue
        docs.append(Doc(id=f"{tag}:{os.path.basename(path)}:{i}", text=p[:4000],
                        source=path, title=os.path.basename(path), tags=(tag,)))
    return docs

def yaml_doc(path, tag="persona"):
    with open(path,"r",encoding="utf-8") as f: y=yaml.safe_load(f)
    flat = yaml.safe_dump(y)
    return [Doc(id=f"{tag}:{os.path.basename(path)}", text=flat[:4000],
                source=path, title=os.path.basename(path), tags=(tag,))]

def seed():
    docs=[]
    for y in glob.glob(os.path.join(DATA,"personas","*.yaml")):
        docs += yaml_doc(y,"persona")
    for md in glob.glob(os.path.join(DATA,"talktrack","*.md")):
        docs += md_chunks(md,"talktrack")
    # Optional: project README
    readme=os.path.join(ROOT,"..","README.md")
    if os.path.exists(readme): docs += md_chunks(readme,"project")
    return ingest(docs)

if __name__=="__main__":
    print({"ingested": seed()})