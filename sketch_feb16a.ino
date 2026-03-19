// ═══════════════════════════════════════════════════════════════════════════
//  ESP32 ANTENNA SWITCH v2.2 - TESTATO E FUNZIONANTE
//  Access Point + Station + USB Serial + Web Interface
// ═══════════════════════════════════════════════════════════════════════════

#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
// Forward declarations
void handleStatus();
void handleSelect();
void handleWiFi();
void handleScan();
void handleSerial();
void updateWiFi();
void updateLED();
void selectAntenna(int index);
void processCommand(String cmd);
// ═══════════════════════════════════════════════════════════════════════════
//  CONFIGURAZIONE
// ═══════════════════════════════════════════════════════════════════════════

#define NUM_ANTENNAS 6
#define LED_PIN 2
#define SERIAL_BAUD 9600

// Default antenna pins
const int antennaPins[NUM_ANTENNAS] = {4, 5, 18, 19, 21, 22};

// Default antenna names
const char* antennaNames[NUM_ANTENNAS] = {
  "DxCommander",
  "3El 10-15-20",
  "Delta Loop 11m",
  "9el V/UHF",
  "Dipolo 80",
  "Dipolo 40"
};

const bool antennaDirective[NUM_ANTENNAS] = {true, false, false, true, false, false};

// WiFi AP settings
const char* AP_SSID = "AntennaSwitch-AP";
const char* AP_PASSWORD = "antenna123";

// ═══════════════════════════════════════════════════════════════════════════
//  STATO GLOBALE
// ═══════════════════════════════════════════════════════════════════════════

int selectedAntenna = -1;
bool systemOn = true;
String staSSID = "";
String staPassword = "";
bool staConnected = false;

unsigned long lastReconnect = 0;
unsigned long lastLedUpdate = 0;
bool ledState = false;

Preferences prefs;
WebServer server(80);

// ═══════════════════════════════════════════════════════════════════════════
//  HTML PAGE
// ═══════════════════════════════════════════════════════════════════════════

