# data-dev:ingest  (run inside the api image or via job; keeps it simple)
import os, glob
import chromadb

DATA_DIR = os.environ.get("DATA_DIR", "/data")
KNOW_DIR = os.path.join(DATA_DIR, "knowledge", "jimmie")
os.makedirs(KNOW_DIR, exist_ok=True)

# 1) read markdown files
docs = []
for p in glob.glob(os.path.join(KNOW_DIR, "*.md")):
    with open(p, "r", encoding="utf-8") as f:
        docs.append(f.read())

print(f"[ingest] found {len(docs)} docs in {KNOW_DIR}")

# 2) write into chroma
client = chromadb.PersistentClient(path=os.path.join(DATA_DIR, "chroma"))
coll = client.get_or_create_collection("jimmie")

# Simple IDs; de-dupe by content hash if needed
ids = [f"doc-{i}" for i in range(len(docs))]
if docs:
    coll.upsert(documents=docs, ids=ids)
    print(f"[ingest] upserted {len(docs)} docs")
else:
    print("[ingest] no docs to ingest")