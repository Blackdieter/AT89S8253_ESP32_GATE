#include <WiFi.h>
#include <HTTPClient.h>
#include <SD.h>
#include <FS.h>
#include "my_base64.h"


// Replace these with your network and web app details
const char *ssid = "AnhKul3";
const char *password = "0904155345";
const char *webAppUrl = "https://script.google.com/macros/s/AKfycbwEkmrfscUkWNsu1_7NLPi3LsThJ8-iUf_bpt1bsm6jYkx60tYeoxXmonfrFa-WsYc/exec";

// Function to upload a single photo
void uploadPhoto(const String &filePath) {
  File photo = SD.open(filePath, FILE_READ);
  if (!photo) {
    Serial.println("Failed to open file: " + filePath);
    return;
  }

  size_t photoSize = photo.size();
  char *buffer = new char[photoSize];
  photo.readBytes(buffer, photoSize);
  photo.close();

  // Initialize HTTP client
  HTTPClient http;
  String url = String(webAppUrl) + "?folder=ESP32-CAM";
  http.begin(url);
  http.addHeader("Content-Type", "application/json");

  // Prepare Base64-encoded data
  size_t base64Len = base64_enc_len(photoSize);
  char *base64Image = new char[base64Len + 1];
  base64_encode(base64Image, buffer, photoSize);

  // Create JSON payload
  String payload = "{\"contents\":\"";
  payload += base64Image;
  payload += "\", \"type\":\"image/jpeg\"}";

  // Send POST request
  int httpResponseCode = http.POST(payload);

  if (httpResponseCode > 0) {
    Serial.println("Response: " + http.getString());
  } else {
    Serial.println("Error uploading file: " + String(httpResponseCode));
  }

  // Cleanup
  delete[] buffer;
  delete[] base64Image;
  http.end();
}

// Function to upload all photos from the SD card
void uploadAllPhotos() {
  File root = SD.open("/");
  if (!root) {
    Serial.println("Failed to open SD card root directory.");
    return;
  }

  File file = root.openNextFile();
  while (file) {
    if (!file.isDirectory() && String(file.name()).endsWith(".jpg")) {
      Serial.println("Uploading file: " + String(file.name()));
      uploadPhoto(String("/") + file.name());
    }
    file = root.openNextFile();
  }
}

void setup() {
  Serial.begin(115200);
  WiFi.begin(ssid, password);

  // Wait for Wi-Fi connection
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected!");

  // Initialize SD card
  if (!SD.begin()) {
    Serial.println("SD card initialization failed!");
    return;
  }

  // Upload all photos
  uploadAllPhotos();
}

void loop() {
  // Do nothing
}
