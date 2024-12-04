/*********
  Rui Santos
  Complete instructions at https://RandomNerdTutorials.com/esp32-cam-projects-ebook/
  
  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files.
  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
*********/

#include "WiFi.h"
#include "esp_camera.h"
#include "esp_timer.h"
#include "img_converters.h"
#include "Arduino.h"
#include "soc/soc.h"           // Disable brownout problems
#include "soc/rtc_cntl_reg.h"  // Disable brownout problems
#include "driver/rtc_io.h"
#include <ESPAsyncWebServer.h>
#include <StringArray.h>
#include "FS.h"                // SD Card ESP32
#include "SD_MMC.h"            // SD Card ESP32
#include "time.h"
#include <WiFiUdp.h>
#include "SPIFFS.h"
#include "base64.h"
#include <Arduino_JSON.h> 
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

#define RX_BUFFER_SIZE 128

// Replace with your network credentials
const char* ssid = "AnhKul3";
const char* password = "0904155345";
const char *webAppUrl = "https://script.google.com/macros/s/AKfycbwj80c6y4c6AFBSVYJ0apv5K--mqbFIDze973GA-V3Lhvadi3bL3peg8ujikoQcYfBX/exec";
// Set your Static IP address 
IPAddress local_IP(192, 168, 1, 184); 
// Set your Gateway IP address 
IPAddress gateway(192, 168, 1, 1); 
IPAddress subnet(255, 255, 0, 0); 
IPAddress primaryDNS(8, 8, 8, 8);   //optional 
IPAddress secondaryDNS(8, 8, 4, 4); //optional

// NTP Server
const char* ntpServer = "pool.ntp.org";
const long  gmtOffset_sec = 25200; // +7 hour
const int   daylightOffset_sec = 0;

// Create AsyncWebServer object on port 80
AsyncWebServer server(80);
AsyncEventSource events("/events");

boolean takeNewPhoto = false;
boolean uploadNewPhoto = false;
boolean uploadAllPhoto = false;

String lastPhoto = "";
String list = "";
String uploadFilePath;
// HTTP GET parameter
const char* PARAM_INPUT_PHOTO = "photo";
// Search for parameter in HTTP POST request 
const char* PARAM_INPUT_1 = "input1"; 
const char* PARAM_INPUT_2 = "input2"; 
 
//Variables to save values from HTML form 
String input1; 
String input2;
#define NEW_PASSWORD input2
#define USER_NAME input1
String message = "servercheck"; // The password MCS51 will send
// File paths to save input values permanently 
const char* input1Path = "/input1.txt"; 
const char* input2Path = "/input2.txt"; 
 
JSONVar values; 

// OV2640 camera module pins (CAMERA_MODEL_AI_THINKER)
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27

#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// Stores the camera configuration parameters
camera_config_t config;

File root;
void serialEvent() {
    static char rxBuffer[RX_BUFFER_SIZE];
    static size_t index = 0;

    while (Serial.available()) {
        char receivedChar = Serial.read();

        if (index < RX_BUFFER_SIZE - 1) {
            rxBuffer[index++] = receivedChar;
        }

        if (receivedChar == '\n') { // End of line indicates a full command
            rxBuffer[index] = '\0'; // Null-terminate the string
            index = 0; // Reset the buffer index

            // Check if the string starts with "s"
            if (rxBuffer[0] == 's') {
                takeNewPhoto = true;
                message = String(rxBuffer).substring(1); // Extract the string after "s"
                message.trim(); // Remove leading and trailing whitespace, including '\n'
                Serial.println(message.c_str());
            }
        }
    }
}

void configInitCamera(){
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG; //YUV422,GRAYSCALE,RGB565,JPEG
  config.grab_mode = CAMERA_GRAB_LATEST;

  // Select lower framesize if the camera doesn't support PSRAM
  if(psramFound()){
    config.frame_size = FRAMESIZE_XGA; // FRAMESIZE_ + QVGA|CIF|VGA|SVGA|XGA|SXGA|UXGA
    config.jpeg_quality = 10; //0-63 lower number means higher quality
    config.fb_count = 1;
  } 
  else {
    config.frame_size = FRAMESIZE_SVGA;
    config.jpeg_quality = 12;
    config.fb_count = 1;
  }
  
  // Initialize the Camera
  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x", err);
    return;
  }
}

