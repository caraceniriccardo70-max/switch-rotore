// ═══════════════════════════════════════════════════════════════════════════
//  ESP32 ANTENNA SWITCH v2.3 - RELAY ATTIVI LOW + NOMI PERSONALIZZABILI
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
void handleRename();
void updateWiFi();
void updateLED();
void selectAntenna(int index);
void processCommand(String cmd);
void loadAntennaNames();
void saveAntennaName(int idx, String name);

// ═══════════════════════════════════════════════════════════════════════════
//  CONFIGURAZIONE
// ═══════════════════════════════════════════════════════════════════════════

#define NUM_ANTENNAS 6
#define LED_PIN 2
#define SERIAL_BAUD 9600

// Default antenna pins
const int antennaPins[NUM_ANTENNAS] = {14, 27, 26, 25, 33, 32};

// Default antenna names (sovrascrivibili da NVS)
const char* defaultAntennaNames[NUM_ANTENNAS] = {
  "Antenna 1",
  "Antenna 2",
  "Antenna 3",
  "Antenna 4",
  "Antenna 5",
  "Antenna 6"
};

// Nomi correnti (caricati da NVS)
String antennaNames[NUM_ANTENNAS];

// Relè attivi LOW (HIGH = spento, LOW = acceso)
#define RELAY_ON  LOW
#define RELAY_OFF HIGH

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
.rename-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px}
.rename-item{display:flex;gap:8px;align-items:center}
.rename-item input{flex:1;padding:8px}
.rename-item span{color:#888;font-size:12px;min-width:50px}
.btn-sm{padding:8px 14px;font-size:12px}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>🛰️ Antenna Switch Control</h1>
<div style="color:#888;font-size:12px">ESP32 Controller v2.3</div>
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
<h2>⚙️ Rinomina Antenne</h2>
<div class="rename-grid" id="renameGrid"></div>
<br>
<button class="btn" onclick="saveAllNames()">💾 SALVA NOMI</button>
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
let antData=[];
function upd(){
fetch('/status').then(r=>r.json()).then(d=>{
cur=d.sel;
antData=d.ants;
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
g+='<div class="led-ind" style="background:'+(act?'#00ff88':'#333')+'"></div>'; 
g+='<div class="ant-name">'+a.name+'</div>'; 
g+='<div class="ant-info">Pin '+a.pin+'</div>';
g+='</div>';
}
document.getElementById('grid').innerHTML=g;
// Aggiorna rename grid solo se non sta modificando
let rg=document.getElementById('renameGrid');
if(!rg.querySelector('input:focus')){
let h='';
for(let i=0;i<d.ants.length;i++){
h+='<div class="rename-item">';
h+='<span style="color:#888">ANT '+(i+1)+':</span>';
h+='<input type="text" id="rn'+i+'" value="'+d.ants[i].name+'" maxlength="20">'; 
h+='</div>';
}
rg.innerHTML=h;
}
let si=document.getElementById('staInfo');
if(d.staConn){
si.innerHTML='<strong style="color:#00ff88">✓ Connesso!</strong><br>SSID: <strong>'+d.staSsid+'</strong><br>IP: <strong>'+d.staIP+'</strong><br>RSSI: <strong>'+d.staRssi+' dBm</strong>';
}else if(d.staSsid.length>0){
si.innerHTML='<strong style="color:#ffaa00">⚠ Non connesso</strong><br>SSID: <strong>'+d.staSsid+'</strong>';
}else{
si.innerHTML='Nessun router configurato';
}
document.getElementById('info').innerHTML='AP IP: <strong>192.168.4.1</strong><br>Clients: <strong>'+d.apCli+'</strong><br>'+(d.staConn?'Router IP: <strong>'+d.staIP+'</strong><br>':'')+'Uptime: <strong>'+d.up+'s</strong><br>Heap: <strong>'+d.heap+' bytes</strong>';
}).catch(e=>console.error(e));
}
function sel(i){
fetch('/sel?a='+i).then(()=>upd());
}
function saveAllNames(){
let promises=[];
for(let i=0;i<6;i++){
let el=document.getElementById('rn'+i);
if(el){
let name=el.value.trim()||('Antenna '+(i+1));
promises.push(fetch('/rename?i='+i+'&n='+encodeURIComponent(name)));
}
}
Promise.all(promises).then(()=>{
alert('Nomi salvati!');
upon = { AUTH_TOKEN:token , request_type: 'put'};}));for(i=1;in;returning (async=true)-0){
function updateWiFi() {
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



function saveWiFi(s, p) {
    s = s || document.getElementById('ssid').value.trim();
    p = p || document.getElementById('pass').value;

    if (s === '' && p === '') {
        if (!confirm('Disconnettere?')) return;
    }
    fetch('/wifi?s=' + encodeURIComponent(s) + '&p=' + encodeURIComponent(p)).then(() => {
        alert('Operazione avviata');
        setTimeout(upd, 3000);
    });
}
setInterval(upd, 2000);
upd();
</script>
</body>
</html>
)rawliteral"; 
void loadAntennaNames() {
  prefs.begin("antswitch", false);
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    String key = "aname" + String(i);
    antennaNames[i] = prefs.getString(key.c_str(), defaultAntennaNames[i]);
  }
  prefs.end();
}

