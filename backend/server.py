from llama_cpp import Llama
from fastapi import FastAPI
from pydantic import BaseModel

MODEL_PATH = "models/deepseek-r3.gguf"

llm = Llama(
    model_path=MODEL_PATH,
    n_batch=512,
    n_threads=6,
    chat_format="deepseek-r1"
)

app = FastAPI()

class ChatRequest(BaseModel):
    message: str

@app.post("/chat")
async def chat(req: ChatRequest):
    output = llm.create_chat_completion(
        messages=[{"role": "user", "content": req.message}],
        max_tokens=256,
        temperature=0.7
    )
    reply = output["choices"][0]["message"]["content"]
    return {"reply": reply}
