// ═══════════════════════════════════════════════════════════════════════════
//  ESP32 ANTENNA SWITCH v5.2
//
//  AVVIO:
//   1) ESP32 parte SEMPRE come AP "AntennaSwitch-AP" (password: antenna123)
//   2) Apri http://192.168.4.1:8080 → sezione WiFi → inserisci SSID+pass → CONNETTI
//   3) ESP32 si connette al router in background (nessun blocco)
//   4) Sul Monitor Seriale vedi l'IP assegnato dal router
//
//  PORTE:
//   80   → fauxmoESP (Alexa)
//   8080 → Pagina web
//   8181 → TCP raw per app Processing
//
//  LIBRERIE: "fauxmoESP" + "AsyncTCP" (Gestione Librerie Arduino)
// ═══════════════════════════════════════════════════════════════════════════

#include <WiFi.h>
#include <WebServer.h>
#include <WiFiServer.h>
#include <WiFiClient.h>
#include <Preferences.h>
#include <fauxmoESP.h>

// ══════════════════════════════════════════════════════════════════════════
//  CONFIGURAZIONE
// ══════════════════════════════════════════════════════════════════════════

#define NUM_ANTENNAS  6
#define LED_PIN       2
#define SERIAL_BAUD   9600

const int antennaPins[NUM_ANTENNAS] = {14, 27, 26, 25, 33, 32};

const char* defaultAntennaNames[NUM_ANTENNAS] = {
  "DxCommander",
  "Tre Elementi",
  "Delta Loop",
  "Verticale VHF",
  "Dipolo Ottanta",
  "Dipolo Quaranta"
};

String antennaNames[NUM_ANTENNAS];

#define RELAY_ON  LOW
#define RELAY_OFF HIGH

const char* AP_SSID     = "AntennaSwitch-AP";
const char* AP_PASSWORD = "antenna123";

// ══════════════════════════════════════════════════════════════════════════
//  VARIABILI GLOBALI
// ══════════════════════════════════════════════════════════════════════════

int    selectedAntenna  = -1;
String staSSID          = "";
String staPassword      = "";
bool   staConnected     = false;
bool   staConnecting    = false;   // true mentre tenta la connessione al router

unsigned long lastReconnect  = 0;
unsigned long lastLedUpdate  = 0;
unsigned long connectStart   = 0;
bool          ledState       = false;

Preferences prefs;
WebServer   server(8080);    // pagina web
WiFiServer  tcpServer(8181); // Processing
WiFiClient  tcpClient;
fauxmoESP   fauxmo;

// ══════════════════════════════════════════════════════════════════════════
//  FORWARD DECLARATIONS
// ══════════════════════════════════════════════════════════════════════════

void selectAntenna(int index);
void loadAntennaNames();
void saveAntennaName(int idx, String name);
void handleStatus();
void handleSelect();
void handleWiFi();
void handleScan();
void handleRename();
void handleSerial();
void handleTCP();
void processCommand(String cmd);
void updateWiFi();
void updateLED();
void startConnectToRouter();

// ══════════════════════════════════════════════════════════════════════════
//  SELEZIONE ANTENNA
// ══════════════════════════════════════════════════════════════════════════

void selectAntenna(int index) {
  for (int i = 0; i < NUM_ANTENNAS; i++)
    digitalWrite(antennaPins[i], RELAY_OFF);

  if (index >= 0 && index < NUM_ANTENNAS) {
    selectedAntenna = index;
    digitalWrite(antennaPins[index], RELAY_ON);
    Serial.println("[ANT] Selezionata: " + antennaNames[index]);
    if (tcpClient && tcpClient.connected())
      tcpClient.println("ANT:" + String(index) + ":" + String(antennaPins[index]));
  } else {
    selectedAntenna = -1;
    Serial.println("[ANT] Tutte disattivate");
    if (tcpClient && tcpClient.connected())
      tcpClient.println("ANT:-1:0");
  }

  for (int i = 0; i < NUM_ANTENNAS; i++)
    fauxmo.setState(i, (i == selectedAntenna), 255);
  fauxmo.setState(NUM_ANTENNAS, false, 0);

  prefs.begin("antswitch", false);
  prefs.putInt("sel", selectedAntenna);
  prefs.end();
}

