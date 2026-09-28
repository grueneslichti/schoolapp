Eine gamifizierte Schul-App für mehr Motivation im Unterricht – 
mit XP-System, Avataren, Spielen und KI-Maskottchen.

![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-0.x-green)

## Features
- **XP- & Level-System** – Motivation durch Belohnungen
- **Avatar-System** mit Shop und Anime-Style-Option
- **KI-Maskottchen „Lottie"** – lokal laufend, keine Cloud
- **Spiele** mit Testphase & XP-Freischaltung (Zahlenjagd, Mathe-Jagd, Function Master)
- **Kummerkasten** – anonymes Feedback an Lehrkräfte
- **Klassen-Randomisierer** für Gruppenarbeiten
- **Klassenabschluss-Fotos** als Andenken
- **Lehrer-Postfach** für Kolleg:innen
- **Mehrstufigkeit** (Grundschule/Mittelstufe/Oberstufe) mit eigenen UIs
- **Self-Hosting** – alle Daten bleiben an der Schule

## Tech-Stack
| Bereich | Technologie |
|---|---|
| Backend | FastAPI + SQLAdmin |
| Datenbank | SQLite (via SQLAlchemy + Alembic) |
| Frontend | Flutter (Android/iOS) |
| KI-Maskottchen | KoboldCpp + Llama-3.1-SauerkrautLM-8b-Instruct-Q4_K_M (lokal, optional) |

##  Voraussetzungen
- **Python 3.11**
- **Flutter SDK 3.x** + Android Studio
- **Git**
- Optional: **KoboldCpp** + ein GGUF-Modell für das KI-Maskottchen
- Optional: **Pillow** wird für Klassenabschluss-Fotos gebraucht

## Self-Hosting für Schulen
Die App ist dafür gemacht, dass Schulen sie selbst betreiben alle Daten bleiben im Haus.

Empfehlungen für den Produktivbetrieb:
- Server in **Österreich/EU**
- **HTTPS**
- Regelmäßige **Backups** der `app.db`
- **ACHTUNG!!! `SECRET_KEY` unbedingt ändern bei kommerzieller Nutzung !!!**

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
