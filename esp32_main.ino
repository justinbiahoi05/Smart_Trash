#include <WiFi.h>
#include <ESP32Servo.h>

const char* ssid = "Van Hai";
const char* password = "15924858";
WiFiServer server(80);

// --- Khai báo chân ---
#define LID_SERVO_PIN 13   
#define SORT_SERVO_PIN 12 

#define TRIG_OPEN 5
#define ECHO_OPEN 18
#define TRIG_BIN1 14  // Hữu cơ
#define ECHO_BIN1 27
#define LED_BIN1 33
#define TRIG_BIN2 26  // Vô cơ
#define ECHO_BIN2 25
#define LED_BIN2 32

Servo lidServo;
Servo sortServo;

// --- CÀI ĐẶT GÓC CHO SG90 ---
int gocDongNap = 0;   
int gocMoNap = 85;    

int distToOpen = 15;
int distFull = 10;

bool needToScan = false; 
unsigned long previousMillis = 0;
bool ledState = LOW;

void setup() {
  Serial.begin(115200);
  lidServo.setPeriodHertz(50); sortServo.setPeriodHertz(50);
  
  lidServo.write(gocDongNap);   
  sortServo.write(90);          

  lidServo.attach(LID_SERVO_PIN, 500, 2400); 
  sortServo.attach(SORT_SERVO_PIN, 500, 2400);

  pinMode(TRIG_OPEN, OUTPUT); pinMode(ECHO_OPEN, INPUT);
  pinMode(TRIG_BIN1, OUTPUT); pinMode(ECHO_BIN1, INPUT);
  pinMode(TRIG_BIN2, OUTPUT); pinMode(ECHO_BIN2, INPUT);
  pinMode(LED_BIN1, OUTPUT);  pinMode(LED_BIN2, OUTPUT);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.println("");
  Serial.print("Da ket noi WiFi! IP ESP32 CHINH: ");
  Serial.println(WiFi.localIP()); 

  server.begin();
}

int getDistance(int trigPin, int echoPin) {
  digitalWrite(trigPin, LOW); delayMicroseconds(2);
  digitalWrite(trigPin, HIGH); delayMicroseconds(10); digitalWrite(trigPin, LOW);
  long duration = pulseIn(echoPin, HIGH, 30000); 
  if (duration == 0) return 999; return duration * 0.034 / 2;
}

void loop() {
  WiFiClient client = server.available();
  if (client) {
    if (client.connected() && client.available()) {
      String request = client.readStringUntil('\r');
      
      if (request.indexOf("GET /status") != -1) {
        client.println("HTTP/1.1 200 OK");
        client.println("Content-Type: text/plain");
        client.println();
        if (needToScan) client.println("SCAN");
        else client.println("IDLE");
      } 
      else if (request.indexOf("GET /H") != -1) {
        client.println("HTTP/1.1 200 OK"); client.println(); client.println("OK");
        sortServo.write(45); delay(2000); sortServo.write(90); 
        needToScan = false; 
      } 
      else if (request.indexOf("GET /V") != -1) {
        client.println("HTTP/1.1 200 OK"); client.println(); client.println("OK");
        sortServo.write(135); delay(2000); sortServo.write(90); 
        needToScan = false; 
      }
    }
    client.stop();
  }

  // 2. Cảm biến Mở Nắp (DÙNG FULL SỨC MẠNH - KHÔNG QUÉT TỪ TỪ)
  int distOpen = getDistance(TRIG_OPEN, ECHO_OPEN);
  
  if (distOpen > 0 && distOpen < distToOpen) {
    Serial.println("PHAT HIEN TAY! Bật nắp FULL POWER!");
    
    // Đẩy thẳng lên 85 độ ngay lập tức
    lidServo.write(gocMoNap);
    
    delay(4000);        // Đợi 4 giây 
    
    Serial.println("Đóng nắp!");
    
    // Đóng thẳng về 0 độ
    lidServo.write(gocDongNap);
    
    delay(1000);
    needToScan = true;  
  }

  // 3. Cảm biến Báo Đầy
  int distBin1 = getDistance(TRIG_BIN1, ECHO_BIN1);
  int distBin2 = getDistance(TRIG_BIN2, ECHO_BIN2);

  unsigned long currentMillis = millis();
  if (currentMillis - previousMillis >= 300) { previousMillis = currentMillis; ledState = !ledState; }

  if (distBin1 < distFull) digitalWrite(LED_BIN1, ledState); else digitalWrite(LED_BIN1, LOW);
  if (distBin2 < distFull) digitalWrite(LED_BIN2, ledState); else digitalWrite(LED_BIN2, LOW);
}