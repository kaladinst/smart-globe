#include <Wire.h>
#include <Adafruit_MPR121.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Adafruit_NeoPixel.h>

// --- WIFI AYARLARI ---
const char* ssid = "INTERNET_ID";
const char* password = "PASSWORD";

// --- LED AYARLARI ---
#define LED_PIN    14  
#define LED_COUNT  12  

Adafruit_MPR121 cap = Adafruit_MPR121();
WebServer server(80);
Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);

int offsetValues[12]; 

void sensorKalibrasyonuYap() {
  Serial.println("Kalibrasyon yapiliyor...");
  // Bilgi Işığı: Mavi
  for(int i=0; i<strip.numPixels(); i++) strip.setPixelColor(i, strip.Color(0, 0, 50));
  strip.show();
  delay(1000); 
  
  for (uint8_t i = 0; i < 12; i++) {
    offsetValues[i] = cap.baselineData(i) - cap.filteredData(i);
    if (offsetValues[i] < 0) offsetValues[i] = 0;
  }
  
  for(int i=0; i<strip.numPixels(); i++) strip.setPixelColor(i, strip.Color(0, 50, 0));
  strip.show();
  delay(500);
  strip.clear();
  strip.show();
  Serial.println("Kalibrasyon Bitti.");
}

void handleRoot() {
  String veriPaketi = "";
  for (uint8_t i = 0; i < 12; i++) {
    int val = (cap.baselineData(i) - cap.filteredData(i)) - offsetValues[i];
    if (val < 0) val = 0;
    veriPaketi += String(val);
    if (i < 11) veriPaketi += ",";
  }
  server.send(200, "text/plain", veriPaketi);
}

void handleSetColor() {
  Serial.println("Renk Degistirme Istegi Geldi!");

  if (server.hasArg("r1")) {
    int r1 = server.arg("r1").toInt();
    int g1 = server.arg("g1").toInt();
    int b1 = server.arg("b1").toInt();
    int r2 = server.arg("r2").toInt();
    int g2 = server.arg("g2").toInt();
    int b2 = server.arg("b2").toInt();

    Serial.printf("R1:%d G1:%d B1:%d - R2:%d G2:%d B2:%d\n", r1, g1, b1, r2, g2, b2);

    for(int i=0; i<strip.numPixels(); i++) {
      if(i % 2 == 0) strip.setPixelColor(i, strip.Color(r1, g1, b1)); 
      else strip.setPixelColor(i, strip.Color(r2, g2, b2));
    }
    strip.show(); 
    server.send(200, "text/plain", "OK");
  } else {
    server.send(400, "text/plain", "Eksik Parametre");
    Serial.println("Hatali istek parametreleri");
  }
}

void setup() {
  Serial.begin(115200);
  
  strip.begin();
  strip.show();
  strip.setBrightness(150);

  if (!cap.begin(0x5A)) {
    Serial.println("MPR121 Bulunamadi!");
    while (1);
  }

  cap.writeRegister(MPR121_AUTOCONFIG0, 0x00); 
  cap.writeRegister(MPR121_AUTOCONFIG1, 0x00); 
  cap.writeRegister(MPR121_CONFIG1, 0xFF); 
  cap.writeRegister(MPR121_CONFIG2, 0x24); 

  WiFi.begin(ssid, password);
  Serial.print("WiFi Baglaniyor");
  
  int x = 0;
  while (WiFi.status() != WL_CONNECTED) {
    strip.clear();
    strip.setPixelColor(x % 12, strip.Color(50, 50, 0));
    strip.show();
    x++;
    delay(200);
    Serial.print(".");
  }
  
  strip.clear(); strip.show();
  Serial.println("\nWiFi Baglandi: " + WiFi.localIP().toString());

  sensorKalibrasyonuYap();

  server.on("/", HTTP_GET, handleRoot);
  server.on("/set_color", HTTP_GET, handleSetColor);
  server.begin();
}

void loop() {
  server.handleClient();
  
}