const char HTML_PAGE[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Antenna Switch</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Arial,sans-serif;background:#0a0a0a;color:#fff;padding:20px}
.container{max-width:800px;margin:0 auto}
.header{background:#111;padding:20px;border-radius:10px;margin-bottom:20px;border:2px solid #00ff88}
h1{color:#00ff88;font-size:24px}
.status{display:flex;gap:20px;background:#111;padding:15px;border-radius:8px;margin-bottom:20px;flex-wrap:wrap}
.status-item{display:flex;align-items:center;gap:8px;font-size:14px}
.led{width:12px;height:12px;border-radius:50%;box-shadow:0 0 8px}
.led-on{background:#00ff88}
.led-off{background:#ff4444}
.panel{background:#111;padding:20px;border-radius:10px;margin-bottom:20px;border:1px solid #333}
h2{color:#00ff88;font-size:18px;margin-bottom:15px;border-bottom:1px solid #333;padding-bottom:10px}
.antenna-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px}
.ant-btn{background:#1a1a1a;border:2px solid #444;border-radius:8px;padding:15px;cursor:pointer;transition:all 0.2s;position:relative}
.ant-btn:hover{border-color:#00ff88;transform:translateY(-2px)}
.ant-btn.active{background:#00ff88;color:#000;border-color:#00ff88;box-shadow:0 0 20px rgba(0,255,136,0.4)}
.ant-name{font-weight:bold;margin-bottom:5px}
.ant-info{font-size:11px;opacity:0.7}
.dir-badge{position:absolute;top:8px;left:8px;background:#ffaa00;color:#000;font-size:9px;padding:2px 6px;border-radius:4px;font-weight:bold}
.led-ind{position:absolute;top:8px;right:8px;width:8px;height:8px;border-radius:50%}
.form-group{margin:15px 0}
label{display:block;color:#888;font-size:12px;margin-bottom:6px}
input{width:100%;padding:10px;background:#0a0a0a;border:1px solid #444;border-radius:6px;color:#fff;font-size:14px}
.btn{padding:12px 24px;background:#00ff88;color:#000;border:none;border-radius:6px;font-weight:bold;cursor:pointer;font-size:14px}
.btn:hover{background:#00dd77}
.btn-sec{background:#333;color:#fff}
.btn-sec:hover{background:#444}
.btn-danger{background:#ff4444;color:#fff}
.btn-off{background:#888;margin-left:10px}
.info{background:#0a0a0a;border:1px solid#333;border-radius:6px;padding:12px;margin:10px 0;font-size:13px}
.info strong{color:#00ff88}
.scan-item{background:#1a1a1a;border:1px solid#333;padding:10px;margin:5px 0;border-radius:6px;cursor:pointer}
.scan-item:hover{border-color:#00ff88}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>🛰️ Antenna Switch Control</h1>
<div style="color:#888;font-size:12px">ESP32 Controller v2.2</div>
</div>
<div class="status">
<div class="status-item"><span class="led led-on" id="ledSys"></span><span id="txtSys">Sistema: ON</span></div>
<div class="status-item"><span class="led led-on"></span><span>AP: AntennaSwitch-AP</span></div>
<div class="status-item"><span class="led led-off" id="ledSta"></span><span id="txtSta">Router: --</span></div>
<div class="status-item"><span>Antenna: <strong id="txtAnt">Nessuna</strong></span></div>
</div>
<div class="panel">
<h2>Seleziona Antenna</h2>
<button class="btn btn-off" onclick="sel(-1)">DISATTIVA TUTTE</button>
<div class="antenna-grid" id="grid"></div>
</div>
<div class="panel">
<h2>WiFi Router</h2>
<div class="info" id="staInfo">Nessun router configurato</div>
<div class="form-group">
<label>SSID:</label>
<input type="text" id="ssid" placeholder="Nome rete">
</div>
<div class="form-group">
<label>Password:</label>
<input type="password" id="pass" placeholder="Password">
</div>
<button class="btn" onclick="saveWiFi()">CONNETTI</button>
<button class="btn btn-sec" onclick="scan()">CERCA RETI</button>
<div id="scanRes" style="margin-top:10px"></div>
<button class="btn btn-danger" onclick="saveWiFi('','')" style="margin-top:10px">DISCONNETTI</button>
</div>
<div class="panel">
<h2>Info Sistema</h2>
<div class="info" id="info">Caricamento...</div>
<button class="btn btn-sec" onclick="upd()">AGGIORNA</button>
</div>
</div>
<script>
let cur=-1;
function upd(){
fetch('/status').then(r=>r.json()).then(d=>{
cur=d.sel;
document.getElementById('ledSys').className='led '+(d.on?'led-on':'led-off');
document.getElementById('txtSys').textContent='Sistema: '+(d.on?'ON':'OFF');
document.getElementById('ledSta').className='led '+(d.staConn?'led-on':'led-off');
document.getElementById('txtSta').textContent='Router: '+(d.staConn?d.staIP:'Non connesso');
document.getElementById('txtAnt').textContent=cur>=0?d.ants[cur].name:'Nessuna';
let g='';
for(let i=0;i<d.ants.length;i++){
let a=d.ants[i];
let act=(i===cur);
g+='<div class="ant-btn'+(act?' active':'')+'" onclick="sel('+i+')">';
if(a.dir)g+='<div class="dir-badge">DIR</div>';
g+='<div class="led-ind" style="background:'+(act?'#00ff88':'#333')+'"></div>';
g+='<div class="ant-name">'+a.name+'</div>';
g+='<div class="ant-info">Pin '+a.pin+'</div>';
g+='</div>';
}
document.getElementById('grid').innerHTML=g;
let si=document.getElementById('staInfo');
if(d.staConn){
si.innerHTML='<strong style="color:#00ff88">✓ Connesso!</strong><br>SSID: <strong>'+d.staSsid+'</strong><br>IP: <strong>'+d.staIP+'</strong><br>RSSI: <strong>'+d.staRssi+' dBm</strong>';
}else if(d.staSsid.length>0){
si.innerHTML='<strong style="color:#ffaa00">⚠ Non connesso</strong><br>SSID: <strong>'+d.staSsid+'</strong>';
}else{
si.innerHTML='Nessun router configurato';
}
document.getElementById('info').innerHTML='AP IP: <strong>192.168.4.1</strong><br>Clients: <strong>'+d.apCli+'</strong><br>'+(d.staConn?'Router IP: <strong>'+d.staIP+'</strong><br>':'')+'Uptime: <strong>'+d.up+'s</strong><br>Heap: <strong>'+d.heap+' bytes</strong><br>Antenna salvata: <strong>'+(cur>=0?'Sì (Pin '+d.ants[cur].pin+')':'No')+'</strong>';
}).catch(e=>console.error(e));
}
function sel(i){
fetch('/sel?a='+i).then(()=>upd());
}
function saveWiFi(s,p){
s=s||document.getElementById('ssid').value.trim();
p=p||document.getElementById('pass').value;
if(s===''&&p===''){
if(!confirm('Disconnettere?'))return;
}
fetch('/wifi?s='+encodeURIComponent(s)+'&p='+encodeURIComponent(p)).then(()=>{
alert('Operazione avviata');
setTimeout(upd,3000);
});
}
function scan(){
let r=document.getElementById('scanRes');
r.innerHTML='<div style="color:#888;padding:10px">Scansione...</div>';
fetch('/scan').then(res=>res.json()).then(d=>{
if(!d.nets||d.nets.length===0){
r.innerHTML='<div style="color:#888;padding:10px">Nessuna rete trovata</div>';
return;
}
let h='';
for(let n of d.nets){
h+='<div class="scan-item" onclick="document.getElementById(\'ssid\').value=\''+n.ssid.replace(/'/g,"\\'")+'\';document.getElementById(\'pass\').focus();">';
h+='<strong>'+n.ssid+'</strong> <span style="color:#888">'+n.rssi+' dBm</span> '+(n.enc?'🔒':'🔓');
h+='</div>';
}
r.innerHTML=h;
}).catch(()=>{
r.innerHTML='<div style="color:#ff4444;padding:10px">Errore</div>';
});
}
setInterval(upd,2000);
upd();
</script>
</body>
</html>
)rawliteral";

// ═══════════════════════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════════════════════

void setup() {
  // ⭐ SERIAL DEVE ESSERE LA PRIMA COSA
  Serial.begin(SERIAL_BAUD);
  delay(500);  // IMPORTANTE: aspetta che la seriale sia pronta
  
  Serial.println();
  Serial.println("═══════════════════════════════════════");
  Serial.println("  ESP32 ANTENNA SWITCH v2.2");
  Serial.println("═══════════════════════════════════════");
  Serial.println("Inizializzazione...");
  
  // LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  
  // Relay pins
  Serial.println("Configurazione pin relè...");
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    pinMode(antennaPins[i], OUTPUT);
    digitalWrite(antennaPins[i], LOW);
    Serial.print("  Pin ");
    Serial.print(antennaPins[i]);
    Serial.print(" → ");
    Serial.println(antennaNames[i]);
  }
  
  // Load preferences
  Serial.println("Caricamento preferenze...");
  prefs.begin("antswitch", false);
  selectedAntenna = prefs.getInt("sel", -1);
  staSSID = prefs.getString("staSsid", "");
  staPassword = prefs.getString("staPass", "");
  prefs.end();
  
  Serial.print("Antenna salvata: ");
  Serial.println(selectedAntenna >= 0 ? antennaNames[selectedAntenna] : "Nessuna");
  
  // ⭐ WiFi SETUP - CRITICO
  Serial.println("Avvio WiFi...");
  WiFi.mode(WIFI_AP_STA);
  delay(100);
  
  // Access Point
  Serial.print("Creazione Access Point: ");
  Serial.println(AP_SSID);
  
  bool apStarted = WiFi.softAP(AP_SSID, AP_PASSWORD, 1, 0, 4);
  delay(500);  // ⭐ DELAY CRITICO - senza questo l'AP non si avvia
  
  if (apStarted) {
    Serial.println("✓ AP avviato!");
  } else {
    Serial.println("✗ ERRORE avvio AP!");
  }
  
  IPAddress apIP = WiFi.softAPIP();
  Serial.print("AP IP: ");
  Serial.println(apIP);
  
  // Station (se configurato)
  if (staSSID.length() > 0) {
    Serial.print("Connessione a router: ");
    Serial.println(staSSID);
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    Serial.println();
    
    if (WiFi.status() == WL_CONNECTED) {
      staConnected = true;
      Serial.print("✓ Router connesso! IP: ");
      Serial.println(WiFi.localIP());
    } else {
      Serial.println("✗ Connessione router fallita");
    }
  }
  
  // Web server
  Serial.println("Avvio web server...");
  
  server.on("/", HTTP_GET, []() {
    server.send_P(200, "text/html", HTML_PAGE);
  });
  
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/sel", HTTP_GET, handleSelect);
  server.on("/wifi", HTTP_GET, handleWiFi);
  server.on("/scan", HTTP_GET, handleScan);
  
  server.begin();
  Serial.println("✓ Web server avviato");
  
  // Ripristina antenna
  if (selectedAntenna >= 0 && selectedAntenna < NUM_ANTENNAS) {
    Serial.print("Ripristino antenna: ");
    Serial.println(antennaNames[selectedAntenna]);
    digitalWrite(antennaPins[selectedAntenna], HIGH);
  }
  
  Serial.println();
  Serial.println("═══════════════════════════════════════");
  Serial.println("  SISTEMA PRONTO!");
  Serial.println("═══════════════════════════════════════");
  Serial.println("Comandi USB disponibili:");
  Serial.println("  ANT:<idx>:<pin>  → Seleziona antenna (0-5)");
  Serial.println("  PWR:1 / PWR:0    → Sistema ON/OFF");
  Serial.println("  STATUS?          → Richiedi stato");
  Serial.println();
  Serial.print("Web Interface: http://");
  Serial.println(apIP);
  Serial.println("═══════════════════════════════════════");
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOOP
// ═══════════════════════════════════════════════════════════════════════════

void loop() {
  server.handleClient();
  handleSerial();
  updateWiFi();
  updateLED();
}

// ═══════════════════════════════════════════════════════════════════════════
//  WEB HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

void handleStatus() {
  String json = "{";
  json += "\"on\":" + String(systemOn ? "true" : "false");
  json += ",\"sel\":" + String(selectedAntenna);
  json += ",\"apCli\":" + String(WiFi.softAPgetStationNum());
  json += ",\"staSsid\":\"" + staSSID + "\"";
  json += ",\"staConn\":" + String(staConnected ? "true" : "false");
  json += ",\"staIP\":\"" + (staConnected ? WiFi.localIP().toString() : "") + "\"";
  json += ",\"staRssi\":" + String(staConnected ? WiFi.RSSI() : 0);
  json += ",\"up\":" + String(millis() / 1000);
  json += ",\"heap\":" + String(ESP.getFreeHeap());
  json += ",\"ants\":[";
  
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    if (i > 0) json += ",";
    json += "{\"name\":\"" + String(antennaNames[i]) + "\"";
    json += ",\"pin\":" + String(antennaPins[i]);
    json += ",\"dir\":" + String(antennaDirective[i] ? "true" : "false");
    json += ",\"act\":" + String((i == selectedAntenna) ? "true" : "false") + "}";
  }
  
  json += "]}";
  server.send(200, "application/json", json);
}

void handleSelect() {
  if (server.hasArg("a")) {
    int idx = server.arg("a").toInt();
    selectAntenna(idx);
  }
  server.send(200, "text/plain", "OK");
}

void handleWiFi() {
  if (server.hasArg("s")) {
    String newSSID = server.arg("s");
    String newPass = server.hasArg("p") ? server.arg("p") : "";
    
    if (newSSID.length() == 0) {
      // Disconnect
      staSSID = "";
      staPassword = "";
      staConnected = false;
      WiFi.disconnect();
      Serial.println("Router disconnesso");
    } else {
      staSSID = newSSID;
      staPassword = newPass;
      
      Serial.print("Connessione a: ");
      Serial.println(staSSID);
      
      WiFi.disconnect();
      delay(500);
      WiFi.begin(staSSID.c_str(), staPassword.c_str());
    }
    
    prefs.begin("antswitch", false);
    prefs.putString("staSsid", staSSID);
    prefs.putString("staPass", staPassword);
    prefs.end();
  }
  
  server.send(200, "text/plain", "OK");
}

void handleScan() {
  int n = WiFi.scanNetworks();
  
  String json = "{\"nets\":[";
  for (int i = 0; i < n && i < 15; i++) {
    if (i > 0) json += ",";
    String ssid = WiFi.SSID(i);
    ssid.replace("\"", "\\\"");
    json += "{\"ssid\":\"" + ssid + "\"";
    json += ",\"rssi\":" + String(WiFi.RSSI(i));
    json += ",\"enc\":" + String(WiFi.encryptionType(i) != WIFI_AUTH_OPEN ? "true" : "false") + "}";
  }
  json += "]}";
  
  WiFi.scanDelete();
  server.send(200, "application/json", json);
}

// ═══════════════════════════════════════════════════════════════════════════
//  ANTENNA CONTROL
// ═══════════════════════════════════════════════════════════════════════════

void selectAntenna(int idx) {
  // Disattiva tutte
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    digitalWrite(antennaPins[i], LOW);
  }
  
  if (idx < 0 || idx >= NUM_ANTENNAS) {
    selectedAntenna = -1;
    Serial.println("TX: ANT:NONE");
  } else {
    selectedAntenna = idx;
    digitalWrite(antennaPins[idx], HIGH);
    Serial.print("TX: ANT:");
    Serial.print(idx);
    Serial.print(":");
    Serial.println(antennaNames[idx]);
  }
  
  // Salva in memoria
  prefs.begin("antswitch", false);
  prefs.putInt("sel", selectedAntenna);
  prefs.end();
}

// ═══════════════════════════════════════════════════════════════════════════
//  SERIAL COMMANDS
// ═══════════════════════════════════════════════════════════════════════════

void handleSerial() {
  static String buffer = "";
  
  while (Serial.available()) {
    char c = Serial.read();
    
    if (c == '\n' || c == '\r') {
      if (buffer.length() > 0) {
        processCommand(buffer);
        buffer = "";
      }
    } else {
      buffer += c;
    }
  }
}

void processCommand(String cmd) {
  cmd.trim();
  if (cmd.length() == 0) return;
  
  Serial.print("RX: ");
  Serial.println(cmd);
  
  if (cmd.startsWith("ANT:")) {
    int idx = cmd.substring(4).toInt();
    selectAntenna(idx);
  }
  else if (cmd.startsWith("PWR:")) {
    systemOn = (cmd.substring(4) == "1");
    Serial.print("TX: PWR:");
    Serial.println(systemOn ? "ON" : "OFF");
    
    if (!systemOn) {
      selectAntenna(-1);
    }
  }
  else if (cmd == "STATUS?") {
    Serial.println("TX: STATUS:");
    Serial.print("  systemOn=");
    Serial.println(systemOn);
    Serial.print("  selected=");
    Serial.println(selectedAntenna);
    Serial.print("  apIP=");
    Serial.println(WiFi.softAPIP());
    Serial.print("  staConnected=");
    Serial.println(staConnected);
    if (staConnected) {
      Serial.print("  staIP=");
      Serial.println(WiFi.localIP());
    }
    
    for (int i = 0; i < NUM_ANTENNAS; i++) {
      Serial.print("  ANT");
      Serial.print(i);
      Serial.print(": ");
      Serial.print(antennaNames[i]);
      Serial.print(" (Pin ");
      Serial.print(antennaPins[i]);
      Serial.print(") ");
      Serial.println(i == selectedAntenna ? "[ATTIVA]" : "");
    }
  }
}

// ════════════════════════════════════════════���══════════════════════════════
//  WiFi RECONNECT
// ═══════════════════════════════════════════════════════════════════════════

void updateWiFi() {
  if (staSSID.length() == 0) return;
  
  bool nowConnected = (WiFi.status() == WL_CONNECTED);
  
  if (nowConnected && !staConnected) {
    staConnected = true;
    Serial.print("Router connesso! IP: ");
    Serial.println(WiFi.localIP());
  }
  else if (!nowConnected && staConnected) {
    staConnected = false;
    Serial.println("Router disconnesso");
  }
  else if (!nowConnected && millis() - lastReconnect > 30000) {
    lastReconnect = millis();
    Serial.println("Tentativo riconnessione...");
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LED UPDATE
// ═══════════════════════════════════════════════════════════════════════════

void updateLED() {
  if (selectedAntenna >= 0) {
    digitalWrite(LED_PIN, HIGH);
    return;
  }
  
  unsigned long interval = systemOn ? (staConnected ? 1000 : 500) : 2000;
  
  if (millis() - lastLedUpdate > interval) {
    lastLedUpdate = millis();
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState);
  }
}