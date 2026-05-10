// ═══════════════════════════════════════════════════════════════════════════
//  ESP32 ANTENNA SWITCH v3.0 - ALEXA + RELAY ATTIVI LOW + WEB INTERFACE
//  Access Point + Station + USB Serial + Web Interface + Alexa Voice Control
//
//  LIBRERIA RICHIESTA: "Espalexa-ESP32" di Aircoookie
//  Arduino IDE → Gestione librerie → cerca "Espalexa" → installa
//
//  UTILIZZO ALEXA (rete WiFi locale, no cloud):
//    "Alexa, accendi DxCommander"   → seleziona quell'antenna
//    "Alexa, spegni DxCommander"    → disattiva quell'antenna
//    Prima volta: "Alexa, trova dispositivi"
// ═══════════════════════════════════════════════════════════════════════════

#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <Espalexa.h>

// ── Forward declarations ───────────────────────────────────────────────────
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
void setupAlexaDevices();
void alexaCallback(EspalexaDevice* d);

// ══════════════════════════════════════════════════════════════════════════
//  CONFIGURAZIONE — modifica qui i nomi di default e i pin
// ══════════════════════════════════════════════════════════════════════════

#define NUM_ANTENNAS  6
#define LED_PIN       2
#define SERIAL_BAUD   9600

// Pin relè (modifica se hai cablato diversamente)
const int antennaPins[NUM_ANTENNAS] = {14, 27, 26, 25, 33, 32};

// Nomi di default — Alexa userà questi nomi al primo avvio.
// Puoi cambiarli dalla pagina web e poi ri-fare "Alexa, trova dispositivi".
// IMPORTANTE: usa nomi senza accenti per Alexa (es. "Dipolo Ottanta" non "Dipolo 80")
const char* defaultAntennaNames[NUM_ANTENNAS] = {
  "DxCommander",
  "Tre Elementi",
  "Delta Loop",
  "Verticale VHF",
  "Dipolo Ottanta",
  "Dipolo Quaranta"
};

// Nomi correnti (caricati da memoria NVS)
String antennaNames[NUM_ANTENNAS];

// Relè attivi LOW (modulo relè standard cinese)
#define RELAY_ON  LOW
#define RELAY_OFF HIGH

// Access Point dell'ESP32 (raggiungibile anche senza router)
const char* AP_SSID     = "AntennaSwitch-AP";
const char* AP_PASSWORD = "antenna123";

// ══════════════════════════════════════════════════════════════════════════
//  VARIABILI GLOBALI
// ══════════════════════════════════════════════════════════════════════════

int    selectedAntenna = -1;
bool   systemOn        = true;
String staSSID         = "";
String staPassword     = "";
bool   staConnected    = false;

unsigned long lastReconnect = 0;
unsigned long lastLedUpdate = 0;
bool          ledState      = false;

Preferences     prefs;
WebServer       server(80);
Espalexa        espalexa;
EspalexaDevice* alexaDevices[NUM_ANTENNAS];