void initMicroSDCard(){
  // Start Micro SD card
  Serial.println("Starting SD Card");
  if(!SD_MMC.begin()){
    Serial.println("SD Card Mount Failed");
    return;
  }
  uint8_t cardType = SD_MMC.cardType();
  if(cardType == CARD_NONE){
    Serial.println("No SD Card attached");
    return;
  }
}

void listDirectory(fs::FS &fs) {
  File root = fs.open("/");
  list = "";
  if (!root) {
    Serial.println("Failed to open directory");
    return;
  }
  if (!root.isDirectory()) {
    Serial.println("Not a directory");
    return;
  }

  File file = root.openNextFile();
  while (file) {
    if (!file.isDirectory()) {
      String filename = String(file.name());
      filename.toLowerCase();
      if (filename.indexOf(".jpg") != -1) {
        // Add "Upload" button for each image
        list = "<tr><td><button onclick=\"window.open('/view?photo=" + String(file.name()) + "','_blank')\">View</button></td>" +
               "<td><button onclick=\"window.location.href='/delete?photo=" + String(file.name()) + "'\">Delete</button></td>" +
               "<td>" + String(file.name()) + "</td></tr>" + list;
      }
    }
    lastPhoto = file.name();
    file = root.openNextFile();
  }

  if (list == "") {
    list = "<tr>No photos Stored</tr>";
  } else {
    // Add "Upload All" button
    list = "<h1>ESP32-CAM View, Delete, and Upload Photos</h1><p><a href=\"/\">Return to Home Page</a></p><button onclick=\"window.location.href='/uploadAll'\">Upload All</button><table><th>View</th><th>Delete</th><th>Upload</th><th>Filename</th>" + list + "</table>";
  }
}

void takeSavePhoto(){
  struct tm timeinfo;
  char now[20];
  
  // Clean previous buffer
  camera_fb_t * fb = NULL;
  fb = esp_camera_fb_get();
  esp_camera_fb_return(fb); // dispose the buffered image
  fb = NULL; // reset to capture errors
  // Get fresh image
  fb = esp_camera_fb_get(); 
  if(!fb) {
    Serial.println("Camera capture failed");
    delay(1000);
    ESP.restart();
  }
    
  // Path where new picture will be saved in SD Card
  getLocalTime(&timeinfo);
  strftime(now, 20, "%Y%m%d_%H%M%S", &timeinfo); // Format Date & Time
  String path = "/photo_" + String(now) + +"_" + message.c_str()+".jpg";
  lastPhoto = path;
  Serial.printf("Picture file name: %s\n", path.c_str());
  // Save picture to microSD card
  fs::FS &fs = SD_MMC; 
  File file = fs.open(path.c_str(),FILE_WRITE);
  if(!file){
    Serial.printf("Failed to open file in writing mode");
  } 
  else {
    file.write(fb->buf, fb->len); // payload (image), payload length
    Serial.printf(" Saved: %s\n", path.c_str());
    listDirectory(SD_MMC);
  }
  file.close();
  esp_camera_fb_return(fb); 
}

void deleteFile(fs::FS &fs, const char * path){
  Serial.printf("Deleting file: %s\n", path);
  if(fs.remove(path)){  
    Serial.println("File deleted");
    listDirectory(SD_MMC);
  } 
  else {
    Serial.println("Delete failed");
  }
}

void initSPIFFS() {
  if (!SPIFFS.begin(true)) {
    Serial.println("An error has occurred while mounting SPIFFS");
  }
  else {
    Serial.println("SPIFFS mounted successfully");
  }
}