void saveAntennaName(int idx, String name) {
  if (idx < 0 || idx >= NUM_ANTENNAS) return;
  antennaNames[idx] = name;
  prefs.begin("antswitch", false);
  String key = "aname" + String(idx);
  prefs.putString(key.c_str(), name);
  prefs.end();
}

// ═══════════════════════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(SERIAL_BAUD);
  delay(500);

  Serial.println();
  Serial.println("═══════════════════════════════════════");
  Serial.println("  ESP32 ANTENNA SWITCH v2.3");
  Serial.println("═══════════════════════════════════════");
  Serial.println("Inizializzazione...");

  // LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Relay pins - inizializza a RELAY_OFF (HIGH = relè spento su moduli attivi LOW)
  Serial.println("Configurazione pin relè (attivi LOW)...");
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    pinMode(antennaPins[i], OUTPUT);
    digitalWrite(antennaPins[i], RELAY_OFF);
    Serial.print("  Pin ");
    Serial.print(antennaPins[i]);
    Serial.println(" → OFF");
  }

  // Load preferences
  Serial.println("Caricamento preferenze...");
  prefs.begin("antswitch", false);
  selectedAntenna = prefs.getInt("sel", -1);
  staSSID = prefs.getString("staSsid", "");
  staPassword = prefs.getString("staPass", "");
  prefs.end();

  // Carica nomi antenne
  loadAntennaNames();

  Serial.print("Antenna salvata: ");
  Serial.println(selectedAntenna >= 0 ? antennaNames[selectedAntenna] : "Nessuna");

  // WiFi SETUP
  Serial.println("Avvio WiFi...");
  WiFi.mode(WIFI_AP_STA);
  delay(100);

  Serial.print("Creazione Access Point: ");
  Serial.println(AP_SSID);

  bool apStarted = WiFi.softAP(AP_SSID, AP_PASSWORD, 1, 0, 4);
  delay(500);

  if (apStarted) {
    Serial.println("✓ AP avviato!");
  } else {
    Serial.println("✗ ERRORE avvio AP!");
  }

  IPAddress apIP = WiFi.softAPIP();
  Serial.print("AP IP: ");
  Serial.println(apIP);

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
  server.on("/rename", HTTP_GET, handleRename);

  server.begin();
  Serial.println("✓ Web server avviato");

  // Ripristina antenna
  if (selectedAntenna >= 0 && selectedAntenna < NUM_ANTENNAS) {
    Serial.print("Ripristino antenna: ");
    Serial.println(antennaNames[selectedAntenna]);
    digitalWrite(antennaPins[selectedAntenna], RELAY_ON);
  }

  Serial.println();
  Serial.println("═══════════════════════════════════════");
  Serial.println("  SISTEMA PRONTO!");
  Serial.println("═══════════════════════════════════════");
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
  json += ",\"apCli\":