// ══════════════════════════════════════════════════════════════════════════
//  PAGINA WEB (HTML/CSS/JS)
// ══════════════════════════════════════════════════════════════════════════

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
.sub{color:#888;font-size:12px;margin-top:4px}
.status{display:flex;gap:20px;background:#111;padding:15px;border-radius:8px;margin-bottom:20px;flex-wrap:wrap}
.status-item{display:flex;align-items:center;gap:8px;font-size:14px}
.led{width:12px;height:12px;border-radius:50%}
.led-on{background:#00ff88;box-shadow:0 0 8px #00ff88}
.led-off{background:#ff4444;box-shadow:0 0 8px #ff4444}
.panel{background:#111;padding:20px;border-radius:10px;margin-bottom:20px;border:1px solid #333}
h2{color:#00ff88;font-size:18px;margin-bottom:15px;border-bottom:1px solid #333;padding-bottom:10px}
.alexa-box{background:#1a1040;border:1px solid #7b5ea7;border-radius:8px;padding:14px;font-size:13px;color:#c9b3f5;line-height:1.8}
.alexa-box strong{color:#a78bfa}
.alexa-box code{background:#2d1f5e;padding:2px 6px;border-radius:4px;font-size:12px}
.antenna-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-top:12px}
.ant-btn{background:#1a1a1a;border:2px solid #444;border-radius:8px;padding:15px;cursor:pointer;transition:all 0.2s;position:relative;text-align:center}
.ant-btn:hover{border-color:#00ff88;transform:translateY(-2px)}
.ant-btn.active{background:#00ff88;color:#000;border-color:#00ff88;box-shadow:0 0 20px rgba(0,255,136,0.4)}
.ant-name{font-weight:bold;margin-bottom:5px;font-size:14px}
.ant-info{font-size:11px;opacity:0.7}
.led-ind{position:absolute;top:8px;right:8px;width:8px;height:8px;border-radius:50%}
.rename-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:10px}
.rename-item{display:flex;gap:8px;align-items:center}
.rename-item input{flex:1;padding:8px;background:#0a0a0a;border:1px solid #444;border-radius:6px;color:#fff;font-size:13px}
.rename-item span{color:#888;font-size:12px;min-width:55px}
.form-group{margin:15px 0}
label{display:block;color:#888;font-size:12px;margin-bottom:6px}
input[type=text],input[type=password]{width:100%;padding:10px;background:#0a0a0a;border:1px solid #444;border-radius:6px;color:#fff;font-size:14px}
.btn{display:inline-block;padding:12px 24px;background:#00ff88;color:#000;border:none;border-radius:6px;font-weight:bold;cursor:pointer;font-size:14px;margin-right:8px;margin-top:4px}
.btn:hover{background:#00dd77}
.btn-sec{background:#333;color:#fff}
.btn-sec:hover{background:#444}
.btn-danger{background:#ff4444;color:#fff}
.btn-danger:hover{background:#cc3333}
.btn-off{background:#555;color:#fff}
.info{background:#0a0a0a;border:1px solid #333;border-radius:6px;padding:12px;margin:10px 0;font-size:13px;line-height:1.6}
.info strong{color:#00ff88}
.scan-item{background:#1a1a1a;border:1px solid #333;padding:10px;margin:5px 0;border-radius:6px;cursor:pointer;font-size:13px}
.scan-item:hover{border-color:#00ff88}
.note{color:#888;font-size:12px;margin-top:8px}
</style>
</head>
<body>
<div class="container">

<div class="header">
  <h1>🛰️ Antenna Switch Control</h1>
  <div class="sub">ESP32 Controller v3.0 — Alexa Ready 🎙️</div>
</div>

<div class="status">
  <div class="status-item"><span class="led led-on" id="ledSys"></span><span id="txtSys">Sistema: ON</span></div>
  <div class="status-item"><span class="led led-on"></span><span>AP: AntennaSwitch-AP</span></div>
  <div class="status-item"><span class="led led-off" id="ledSta"></span><span id="txtSta">Router: --</span></div>
  <div class="status-item"><span>🎯 Antenna: <strong id="txtAnt">Nessuna</strong></span></div>
</div>

<div class="panel">
  <h2>🎙️ Comandi vocali Alexa</h2>
  <div class="alexa-box">
    <strong>Seleziona antenna:</strong><br>
    <code>«Alexa, accendi DxCommander»</code> → attiva quell'antenna (le altre si spengono)<br><br>
    <strong>Disattiva antenna:</strong><br>
    <code>«Alexa, spegni DxCommander»</code> → spegne quell'antenna<br><br>
    <strong>Prima volta o dopo rinomina:</strong><br>
    <code>«Alexa, trova dispositivi»</code> → Alexa scopre tutte le antenne<br><br>
    ⚠ <strong>Alexa e ESP32 devono essere sulla stessa rete WiFi di casa.</strong>
  </div>
</div>

<div class="panel">
  <h2>Seleziona Antenna</h2>
  <button class="btn btn-off" onclick="sel(-1)">⏹ DISATTIVA TUTTE</button>
  <div class="antenna-grid" id="grid"></div>
</div>

<div class="panel">
  <h2>⚙️ Rinomina Antenne</h2>
  <div class="rename-grid" id="renameGrid"></div>
  <br>
  <button class="btn" onclick="saveAllNames()">💾 SALVA NOMI</button>
  <p class="note">⚠ Dopo aver salvato: riavvia l'ESP32, poi di' «Alexa, trova dispositivi».</p>
</div>

<div class="panel">
  <h2>📡 WiFi Router di casa</h2>
  <div class="info" id="staInfo">Nessun router configurato</div>
  <div class="form-group"><label>Nome rete (SSID):</label><input type="text" id="ssid" placeholder="Nome rete WiFi di casa"></div>
  <div class="form-group"><label>Password:</label><input type="password" id="pass" placeholder="Password WiFi"></div>
  <button class="btn" onclick="saveWiFi()">🔗 CONNETTI</button>
  <button class="btn btn-sec" onclick="scan()">🔍 CERCA RETI</button>
  <button class="btn btn-danger" onclick="saveWiFi('','')">✖ DISCONNETTI</button>
  <div id="scanRes" style="margin-top:10px"></div>
</div>

<div class="panel">
  <h2>Info Sistema</h2>
  <div class="info" id="info">Caricamento...</div>
  <button class="btn btn-sec" onclick="upd()">🔄 AGGIORNA</button>
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
      let a=d.ants[i],act=(i===cur);
      g+='<div class="ant-btn'+(act?' active':'')+'" onclick="sel('+i+')">';
      g+='<div class="led-ind" style="background:'+(act?'#00ff88':'#333')+'"></div>';
      g+='<div class="ant-name">'+a.name+'</div>';
      g+='<div class="ant-info">Pin '+a.pin+'</div></div>';
    }
    document.getElementById('grid').innerHTML=g;
    let rg=document.getElementById('renameGrid');
    if(!rg.querySelector('input:focus')){
      let h='';
      for(let i=0;i<d.ants.length;i++){
        h+='<div class="rename-item"><span>ANT '+(i+1)+':</span>';
        h+='<input type="text" id="rn'+i+'" value="'+d.ants[i].name+'" maxlength="24"></div>';
      }
      rg.innerHTML=h;
    }
    let si=document.getElementById('staInfo');
    if(d.staConn){
      si.innerHTML='<strong style="color:#00ff88">✓ Connesso!</strong><br>SSID: <strong>'+d.staSsid+'</strong><br>IP: <strong>'+d.staIP+'</strong><br>Segnale: <strong>'+d.staRssi+' dBm</strong>';
    }else if(d.staSsid.length>0){
      si.innerHTML='<strong style="color:#ffaa00">⚠ Connessione in corso...</strong><br>SSID: <strong>'+d.staSsid+'</strong>';
    }else{
      si.innerHTML='Nessun router configurato.<br>Inserisci SSID e password qui sotto.';
    }
    let upMin=Math.floor(d.uptime/60000);
    document.getElementById('info').innerHTML=
      'AP IP (senza router): <strong>192.168.4.1</strong><br>'+
      (d.staConn?'Router IP: <strong>'+d.staIP+'</strong><br>':'')+
      'Uptime: <strong>'+upMin+' min</strong><br>'+
      'Client AP: <strong>'+d.apCli+'</strong>';
  }).catch(e=>console.error(e));
}
function sel(i){fetch('/sel?a='+i).then(()=>upd());}
function saveAllNames(){
  let p=[];
  for(let i=0;i<6;i++){
    let el=document.getElementById('rn'+i);
    if(el){let n=el.value.trim()||('Antenna '+(i+1));p.push(fetch('/rename?i='+i+'&n='+encodeURIComponent(n)));}
  }
  Promise.all(p).then(()=>alert('✓ Nomi salvati!\nRiavvia ESP32 e di\' «Alexa, trova dispositivi».'));
}
function saveWiFi(s,p){
  s=s!==undefined?s:document.getElementById('ssid').value.trim();
  p=p!==undefined?p:document.getElementById('pass').value;
  if(s===''&&p===''){if(!confirm('Disconnettere il router?'))return;}
  fetch('/wifi?s='+encodeURIComponent(s)+'&p='+encodeURIComponent(p))
    .then(()=>{alert('Operazione avviata...');setTimeout(upd,3000);});
}
function scan(){
  document.getElementById('scanRes').innerHTML='Scansione in corso...';
  fetch('/scan').then(r=>r.json()).then(d=>{
    let h='';
    for(let n of d.nets){
      h+='<div class="scan-item" onclick="document.getElementById(\'ssid\').value=\''+n.ssid+'\'">'+
        '📶 '+n.ssid+' ('+n.rssi+' dBm)</div>';
    }
    document.getElementById('scanRes').innerHTML=h||'Nessuna rete trovata';
  });
}
setInterval(upd,2000);
upd();
</script>
</body>
</html>
)rawliteral";

// ══════════════════════════════════════════════════════════════════════════
//  NVS — salvataggio persistente nomi antenne
// ══════════════════════════════════════════════════════════════════════════

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
  prefs.putString(("aname" + String(idx)).c_str(), name);
  prefs.end();
}

// ══════════════════════════════════════════════════════════════════════════
//  SELEZIONE ANTENNA — unico punto di controllo dei relè
// ══════════════════════════════════════════════════════════════════════════

void selectAntenna(int index) {
  // Spegni TUTTI i relè prima
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    digitalWrite(antennaPins[i], RELAY_OFF);
  }

  if (index >= 0 && index < NUM_ANTENNAS) {
    selectedAntenna = index;
    digitalWrite(antennaPins[index], RELAY_ON);
    Serial.println("[ANT] Selezionata: " + antennaNames[index] + " (pin " + String(antennaPins[index]) + ")");
  } else {
    selectedAntenna = -1;
    Serial.println("[ANT] Tutte disattivate");
  }

  // Salva in NVS per ripristino al riavvio
  prefs.begin("antswitch", false);
  prefs.putInt("sel", selectedAntenna);
  prefs.end();

  // Sincronizza stato Alexa: solo l'antenna attiva risulta "accesa"
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    if (alexaDevices[i] != nullptr) {
      alexaDevices[i]->setValue(i == selectedAntenna ? 255 : 0);
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  ALEXA CALLBACK — chiamato ogni volta che Alexa accende/spegne un device
// ══════════════════════════════════════════════════════════════════════════

void alexaCallback(EspalexaDevice* d) {
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    if (alexaDevices[i] == d) {
      if (d->getState()) {
        // "Alexa, accendi [nome]" → seleziona questa antenna
        Serial.println("[ALEXA] Accendi: " + antennaNames[i]);
        selectAntenna(i);
      } else {
        // "Alexa, spegni [nome]" → disattiva solo se è quella attiva
        Serial.println("[ALEXA] Spegni: " + antennaNames[i]);
        if (selectedAntenna == i) selectAntenna(-1);
      }
      return;
    }
  }
}

// Registra le 6 antenne come dispositivi Alexa (tipo "luce on/off")
void setupAlexaDevices() {
  Serial.println("[ALEXA] Registro dispositivi:");
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    alexaDevices[i] = espalexa.addDevice(antennaNames[i], alexaCallback);
    alexaDevices[i]->setValue(i == selectedAntenna ? 255 : 0);
    Serial.println("  [" + String(i) + "] " + antennaNames[i]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  WEB HANDLERS
// ══════════════════════════════════════════════════════════════════════════

void handleStatus() {
  String json = "{";
  json += "\"on\":"      + String(systemOn    ? "true" : "false");
  json += ",\"sel\":"    + String(selectedAntenna);
  json += ",\"staConn\":" + String(staConnected ? "true" : "false");
  json += ",\"staSsid\":\"" + staSSID + "\"";
  json += ",\"staIP\":\""   + (staConnected ? WiFi.localIP().toString() : String("")) + "\"";
  json += ",\"staRssi\":"   + String(WiFi.RSSI());
  json += ",\"apCli\":"     + String(WiFi.softAPgetStationNum());
  json += ",\"uptime\":"    + String(millis());
  json += ",\"ants\":[";
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    if (i > 0) json += ",";
    json += "{\"name\":\"" + antennaNames[i] + "\",\"pin\":" + String(antennaPins[i]) + "}";
  }
  json += "]}";
  server.send(200, "application/json", json);
}

void handleSelect() {
  if (!server.hasArg("a")) { server.send(400, "text/plain", "Missing param 'a'"); return; }
  selectAntenna(server.arg("a").toInt());
  server.send(200, "text/plain", "OK");
}

void handleWiFi() {
  staSSID     = server.hasArg("s") ? server.arg("s") : "";
  staPassword = server.hasArg("p") ? server.arg("p") : "";
  prefs.begin("antswitch", false);
  prefs.putString("staSsid", staSSID);
  prefs.putString("staPass", staPassword);
  prefs.end();
  if (staSSID.length() > 0) {
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
    Serial.println("[WiFi] Connessione a: " + staSSID);
  } else {
    WiFi.disconnect();
    staConnected = false;
    Serial.println("[WiFi] Disconnesso dal router");
  }
  server.send(200, "text/plain", "OK");
}

void handleScan() {
  int n = WiFi.scanNetworks();
  String json = "{\"nets\":[";
  for (int i = 0; i < n && i < 20; i++) {
    if (i > 0) json += ",";
    json += "{\"ssid\":\"" + WiFi.SSID(i) + "\",\"rssi\":" + String(WiFi.RSSI(i)) + "}";
  }
  json += "]}";
  WiFi.scanDelete();
  server.send(200, "application/json", json);
}

void handleRename() {
  if (!server.hasArg("i") || !server.hasArg("n")) { server.send(400, "text/plain", "Missing params"); return; }
  int    idx  = server.arg("i").toInt();
  String name = server.arg("n");
  name.trim();
  if (name.length() == 0) name = "Antenna " + String(idx + 1);
  saveAntennaName(idx, name);
  Serial.println("[RENAME] Antenna " + String(idx) + " → " + name);
  server.send(200, "text/plain", "OK");
}

void handleSerial() {
  while (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.length() > 0) processCommand(cmd);
  }
}

void processCommand(String cmd) {
  cmd.toUpperCase();
  if (cmd.startsWith("ANT:")) {
    selectAntenna(cmd.substring(4).toInt());
  } else if (cmd == "OFF") {
    selectAntenna(-1);
  } else if (cmd == "STATUS") {
    Serial.println("Antenna: " + (selectedAntenna >= 0 ? antennaNames[selectedAntenna] : "Nessuna"));
    Serial.println("WiFi: " + String(staConnected ? WiFi.localIP().toString() : "Non connesso"));
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  AGGIORNAMENTI PERIODICI
// ══════════════════════════════════════════════════════════════════════════

void updateWiFi() {
  if (staSSID.length() == 0) return;
  bool now = (WiFi.status() == WL_CONNECTED);
  if (now && !staConnected) {
    staConnected = true;
    Serial.print("[WiFi] Connesso! IP: ");
    Serial.println(WiFi.localIP());
  } else if (!now && staConnected) {
    staConnected = false;
    Serial.println("[WiFi] Disconnesso dal router");
  } else if (!now && millis() - lastReconnect > 30000) {
    lastReconnect = millis();
    Serial.println("[WiFi] Tentativo riconnessione...");
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
  }
}

void updateLED() {
  // LED lampeggia lento se antenna attiva, veloce se nessuna antenna
  unsigned long interval = (selectedAntenna >= 0) ? 2000 : 400;
  if (millis() - lastLedUpdate > interval) {
    lastLedUpdate = millis();
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState);
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  SETUP
// ══════════════════════════════════════════════════════════════════════════

void setup() {
  Serial.begin(SERIAL_BAUD);
  delay(500);

  Serial.println();
  Serial.println("═══════════════════════════════════════");
  Serial.println("  ESP32 ANTENNA SWITCH v3.0 + ALEXA");
  Serial.println("═══════════════════════════════════════");

  // LED
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Relè — tutti spenti all'avvio
  Serial.println("[RELAY] Inizializzazione pin relè (attivi LOW)...");
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    pinMode(antennaPins[i], OUTPUT);
    digitalWrite(antennaPins[i], RELAY_OFF);
    Serial.println("  Pin " + String(antennaPins[i]) + " → OFF");
  }

  // Leggi preferenze salvate
  prefs.begin("antswitch", false);
  selectedAntenna = prefs.getInt("sel", -1);
  staSSID         = prefs.getString("staSsid", "");
  staPassword     = prefs.getString("staPass", "");
  prefs.end();
  loadAntennaNames();

  Serial.println("[NVS] Antenna salvata: " + (selectedAntenna >= 0 ? antennaNames[selectedAntenna] : "Nessuna"));

  // WiFi: AP + Station contemporaneamente
  WiFi.mode(WIFI_AP_STA);
  delay(100);

  // Avvia Access Point (raggiungibile sempre su 192.168.4.1)
  WiFi.softAP(AP_SSID, AP_PASSWORD, 1, 0, 4);
  delay(500);
  Serial.print("[WiFi] AP IP: ");
  Serial.println(WiFi.softAPIP());

  // Connetti al router di casa se configurato
  if (staSSID.length() > 0) {
    Serial.print("[WiFi] Connessione a router: ");
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
      Serial.print("[WiFi] ✓ Router connesso! IP: ");
      Serial.println(WiFi.localIP());
      Serial.println("[ALEXA] Alexa DEVE essere sulla stessa rete: " + staSSID);
    } else {
      Serial.println("[WiFi] ✗ Connessione router fallita (riprova dalla pagina web)");
    }
  }

  // ── Web server ─────────────────────────────────────────────────────────
  server.on("/",       HTTP_GET, []() { server.send_P(200, "text/html", HTML_PAGE); });
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/sel",    HTTP_GET, handleSelect);
  server.on("/wifi",   HTTP_GET, handleWiFi);
  server.on("/scan",   HTTP_GET, handleScan);
  server.on("/rename", HTTP_GET, handleRename);

  // IMPORTANTE: questo handler catch-all deve essere l'ULTIMO.
  // Passa le richieste sconosciute a Espalexa (discovery Alexa, API Hue).
  server.onNotFound([]() {
    if (!espalexa.handleAlexaApiCall(server.uri(), server.arg("plain")))
      server.send(404, "text/plain", "Not found");
  });

  // ── Registra dispositivi Alexa e avvia tutto ───────────────────────────
  setupAlexaDevices();
  espalexa.begin(&server); // condivide il WebServer esistente
  server.begin();
  Serial.println("[WEB] ✓ Web server avviato");

  // Ripristina antenna selezionata prima dello spegnimento
  if (selectedAntenna >= 0 && selectedAntenna < NUM_ANTENNAS) {
    digitalWrite(antennaPins[selectedAntenna], RELAY_ON);
    Serial.println("[ANT] Antenna ripristinata: " + antennaNames[selectedAntenna]);
  }

  Serial.println();
  Serial.println("═══════════════════════════════════════");
  Serial.println("  SISTEMA PRONTO!");
  Serial.println("  Pagina web: http://192.168.4.1");
  if (staConnected) {
    Serial.print("  Pagina web: http://");
    Serial.println(WiFi.localIP());
  }
  Serial.println("  Di' «Alexa, trova dispositivi»");
  Serial.println("═══════════════════════════════════════");
}

// ══════════════════════════════════════════════════════════════════════════
//  LOOP
// ══════════════════════════════════════════════════════════════════════════

void loop() {
  espalexa.loop();        // gestisce discovery UPnP/SSDP di Alexa
  server.handleClient();  // gestisce le richieste web
  handleSerial();         // comandi seriali USB
  updateWiFi();           // riconnessione automatica router
  updateLED();            // lampeggio LED di stato
}