// Write file to SPIFFS 
void writeFile(fs::FS &fs, const char * path, const char * message){ 
  Serial.printf("Writing file: %s\r\n", path); 
 
  File file = fs.open(path, FILE_WRITE); 
  if(!file){ 
    Serial.println("- failed to open file for writing"); 
    return; 
  } 
  if(file.print(message)){ 
    Serial.println("- file written"); 
  } else { 
    Serial.println("- frite failed"); 
  }
}
// Function to send a single image to Google Drive
void sendImageToGoogleDrive(File &file, String filename) {
  if (!file) {
    Serial.println("Failed to open file for reading");
    return;
  }

  // Create a secure connection
  WiFiClientSecure client;
  client.setInsecure(); // Disable certificate verification (use only for testing)
  HTTPClient http;

  // Create the full URL for the request
  String url = String(webAppUrl);

  // Prepare the HTTP request
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");

  // Read file contents into a buffer
  size_t fileSize = file.size();
  uint8_t *fileBuffer = new uint8_t[fileSize];
  file.read(fileBuffer, fileSize);

  // Convert file data to Base64
  String encodedData = base64::encode(fileBuffer, fileSize);

  // Prepare JSON payload
  String payload = "{";
  payload += "\"filename\":\"" + filename + "\",";
  payload += "\"data\":\"" + encodedData + "\"";
  payload += "}";

  // Send the HTTP POST request
  int httpResponseCode = http.POST(payload);

  // Handle the response
  if (httpResponseCode > 0) {
    Serial.printf("HTTP Response code: %d\n", httpResponseCode);
    Serial.println(http.getString());
  } else {
    Serial.printf("Error in sending POST: %s\n", http.errorToString(httpResponseCode).c_str());
  }

  // Clean up
  http.end();
  delete[] fileBuffer;
  file.close();
}
void uploadImagesToGoogleDrive() {
  fs::FS &fs = SD_MMC;
  File root = fs.open("/");
  if (!root) {
    Serial.println("Failed to open directory");
    return;
  }
  if (!root.isDirectory()) {
    Serial.println("Not a directory");
    return;
  }

  File file = root.openNextFile();
  while (file) {
    if (!file.isDirectory()) {
      String filename = String(file.name());
      filename.toLowerCase();
      if (filename.indexOf(".jpg") != -1) {
        Serial.println("Uploading: " + filename);
        sendImageToGoogleDrive(file, filename);
      }
    }
    file = root.openNextFile();
  }
  Serial.println("All images uploaded.");
}


String getCurrentInputValues(){ 
  values["textValue"] = input1; 
  values["numberValue"] = input2; 
  String jsonString = JSON.stringify(values); 
  return jsonString; 
} 

