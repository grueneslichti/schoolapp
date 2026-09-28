A gamified school app to boost classroom motivation – 
featuring an XP system, avatars, games, and an AI mascot.

![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-0.x-green)

## Features
- **XP & Level System** – motivation through rewards
- **Avatar System** with a shop and anime-style option, no real money usage
- **AI Mascot "Lottie"** – runs locally; no cloud usage
- **Games** with trial phases & XP-based unlocks
- **Suggestion/Feedback Box** – anonymous feedback for teachers
- **Class Randomizer** for group work
- **Class Photos** as keepsakes
- **Teacher Mailbox** for staff communication
- **Multi-level Support** (Primary/Middle/Upper School) with dedicated UIs
- **Self-Hosting** – all data remains at the school

## Tech Stack
| Area | Technology |
|---|---|
| Backend | FastAPI + SQLAdmin |
| Database | SQLite (via SQLAlchemy + Alembic) |
| Frontend | Flutter (Android/iOS) |
| AI Mascot | KoboldCpp + Llama-3.1-SauerkrautLM-8b-Instruct-Q4_K_M (local, optional) | ## Prerequisites
- **Python 3.11**
- **Flutter SDK 3.x** + Android Studio
- **Git**
- Optional: **KoboldCpp** + a GGUF model for the AI ​​mascot
- Optional: **Pillow** is required for class graduation photos

## Self-Hosting for Schools
The app is designed for schools to host it themselves; all data remains on-site.

Recommendations for production use:
- Server located in an area where it makes sense.
- **HTTPS**
- Regular **backups** of `app.db`
- **ATTENTION!!! You must change the `SECRET_KEY` for commercial use !!!**

# Structure

- `backend/` – FastAPI backend (Python)
- `app/` – Flutter frontend (Dart)


## Installation

### Backend
git clone https://github.com//schulapp.git
cd schulapp/backend

python -m venv .venv
source .venv/bin/activate

pip install -r requirements.txt

cp .env.example .env
alembic upgrade head

uvicorn main:app --host 0.0.0.0 --port 8000 --reload

### Frontend
cd ../schulapp
flutter pub get

**IMPORTANT:** 
Update the server IP in `lib/services/api_service.dart` 
to point to your backend machine (e.g., http://192.168.8.119:8000)

flutter run