## GERMAN TEXT / ENGLISH VERSION BELOW

Eine gamifizierte Schul-App für mehr Motivation im Unterricht – 
mit XP-System, Avataren, Spielen und KI-Maskottchen.

![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![FastAPI](https://img.shields.io/badge/FastAPI-0.x-green)

## Features
- **XP- & Level-System** – Motivation durch Belohnungen
- **Avatar-System** mit Shop und Anime-Style-Option. Keine echtgeld einkäufe möglich.
- **KI-Maskottchen „Lottie"** – lokal laufend, keine Cloud
- **Spiele** mit Testphase & XP-Freischaltung (Zahlenjagd, Mathe-Jagd, Function Master)
- **Kummerkasten** – anonymes Feedback an Lehrkräfte
- **Klassen-Randomisierer** für Gruppenarbeiten
- **Klassenabschluss-Fotos** als Andenken
- **Lehrer-Postfach** für Kolleg:innen
- **Mehrstufigkeit** (Grundschule/Mittelstufe/Oberstufe) mit eigenen UIs
- **Self-Hosting** – alle Daten bleiben an der Schule
- Spiele sind während des Unterrichts nicht zugänglich.

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



## English Text

A gamified school app to boost classroom motivation – 
featuring an XP system, avatars, games, and an AI mascot.

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
