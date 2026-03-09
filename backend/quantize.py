import os
from mflux.models.common.config.model_config import ModelConfig
from mflux.models.flux2.variants.txt2img.flux2_klein import Flux2Klein

print("Loading and quantizing model...")
flux_model = Flux2Klein(
    model_config=ModelConfig.flux2_klein_9b(),
    quantize=4
)
print("Saving quantized model...")
model_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "flux2-klein-9b-4bit")
flux_model.save_model(model_dir)
print("Done!")
