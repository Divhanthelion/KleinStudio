import io
import time
import base64
import sys

# Clear any cached mflux modules to ensure fresh imports
modules_to_clear = [mod for mod in sys.modules.keys() if 'mflux' in mod]
for mod in modules_to_clear:
    del sys.modules[mod]

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import uvicorn

from mflux.models.common.config.model_config import ModelConfig
from mflux.models.flux2.variants.txt2img.flux2_klein import Flux2Klein

app = FastAPI(title="KleinStudio FLUX Backend")

# Global variables to hold the loaded model
flux_model = None

class GenerationRequest(BaseModel):
    prompt: str
    steps: int = 4
    guidance: float = 3.5
    width: int = 1024
    height: int = 1024
    seed: Optional[int] = None

@app.on_event("startup")
def load_model():
    global flux_model
    import os
    model_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "flux2-klein-9b-4bit")
    print("[DEBUG] Server starting up - v3 (BytesIO fix)")
    print(f"Loading FLUX.2 Klein 9B model from {model_dir} to Unified Memory (4-bit)...")
    flux_model = Flux2Klein(
        model_config=ModelConfig.flux2_klein_9b(),
        model_path=model_dir
    )
    print("Model loaded successfully.")

@app.post("/generate")
def generate_image(req: GenerationRequest):
    global flux_model
    if flux_model is None:
        raise HTTPException(status_code=503, detail="Model is still loading")
    
    seed = req.seed if req.seed is not None else int(time.time())
    
    try:
        print(f"[DEBUG] Generating with params: seed={seed}, steps={req.steps}, guidance={req.guidance}")
        print(f"Generating image for prompt: '{req.prompt}'")
        
        # Call generate_image with individual parameters (NOT config object)
        generated_image = flux_model.generate_image(
            seed=seed,
            prompt=req.prompt,
            num_inference_steps=req.steps,
            height=req.height,
            width=req.width,
            guidance=req.guidance,
        )
        
        # Extract the PIL Image from the GeneratedImage wrapper
        pil_image = generated_image.image
        print(f"[DEBUG] Got PIL image: size={pil_image.size}, mode={pil_image.mode}")
        
        # Save to BytesIO buffer instead of temp file
        buffer = io.BytesIO()
        pil_image.save(buffer, format='PNG')
        buffer.seek(0)
        img_bytes = buffer.getvalue()
        print(f"[DEBUG] Image bytes length: {len(img_bytes)}")
        
        base64_encoded = base64.b64encode(img_bytes).decode('utf-8')
        print(f"[DEBUG] Base64 length: {len(base64_encoded)}")
        
        # Explicit memory cleanup for Apple Silicon / MLX
        del generated_image
        del pil_image
        import gc
        gc.collect()
        try:
            import mlx.core as mx
            if hasattr(mx, "clear_cache"):
                mx.clear_cache()
            else:
                mx.metal.clear_cache()
        except Exception:
            pass
            
        return {
            "status": "success",
            "image_base64": base64_encoded,
            "seed": seed
        }
        
    except Exception as e:
        import traceback
        print(f"Generation error: {e}")
        print(f"Traceback: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    uvicorn.run("server:app", host="127.0.0.1", port=8000, reload=False)
