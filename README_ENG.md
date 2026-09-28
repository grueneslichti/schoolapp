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