// ══════════════════════════════════════════════════════════════════════════
//  NVS
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
//  CONNESSIONE ROUTER (non bloccante)
// ══════════════════════════════════════════════════════════════════════════

void startConnectToRouter() {
  if (staSSID.length() == 0) return;
  Serial.println("[WiFi] Avvio connessione a: " + staSSID);
  WiFi.begin(staSSID.c_str(), staPassword.c_str());
  staConnecting = true;
  connectStart  = millis();
  lastReconnect = millis();
}

void updateWiFi() {
  if (staSSID.length() == 0) return;

  bool now = (WiFi.status() == WL_CONNECTED);

  if (now && !staConnected) {
    // Appena connesso
    staConnected  = true;
    staConnecting = false;
    Serial.print("[WiFi] ✓ Connesso al router! IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("[WEB] Pagina web: http://");
    Serial.print(WiFi.localIP());
    Serial.println(":8080");
    return;
  }

  if (!now && staConnected) {
    // Connessione persa
    staConnected  = false;
    staConnecting = true;
    connectStart  = millis();
    Serial.println("[WiFi] Connessione persa, riprovo...");
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
    return;
  }

  if (!now && staConnecting) {
    // Timeout tentativo (20s) → riprova
    if (millis() - connectStart > 20000) {
      Serial.println("[WiFi] Timeout, riprovo...");
      WiFi.disconnect();
      delay(100);
      WiFi.begin(staSSID.c_str(), staPassword.c_str());
      connectStart = millis();
    }
    return;
  }

  if (!now && !staConnecting && millis() - lastReconnect > 30000) {
    // Riconnessione periodica
    lastReconnect = millis();
    startConnectToRouter();
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  PAGINA WEB HTML
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
.led-wait{background:#ffaa00;box-shadow:0 0 8px #ffaa00}
.panel{background:#111;padding:20px;border-radius:10px;margin-bottom:20px;border:1px solid #333}
h2{color:#00ff88;font-size:18px;margin-bottom:15px;border-bottom:1px solid #333;padding-bottom:10px}
.alexa-box{background:#1a1040;border:1px solid #7b5ea7;border-radius:8px;padding:14px;font-size:13px;color:#c9b3f5;line-height:2.2}
.alexa-box strong{color:#a78bfa}
.alexa-box code{background:#2d1f5e;padding:2px 8px;border-radius:4px;font-size:12px}
.wifi-box{background:#0a1a0a;border:2px solid #00ff88;border-radius:8px;padding:16px;margin-bottom:15px;font-size:13px;color:#aaffaa}
.wifi-box strong{color:#00ff88;font-size:15px}
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
.btn-sec{background:#333;color:#fff}.btn-sec:hover{background:#444}
.btn-danger{background:#ff4444;color:#fff}.btn-danger:hover{background:#cc3333}
.btn-off{background:#555;color:#fff}
.info{background:#0a0a0a;border:1px solid #333;border-radius:6px;padding:12px;margin:10px 0;font-size:13px;line-height:1.8}
.info strong{color:#00ff88}
.scan-item{background:#1a1a1a;border:1px solid #333;padding:10px;margin:5px 0;border-radius:6px;cursor:pointer;font-size:13px}
.scan-item:hover{border-color:#00ff88}
.note{color:#ffaa00;font-size:12px;margin-top:10px}
</style>
</head>
<body>
<div class="container">

<div class="header">
  <h1>🛰️ Antenna Switch Control</h1>
  <div class="sub">ESP32 v5.2 — Web :8080 | Processing TCP :8181 | Alexa :80 🎙️</div>
</div>

<div class="status">
  <div class="status-item"><span class="led led-on"></span><span>AP: AntennaSwitch-AP ✓</span></div>
  <div class="status-item"><span class="led" id="ledSta"></span><span id="txtSta">Router: --</span></div>
  <div class="status-item"><span>🎯 <strong id="txtAnt">Nessuna</strong></span></div>
</div>

<div class="panel">
  <h2>📡 WiFi Router di casa</h2>
  <div id="staInfo" class="wifi-box"><strong>⚙ In attesa configurazione</strong><br>Inserisci SSID e password qui sotto, poi clicca CONNETTI.</div>
  <div class="form-group"><label>Nome rete (SSID):</label><input type="text" id="ssid" placeholder="Nome rete WiFi di casa"></div>
  <div class="form-group"><label>Password:</label><input type="password" id="pass" placeholder="Password WiFi"></div>
  <button class="btn" onclick="saveWiFi()">🔗 CONNETTI</button>
  <button class="btn btn-sec" onclick="scan()">🔍 CERCA RETI</button>
  <button class="btn btn-danger" onclick="saveWiFi('','')">✖ DIMENTICA</button>
  <div id="scanRes" style="margin-top:10px"></div>
</div>

<div class="panel">
  <h2>🎙️ Comandi vocali Alexa</h2>
  <div class="alexa-box">
    <strong>Passo 1:</strong> Connetti ESP32 al router WiFi (sezione sopra)<br>
    <strong>Passo 2:</strong> <code>Alexa, trova dispositivi</code> → trova 7 device<br>
    <strong>Passo 3:</strong> Crea Routine nell'app Alexa per ogni antenna:<br>
    Trigger: <code>seleziona DxCommander</code> → Azione: accendi DxCommander<br>
    <strong>Uso:</strong> <code>Alexa, seleziona DxCommander</code> &nbsp;|&nbsp; <code>Alexa, spegni antenne</code><br>
    ⚠ <strong>ESP32 e Alexa devono essere sulla stessa rete WiFi di casa.</strong>
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
  <p class="note">⚠ Dopo rinomina: riavvia ESP32 → Alexa trova dispositivi → ricrea Routine.</p>
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
    // LED router
    let lc='led ';
    if(d.staConn) lc+='led-on';
    else if(d.staConn===false && d.staSsid.length>0) lc+='led-wait';
    else lc+='led-off';
    document.getElementById('ledSta').className=lc;
    document.getElementById('txtSta').textContent='Router: '+(d.staConn?d.staIP:(d.staSsid.length>0?'Connessione...':'Non configurato'));
    document.getElementById('txtAnt').textContent=cur>=0?d.ants[cur].name:'Nessuna antenna attiva';
    // Griglia antenne
    let g='';
    for(let i=0;i<d.ants.length;i++){
      let a=d.ants[i],act=(i===cur);
      g+='<div class="ant-btn'+(act?' active':'')+'" onclick="sel('+i+')">';
      g+='<div class="led-ind" style="background:'+(act?'#00ff88':'#333')+'"></div>';
      g+='<div class="ant-name">'+a.name+'</div>';
      g+='<div class="ant-info">Pin '+a.pin+'</div></div>';
    }
    document.getElementById('grid').innerHTML=g;
    // Rinomina
    let rg=document.getElementById('renameGrid');
    if(!rg.querySelector('input:focus')){
      let h='';
      for(let i=0;i<d.ants.length;i++){
        h+='<div class="rename-item"><span>ANT '+(i+1)+':</span>';
        h+='<input type="text" id="rn'+i+'" value="'+d.ants[i].name+'" maxlength="24"></div>';
      }
      rg.innerHTML=h;
    }
    // Box WiFi
    let si=document.getElementById('staInfo');
    if(d.staConn){
      si.innerHTML='<strong style="color:#00ff88">✓ Connesso al router!</strong><br>SSID: <strong>'+d.staSsid+'</strong><br>IP: <strong>'+d.staIP+'</strong><br>Segnale: <strong>'+d.staRssi+' dBm</strong><br><small style="color:#888">Usa questo IP nell\'app Processing (porta 8181) e per Alexa.</small>';
      document.getElementById('ssid').value=d.staSsid;
    }else if(d.staSsid.length>0){
      si.innerHTML='<strong style="color:#ffaa00">⏳ Connessione in corso a: '+d.staSsid+'</strong><br><small>Attendi qualche secondo...</small>';
    }else{
      si.innerHTML='<strong style="color:#ff8844">⚙ Nessun router configurato</strong><br>Inserisci SSID e password, poi clicca CONNETTI.';
    }
    // Info
    let up=Math.floor(d.uptime/60000);
    document.getElementById('info').innerHTML=
      'AP (sempre attivo): <strong>192.168.4.1:8080</strong><br>'+
      (d.staConn?'Router IP: <strong>'+d.staIP+'</strong><br>':'')+
      'Alexa porta: <strong>80</strong><br>'+
      'Processing TCP porta: <strong>8181</strong><br>'+
      'Uptime: <strong>'+up+' min</strong><br>'+
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
  Promise.all(p).then(()=>alert('Nomi salvati!\nRiavvia ESP32 poi: Alexa, trova dispositivi'));
}
function saveWiFi(s,p){
  s=s!==undefined?s:document.getElementById('ssid').value.trim();
  p=p!==undefined?p:document.getElementById('pass').value;
  if(s===''&&p===''){if(!confirm('Dimenticare il router?'))return;}
  fetch('/wifi?s='+encodeURIComponent(s)+'&p='+encodeURIComponent(p))
    .then(()=>{
      document.getElementById('staInfo').innerHTML='<strong style="color:#ffaa00">⏳ Connessione avviata...</strong><br>Attendi qualche secondo.';
      setTimeout(upd,4000);
    });
}
function scan(){
  document.getElementById('scanRes').innerHTML='<span style="color:#888">Scansione reti in corso...</span>';
  fetch('/scan').then(r=>r.json()).then(d=>{
    let h='';
    for(let n of d.nets)
      h+='<div class="scan-item" onclick="document.getElementById(\'ssid\').value=\''+n.ssid+'\'">📶 <strong>'+n.ssid+'</strong> ('+n.rssi+' dBm)</div>';
    document.getElementById('scanRes').innerHTML=h||'Nessuna rete trovata';
  });
}
setInterval(upd,3000);
upd();
</script>
</body>
</html>
)rawliteral";

// ══════════════════════════════════════════════════════════════════════════
//  WEB HANDLERS
// ══════════════════════════════════════════════════════════════════════════

void handleStatus() {
  String json = "{";
  json += "\"sel\":"        + String(selectedAntenna);
  json += ",\"staConn\":"   + String(staConnected ? "true" : "false");
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
  if (!server.hasArg("a")) { server.send(400, "text/plain", "Missing param"); return; }
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
  staConnected  = false;
  staConnecting = false;
  WiFi.disconnect();
  delay(200);
  if (staSSID.length() > 0) {
    startConnectToRouter();
  } else {
    Serial.println("[WiFi] Credenziali cancellate");
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
  Serial.println("[RENAME] Antenna " + String(idx) + " -> " + name);
  server.send(200, "text/plain", "OK");
}

// ══════════════════════════════════════════════════════════════════════════
//  TCP SERVER porta 8181
// ══════════════════════════════════════════════════════════════════════════

void handleTCP() {
  if (tcpServer.hasClient()) {
    if (tcpClient && tcpClient.connected()) tcpClient.stop();
    tcpClient = tcpServer.accept();
    Serial.println("[TCP] Processing connesso: " + tcpClient.remoteIP().toString());
    tcpClient.println("STATUS:ANT:" + String(selectedAntenna));
  }
  if (tcpClient && tcpClient.connected() && tcpClient.available()) {
    String cmd = tcpClient.readStringUntil('\n');
    cmd.trim();
    if (cmd.length() > 0) { Serial.println("[TCP] Cmd: " + cmd); processCommand(cmd); }
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  SERIALE USB
// ══════════════════════════════════════════════════════════════════════════

void handleSerial() {
  while (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd.length() > 0) processCommand(cmd);
  }
}

void processCommand(String cmd) {
  String up = cmd; up.toUpperCase();
  if      (up.startsWith("ANT:"))        selectAntenna(cmd.substring(4).toInt());
  else if (up == "OFF" || up == "PWR:0") selectAntenna(-1);
  else if (up == "STATUS") {
    String r = "ANT:" + String(selectedAntenna) + ":" +
               (selectedAntenna >= 0 ? antennaNames[selectedAntenna] : "NONE");
    Serial.println(r);
    if (tcpClient && tcpClient.connected()) tcpClient.println(r);
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  LED
// ══════════════════════════════════════════════════════════════════════════

void updateLED() {
  // Lento 2s = antenna attiva | Veloce 300ms = nessuna antenna
  unsigned long interval = (selectedAntenna >= 0) ? 2000 : 300;
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
  delay(300);

  Serial.println();
  Serial.println("═══════════════════════════════════════");
  Serial.println("  ESP32 ANTENNA SWITCH v5.2");
  Serial.println("═══════════════════════════════════════");

  // LED e relè
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    pinMode(antennaPins[i], OUTPUT);
    digitalWrite(antennaPins[i], RELAY_OFF);
  }

  // Carica dati salvati
  prefs.begin("antswitch", false);
  selectedAntenna = prefs.getInt("sel", -1);
  staSSID         = prefs.getString("staSsid", "");
  staPassword     = prefs.getString("staPass", "");
  prefs.end();
  loadAntennaNames();

  // ── WiFi: prima parte SOLO l'AP ──────────────────────────────────────
  WiFi.mode(WIFI_AP_STA);
  delay(100);
  WiFi.softAP(AP_SSID, AP_PASSWORD, 1, 0, 4);
  delay(500);
  Serial.println("[WiFi] ✓ AP avviato!");
  Serial.print("[WiFi] AP IP: "); Serial.println(WiFi.softAPIP());
  Serial.println("[WEB] Pagina web: http://192.168.4.1:8080");
  Serial.println("[WiFi] Connettiti all'AP e configura il router dalla pagina web.");

  // ── fauxmoESP porta 80 ────────────────────────────────────────────────
  fauxmo.createServer(true);
  fauxmo.setPort(80);
  fauxmo.enable(true);
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    fauxmo.addDevice(antennaNames[i].c_str());
    Serial.println("[ALEXA] Device [" + String(i) + "]: " + antennaNames[i]);
  }
  fauxmo.addDevice("Antenne");
  Serial.println("[ALEXA] Device [6]: Antenne (spegni tutto)");

  fauxmo.onSetState([](unsigned char device_id, const char* device_name, bool state, unsigned char value) {
    Serial.printf("[ALEXA] id=%d name=%s state=%s\n", device_id, device_name, state ? "ON" : "OFF");
    if (device_id < NUM_ANTENNAS) {
      if (state) selectAntenna(device_id);
      else       selectAntenna(-1);
    } else {
      selectAntenna(-1);
    }
  });

  // ── WebServer porta 8080 ──────────────────────────────────────────────
  server.on("/",       HTTP_GET, []() { server.send_P(200, "text/html", HTML_PAGE); });
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/sel",    HTTP_GET, handleSelect);
  server.on("/wifi",   HTTP_GET, handleWiFi);
  server.on("/scan",   HTTP_GET, handleScan);
  server.on("/rename", HTTP_GET, handleRename);
  server.begin();
  Serial.println("[WEB] HTTP server avviato su porta 8080");

  // ── TCP porta 8181 ────────────────────────────────��───────────────────
  tcpServer.begin();
  Serial.println("[TCP] TCP server avviato su porta 8181");

  // Ripristina antenna
  if (selectedAntenna >= 0 && selectedAntenna < NUM_ANTENNAS)
    digitalWrite(antennaPins[selectedAntenna], RELAY_ON);

  // Se c'erano credenziali salvate avvia connessione in background
  if (staSSID.length() > 0) {
    Serial.println("[WiFi] Credenziali salvate trovate, connessione in background a: " + staSSID);
    startConnectToRouter();
  }

  Serial.println("═══════════════════════════════════════");
  Serial.println("  SISTEMA PRONTO!");
  Serial.println("  1) Connettiti a: AntennaSwitch-AP");
  Serial.println("     Password: antenna123");
  Serial.println("  2) Apri: http://192.168.4.1:8080");
  Serial.println("  3) Inserisci WiFi di casa → CONNETTI");
  Serial.println("═══════════════════════════════════════");
}

// ══════════════════════════════════════════════════════════════════════════
//  LOOP
// ══════════════════════════════════════════════════════════════════════════

void loop() {
  fauxmo.handle();       // Alexa (porta 80)
  server.handleClient(); // pagina web (porta 8080)
  handleTCP();           // Processing (porta 8181)
  handleSerial();        // USB seriale
  updateWiFi();          // connessione router non bloccante
  updateLED();           // LED stato
}
