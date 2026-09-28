import httpx
import base64
from core.config import settings

SDFORGE_URL = getattr(settings, 'SDFORGE_URL', 'http://127.0.0.1:7860') # URL anpassen
# Anime-Stil Prompt
DEFAULT_PROMPT = "anime style, high quality, portrait, student avatar, clean background, vibrant colors, detailed face, digital art"
DEFAULT_NEGATIVE = "low quality, blurry, deformed, ugly, bad anatomy, watermark, text"

async def transform_to_anime(
    image_base64: str,
    prompt_suffix: str | None = None,
    denoising_strength: float = 0.65
) -> str:
    if ',' in image_base64:
        image_base64 = image_base64.split(',')[1]
    full_prompt = DEFAULT_PROMPT
    if prompt_suffix:
        full_prompt += f", {prompt_suffix}"
    payload = {
        "init_images": [image_base64],
        "prompt": full_prompt,
        "negative_prompt": DEFAULT_NEGATIVE,
        "denoising_strength": denoising_strength,
        "steps": 25,
        "cfg_scale": 7,
        "width": 512,
        "height": 512,
        "sampler_name": "Euler a",
        "seed": -1,
    }  
    try:
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.post(
                f"{SDFORGE_URL}/sdapi/v1/img2img",
                json=payload
            )
            response.raise_for_status()  
            result = response.json()
            if result.get('images'):
                return result['images'][0]
            else:
                raise Exception("Kein Bild in der SDForge-Response")               
    except httpx.ConnectError:
        raise Exception("SDForge ist nicht erreichbar.")
    except Exception as e:
        raise Exception(f"SDForge-Fehler: {str(e)}")

async def check_sdforge_available() -> bool:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{SDFORGE_URL}/sdapi/v1/options")
            return response.status_code == 200
    except:
        return False