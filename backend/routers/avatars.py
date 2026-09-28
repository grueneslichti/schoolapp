from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security.security import get_current_student
from core.sdforge_client import transform_to_anime, check_sdforge_available
from models import Student, Avatar
from schemas import AvatarUpload, AvatarRegenerate, AvatarResponse
import base64

router = APIRouter(prefix="/avatars", tags=["Avatars"])

@router.get("/sdforge-status")
async def sdforge_status():
    available = await check_sdforge_available()
    return {
        "available": available,
        "message": "SDForge ist erreichbar" if available else "SDForge ist nicht erreichbar"
    }
@router.get("/me", response_model=AvatarResponse)
def get_my_avatar(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    avatar = db.query(Avatar).filter(Avatar.student_id == current_student.id).first() 
    if not avatar:
        return AvatarResponse(
            has_original=False,
            has_anime=False,
            active_version="none",
            image_base64=None
        )
    if avatar.active_version == "anime" and avatar.anime_base64:
        active_image = avatar.anime_base64
    elif avatar.original_base64:
        active_image = avatar.original_base64
    else:
        active_image = None
    return AvatarResponse(
        has_original=avatar.original_base64 is not None,
        has_anime=avatar.anime_base64 is not None,
        active_version=avatar.active_version,
        image_base64=active_image,
        updated_at=avatar.updated_at
    )

@router.post("/upload", response_model=AvatarResponse)
async def upload_avatar(
    data: AvatarUpload,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    if not data.image_base64 or len(data.image_base64) < 100:
        raise HTTPException(status_code=400, detail="Ungültiges Bild")
    clean_base64 = data.image_base64
    if ',' in clean_base64:
        clean_base64 = clean_base64.split(',')[1]
    avatar = db.query(Avatar).filter(Avatar.student_id == current_student.id).first()
    if not avatar:
        avatar = Avatar(student_id=current_student.id)
        db.add(avatar)
    avatar.original_base64 = clean_base64
    if data.apply_anime_style:
        try:
            anime_image = await transform_to_anime(clean_base64)
            avatar.anime_base64 = anime_image
            avatar.active_version = "anime"
        except Exception as e:
            avatar.active_version = "original"
            db.commit()
            raise HTTPException(
                status_code=500, 
                detail=f"KI-Transformation fehlgeschlagen: {str(e)}. Originalfoto wird verwendet."
            )
    else:
        avatar.active_version = "original"
    
    db.commit()
    db.refresh(avatar)
    active_image = avatar.anime_base64 if avatar.active_version == "anime" else avatar.original_base64  
    return AvatarResponse(
        has_original=avatar.original_base64 is not None,
        has_anime=avatar.anime_base64 is not None,
        active_version=avatar.active_version,
        image_base64=active_image,
        updated_at=avatar.updated_at
    )

@router.post("/regenerate", response_model=AvatarResponse)
async def regenerate_avatar(
    data: AvatarRegenerate,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    avatar = db.query(Avatar).filter(Avatar.student_id == current_student.id).first()  
    if not avatar or not avatar.original_base64:
        raise HTTPException(status_code=404, detail="Kein Originalfoto vorhanden. Bitte lade zuerst ein Foto hoch.")
    try:
        anime_image = await transform_to_anime(
            avatar.original_base64,
            prompt_suffix=data.prompt_suffix
        )
        avatar.anime_base64 = anime_image
        avatar.active_version = "anime"
        db.commit()
        db.refresh(avatar)     
        return AvatarResponse(
            has_original=True,
            has_anime=True,
            active_version="anime",
            image_base64=anime_image,
            updated_at=avatar.updated_at
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"KI-Transformation fehlgeschlagen: {str(e)}")

@router.post("/switch-version")
def switch_avatar_version(
    version: str,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student)
):
    if version not in ["original", "anime"]:
        raise HTTPException(status_code=400, detail="Version muss 'original' oder 'anime' sein")  
    avatar = db.query(Avatar).filter(Avatar.student_id == current_student.id).first()
    if not avatar:
        raise HTTPException(status_code=404, detail="Kein Avatar vorhanden")   
    if version == "anime" and not avatar.anime_base64:
        raise HTTPException(status_code=400, detail="Kein Anime-Avatar vorhanden")
    if version == "original" and not avatar.original_base64:
        raise HTTPException(status_code=400, detail="Kein Originalfoto vorhanden")
    avatar.active_version = version
    db.commit()
    return {"message": f"Aktive Version: {version}"}