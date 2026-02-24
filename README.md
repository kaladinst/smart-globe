# 🌍 Smart Globe IoT (Akıllı Küre)

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32-000000?style=for-the-badge&logo=espressif&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Gemini AI](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=google&logoColor=white)
![C++](https://img.shields.io/badge/C++-%2300599C.svg?style=for-the-badge&logo=c%2B%2B&logoColor=white)

**Smart Globe** is an interactive, "phygital" (physical + digital) educational IoT platform. It transforms a standard physical globe into a smart device using capacitive touch sensors (MPR121), NeoPixel LEDs, an ESP32 microcontroller, and a Flutter-based mobile application.

Users can touch different countries on the physical globe to trigger visual, auditory, and informational feedback on the app, powered by APIs and Google Gemini AI. It also features single-player and real-time multiplayer trivia games.

---

### 📸 Project Gallery

<p align="center">
  <img src="https://github.com/user-attachments/assets/d259962c-beb1-46dc-8835-bf2c1f09502b" width="30%">
  <img src="https://github.com/user-attachments/assets/ddfd8fe0-d773-4327-b405-23aae917dae9" width="30%">
  <img src="https://github.com/user-attachments/assets/856452ca-4855-4b20-95b0-49c7a396e541" width="30%">
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/b02a1117-c5c5-452f-9193-3316ba9b4a8e" width="30%">
  <img src="https://github.com/user-attachments/assets/5ab27f89-045e-4b2f-b949-e28e24dc8b4c" width="30%">
  <img src="https://github.com/user-attachments/assets/b31c9c87-f8f2-4302-b5df-b3b298862266" width="30%">
</p>

---

## ✨ Key Features

### 🔍 Interactive Discovery Mode
* **Touch to Learn:** Touching a country on the physical globe immediately fetches its data on the mobile app.
* **Smart Lighting:** The globe's NeoPixel LEDs instantly light up in the colors of the touched country's flag.
* **AI-Powered Insights:** Uses **Google Gemini AI** to generate unique, encyclopedic facts about the country in real-time.
* **Live Weather & Time:** Fetches live weather conditions and calculates the local time using the **OpenWeatherMap API**.
* **Immersive Media:** Plays the country's national anthem and displays an automated photo slideshow.
* **Teleport (Street View):** A quick action button that launches Google Maps Street View in a random prominent location within that country.

### 🎮 Game Modes
1. **Flag Mode (Bayrak Modu):** The app shows a flag, and the user must find and touch the corresponding country on the physical globe before the timer runs out.
2. **Riddle Mode (Bilmece Modu):** Gemini AI dynamically generates a short, challenging riddle about a country's food, history, or culture. The user must deduce the country and touch it on the globe.
3. **Memory Mode (Hafıza Modu):** A "Simon Says" style memory game. The globe lights up specific countries in a sequence, and the user must repeat the sequence by touching the correct pins.

### ⚔️ Multiplayer Duel Mode (Real-Time)
A fully synchronized 2-player trivia game powered by **Firebase Realtime Database**.
* **Room System:** Players can host or join a room using a randomly generated 4-digit code.
* **Buzzer System:** When a question is asked, players must tap the digital **"I KNOW! ✋" (BİLİYORUM)** button on their screen first. 
* **Turn-Based Input:** Only the player who hits the buzzer can interact with the physical globe. The opponent's screen locks and displays "Opponent is answering...".
* **Round Limit:** The game consists of exactly 5 rounds. Points are awarded for correct physical touches. The system automatically handles round transitions and declares the winner.

---

## 🛠️ System Architecture & Tech Stack

### 1. Hardware (Edge)
* **Microcontroller:** ESP32 (Handles Wi-Fi, HTTP Server, I2C, and LED data).
* **Sensors:** MPR121 (12-channel Capacitive Touch Sensor) attached to conductive pins embedded in the globe.
* **Actuators:** WS2812B NeoPixel LED Strip (12 LEDs) placed inside the globe for illumination.
* **Communication:** ESP32 runs a local HTTP Web Server.

### 2. Software (Mobile App)
* **Framework:** Flutter (Dart).
* **State Management:** `StatefulWidget` & Realtime Streams.
* **Network Optimization:** Custom `_isNetworkBusy` flag mechanism implemented to prevent HTTP polling congestion and ESP32 crashes during rapid physical interactions and LED updates.

### 3. Cloud & APIs
* **Database:** Firebase Realtime Database (Stores country static data, leaderboards, and handles multiplayer room sync).
* **AI:** Google Generative AI (`gemini-2.5-flash`) for dynamic riddles and facts.
* **Weather:** OpenWeatherMap API.

---

## 🔌 Hardware Setup & Wiring

| Component | ESP32 Pin | Notes |
| :--- | :--- | :--- |
| **MPR121 (VIN)** | 3.3V | Strictly 3.3V, do not use 5V. |
| **MPR121 (GND)** | GND | Common ground. |
| **MPR121 (SDA)** | GPIO 21 | Default I2C Data. |
| **MPR121 (SCL)** | GPIO 22 | Default I2C Clock. |
| **MPR121 (ADDR)**| GND | Sets I2C address to `0x5A`. |
| **WS2812B (5V)** | VIN / 5V | Powers the NeoPixels. |
| **WS2812B (GND)**| GND | Common ground. |
| **WS2812B (DIN)**| GPIO 14 | Data pin for LEDs. |

---

## 🚀 Getting Started

### Prerequisites
1. Flutter SDK installed.
2. Arduino IDE with ESP32 board manager installed.
3. A Firebase project with Realtime Database enabled.
4. API Keys for Google Gemini and OpenWeatherMap.

### 1. ESP32 Setup
1. Open the `.ino` file in your Arduino IDE.
2. Install the required libraries: `Adafruit_MPR121` and `Adafruit_NeoPixel`.
3. Update the Wi-Fi credentials in the code:
   ```cpp
   const char* ssid = "YOUR_WIFI_SSID";
   const char* password = "YOUR_WIFI_PASSWORD";