void setup() {
  // Turn-off the brownout detector
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  
  // Serial port for debugging purposes
  Serial.begin(115200);
  initSPIFFS();
  // Connect to Wi-Fi
  if(!WiFi.config(local_IP, gateway, subnet, primaryDNS, secondaryDNS)) { 
  Serial.println("STA Failed to configure"); 
  } 
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }

  // Print ESP32 Local IP Address
  Serial.print("IP Address: http://");
  Serial.println(WiFi.localIP());

  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  
  Serial.println("Initializing the camera module...");
  configInitCamera();
  
  Serial.println("Initializing the MicroSD card module... ");
  initMicroSDCard();
  server.serveStatic("/", SPIFFS, "/");

  server.on("/", HTTP_GET, [](AsyncWebServerRequest *request){ 
    request->send(SPIFFS, "/index.html", "text/html", false); 
  }); 

  server.on("/capture", HTTP_GET, [](AsyncWebServerRequest * request) {
    takeNewPhoto = true; 
    request->send_P(200, "text/plain", "Taking Photo");
  });

  server.on("/saved-photo", HTTP_GET, [](AsyncWebServerRequest * request) {
    request->send(SD_MMC, "/" + lastPhoto, "image/jpg", false);
  });
  
  server.on("/list", HTTP_GET, [](AsyncWebServerRequest * request) {
    request->send_P(200, "text/html", list.c_str());
  });
  
  server.on("/view", HTTP_GET, [](AsyncWebServerRequest * request) {
    String inputMessage;
    String inputParam;
    // GET input1 value on <ESP_IP>/view?photo=<inputMessage>
    if (request->hasParam(PARAM_INPUT_PHOTO)) {
      inputMessage = request->getParam(PARAM_INPUT_PHOTO)->value();
      inputParam = PARAM_INPUT_PHOTO;
    }
    else {
      inputMessage = "No message sent";
      inputParam = "none";
    }
    Serial.println(inputMessage);
    request->send(SD_MMC, "/" + inputMessage, "image/jpg", false);
  });
  
  // Send a GET request to <ESP_IP>/delete?photo=<inputMessage>
  server.on("/delete", HTTP_GET, [] (AsyncWebServerRequest *request) {
    String inputMessage;
    String inputParam;
    // GET input1 value on <ESP_IP>/delete?photo=<inputMessage>
    if (request->hasParam(PARAM_INPUT_PHOTO)) {
      inputMessage = request->getParam(PARAM_INPUT_PHOTO)->value();
      inputParam = PARAM_INPUT_1;
    }
    else {
      inputMessage = "No message sent";
      inputParam = "none";
    }
    String deleteFilePath = "/" + inputMessage;
    Serial.println(deleteFilePath);
    deleteFile(SD_MMC, deleteFilePath.c_str());
    request->send(200, "text/html", "Done. Your photo named " + deleteFilePath + " was removed." +
                                     "<br><a href=\"/\">Return to Home Page</a> or <a href=\"/list\">view/delete other photos</a>.");
  });
  
  server.on("/values", HTTP_GET, [](AsyncWebServerRequest *request){ 
    String json = getCurrentInputValues(); 
    request->send(200, "application/json", json); 
    json = String(); 
  }); 

  server.on("/uploadAll", HTTP_GET, [] (AsyncWebServerRequest *request) {
    uploadAllPhoto = true;
    request->send(200, "text/html", "Uploading photos to Google Drive.<br><a href=\"/\">Return to Home Page</a> or <a href=\"/list\">view/upload other photos</a>.");
  });

  server.on("/", HTTP_POST, [](AsyncWebServerRequest *request) { 
    int params = request->params(); 
    for(int i=0;i<params;i++){ 
      AsyncWebParameter* p = request->getParam(i); 
      if(p->isPost()){ 
        // HTTP POST input1 value 
        if (p->name() == PARAM_INPUT_1) { 
          input1 = p->value().c_str(); 
          Serial.print("The user is: "); 
          Serial.println(USER_NAME);
          // Write file to save value 
          writeFile(SPIFFS, input1Path, input1.c_str()); 
        }
        if (p->name() == PARAM_INPUT_2) { 
          input2 = p->value().c_str(); 
          Serial.print("Password Changed to: "); 
          Serial.println("'"+ NEW_PASSWORD);
          if(USER_NAME == "admin"){
            Serial.println("Yes master, here you are!");
            writeFile(SPIFFS, input2Path, input2.c_str());
            input2 = "Changed";
              // HTTP POST input2 value 
          } else {
            Serial.println("Try again!");
            input2 = "Unchanged because you are not authorized";
          } 
          // Write file to save value 
          
        }  
        //Serial.printf("POST[%s]: %s\n", p->name().c_str(), p->value().c_str()); 
      } 
    } 
    request->send(SPIFFS, "/index.html", "text/html"); 
  }); 

  events.onConnect([](AsyncEventSourceClient *client){ 
    if(client->lastId()){ 
      Serial.printf("Client reconnected! Last message ID that it got is: %u\n", client->lastId()); 
    } 
    // send event with message "hello!", id current millis 
    // and set reconnect delay to 1 second 
    client->send("hello!", NULL, millis(), 10000); 
  }); 
  server.addHandler(&events);
  // Start server
  server.begin();
  
  root = SD_MMC.open("/");
  listDirectory(SD_MMC);

}

void loop() {
  if (takeNewPhoto) { 
    takeSavePhoto();
    events.send(message.c_str(), "photo");
    message = "servercheck";
    takeNewPhoto = false; 
  }
  if (uploadAllPhoto){
    uploadImagesToGoogleDrive();
    uploadAllPhoto = false;
  } 
  delay(1);
}
