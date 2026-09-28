Empfehlungen für den Produktivbetrieb:
- Server in **EU oder Lokal**
- **HTTPS**
- Regelmäßige **Backups** der `app.db`
- **ACHTUNG!!! `SECRET_KEY` unbedingt ändern bei kommerzieller Nutzung !!!**  Zu finden in /backend/core/config.py

# Struktur

- `backend/` – FastAPI Backend (Python)
- `app/` – Flutter Frontend (Dart)


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

**WICHTIG:** 
In lib/services/api_service.dart die Server-IP 
auf deinen Backend-Rechner ändern (z.B. http://192.168.8.119:8000)

flutter run
