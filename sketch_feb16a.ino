// ═══════════════════════════════════════════════════════════════════════════
//  ESP32 ANTENNA SWITCH v5.1
//
//  PORTE:
//   80   → fauxmoESP standalone (Alexa discovery + comandi)
//   8080 → HTTP pagina web  → http://IP:8080
//   8181 → TCP raw per app Processing
//
//  COMANDI ALEXA (via Routine app Alexa):
//   Routine trigger "seleziona DxCommander" → azione: accendi DxCommander
//   «Alexa, spegni antenne» → nativo, spegne tutto
//
//  LIBRERIE RICHIESTE:
//   "fauxmoESP"  di Xose Perez  (Gestione Librerie)
//   "AsyncTCP"   (dipendenza di fauxmoESP, Gestione Librerie)
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

int    selectedAntenna = -1;
String staSSID         = "";
String staPassword     = "";
bool   staConnected    = false;

unsigned long lastReconnect = 0;
unsigned long lastLedUpdate = 0;
bool          ledState      = false;

Preferences prefs;
WebServer   server(8080);    // pagina web porta 8080
WiFiServer  tcpServer(8181); // Processing porta 8181
WiFiClient  tcpClient;
fauxmoESP   fauxmo;          // Alexa porta 80 standalone

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

  // Aggiorna stato visibile ad Alexa
  for (int i = 0; i < NUM_ANTENNAS; i++)
    fauxmo.setState(i, (i == selectedAntenna), 255);
  fauxmo.setState(NUM_ANTENNAS, false, 0); // "Antenne" sempre off

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
//  PAGINA WEB HTML (porta 8080)
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
.alexa-box{background:#1a1040;border:1px solid #7b5ea7;border-radius:8px;padding:14px;font-size:13px;color:#c9b3f5;line-height:2.2}
.alexa-box strong{color:#a78bfa}
.alexa-box code{background:#2d1f5e;padding:2px 8px;border-radius:4px;font-size:12px}
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
  <div class="sub">ESP32 v5.1 — Web :8080 | Processing TCP :8181 | Alexa :80 🎙️</div>
</div>

<div class="status">
  <div class="status-item"><span class="led led-on"></span><span>Sistema: ON</span></div>
  <div class="status-item"><span class="led led-on"></span><span>AP: AntennaSwitch-AP</span></div>
  <div class="status-item"><span class="led led-off" id="ledSta"></span><span id="txtSta">Router: --</span></div>
  <div class="status-item"><span>🎯 <strong id="txtAnt">Nessuna</strong></span></div>
</div>

<div class="panel">
  <h2>🎙️ Comandi vocali Alexa</h2>
  <div class="alexa-box">
    <strong>Passo 1 — Prima volta:</strong><br>
    <code>Alexa, trova dispositivi</code> → deve trovare 7 device (6 antenne + Antenne)<br>
    <strong>Passo 2 — Crea Routine nell'app Alexa (una per antenna):</strong><br>
    Trigger: <code>seleziona DxCommander</code> → Azione: accendi DxCommander<br>
    Trigger: <code>seleziona Delta Loop</code> → Azione: accendi Delta Loop<br>
    <em>...ripeti per tutte le 6 antenne...</em><br>
    <strong>Passo 3 — Usa:</strong><br>
    <code>Alexa, seleziona DxCommander</code> &nbsp;|&nbsp; <code>Alexa, spegni antenne</code><br>
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
  <h2>📡 WiFi Router di casa</h2>
  <div class="info" id="staInfo">Nessun router configurato</div>
  <div class="form-group"><label>SSID:</label><input type="text" id="ssid" placeholder="Nome rete WiFi di casa"></div>
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
    document.getElementById('ledSta').className='led '+(d.staConn?'led-on':'led-off');
    document.getElementById('txtSta').textContent='Router: '+(d.staConn?d.staIP:'Non connesso');
    document.getElementById('txtAnt').textContent=cur>=0?d.ants[cur].name:'Nessuna antenna attiva';
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
      si.innerHTML='Nessun router configurato. Inserisci SSID e password.';
    }
    let up=Math.floor(d.uptime/60000);
    document.getElementById('info').innerHTML=
      'AP IP: <strong>192.168.4.1</strong><br>'+
      (d.staConn?'Router IP: <strong>'+d.staIP+'</strong><br>':'')+
      'Alexa: porta <strong>80</strong><br>'+
      'Processing TCP: porta <strong>8181</strong><br>'+
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
  if(s===''&&p===''){if(!confirm('Disconnettere il router?'))return;}
  fetch('/wifi?s='+encodeURIComponent(s)+'&p='+encodeURIComponent(p))
    .then(()=>{alert('Avviato...');setTimeout(upd,3000);});
}
function scan(){
  document.getElementById('scanRes').innerHTML='Scansione...';
  fetch('/scan').then(r=>r.json()).then(d=>{
    let h='';
    for(let n of d.nets)
      h+='<div class="scan-item" onclick="document.getElementById(\'ssid\').value=\''+n.ssid+'\'">📶 '+n.ssid+' ('+n.rssi+' dBm)</div>';
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
//  WEB HANDLERS (porta 8080)
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
  if (staSSID.length() > 0) {
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
    Serial.println("[WiFi] Connessione a: " + staSSID);
  } else {
    WiFi.disconnect();
    staConnected = false;
    Serial.println("[WiFi] Disconnesso");
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
//  TCP SERVER porta 8181 — app Processing
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
//  AGGIORNAMENTI PERIODICI
// ══════════════════════════════════════════════════════════════════════════

void updateWiFi() {
  if (staSSID.length() == 0) return;
  bool now = (WiFi.status() == WL_CONNECTED);
  if (now && !staConnected) {
    staConnected = true;
    Serial.print("[WiFi] Connesso! IP: "); Serial.println(WiFi.localIP());
  } else if (!now && staConnected) {
    staConnected = false;
    Serial.println("[WiFi] Disconnesso");
  } else if (!now && millis() - lastReconnect > 30000) {
    lastReconnect = millis();
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
    Serial.println("[WiFi] Riconnessione...");
  }
}

void updateLED() {
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

  Serial.println("═══════════════════════════════════════");
  Serial.println("  ESP32 ANTENNA SWITCH v5.1");
  Serial.println("  Alexa:80 | Web:8080 | TCP:8181");
  Serial.println("═══════════════════════════════════════");

  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  for (int i = 0; i < NUM_ANTENNAS; i++) {
    pinMode(antennaPins[i], OUTPUT);
    digitalWrite(antennaPins[i], RELAY_OFF);
  }

  prefs.begin("antswitch", false);
  selectedAntenna = prefs.getInt("sel", -1);
  staSSID         = prefs.getString("staSsid", "");
  staPassword     = prefs.getString("staPass", "");
  prefs.end();
  loadAntennaNames();

  Serial.println("[NVS] Antenna: " + (selectedAntenna >= 0 ? antennaNames[selectedAntenna] : "Nessuna"));

  // WiFi AP + Station
  WiFi.mode(WIFI_AP_STA);
  delay(100);
  WiFi.softAP(AP_SSID, AP_PASSWORD, 1, 0, 4);
  delay(500);
  Serial.print("[WiFi] AP IP: "); Serial.println(WiFi.softAPIP());

  if (staSSID.length() > 0) {
    Serial.print("[WiFi] Connessione a: "); Serial.println(staSSID);
    WiFi.begin(staSSID.c_str(), staPassword.c_str());
    int att = 0;
    while (WiFi.status() != WL_CONNECTED && att < 30) { delay(500); Serial.print("."); att++; }
    Serial.println();
    if (WiFi.status() == WL_CONNECTED) {
      staConnected = true;
      Serial.print("[WiFi] Connesso! IP: "); Serial.println(WiFi.localIP());
    } else {
      Serial.println("[WiFi] Fallito — configura dalla pagina web");
    }
  }

  // ── fauxmoESP — server standalone porta 80 ────────────────────────────
  // createServer(true) = fauxmo crea e gestisce il suo server HTTP su porta 80
  fauxmo.createServer(true);
  fauxmo.setPort(80);
  fauxmo.enable(true);

  // Aggiungi le 6 antenne
  for (int i = 0; i < NUM_ANTENNAS; i++) {
    fauxmo.addDevice(antennaNames[i].c_str());
    Serial.println("[ALEXA] Device [" + String(i) + "]: " + antennaNames[i]);
  }
  // Device speciale indice 6: "Antenne" → spegni tutto
  fauxmo.addDevice("Antenne");
  Serial.println("[ALEXA] Device [6]: Antenne (spegni tutto)");

  // Callback unico con device_id
  fauxmo.onSetState([](unsigned char device_id, const char* device_name, bool state, unsigned char value) {
    Serial.printf("[ALEXA] id=%d name=%s state=%s\n", device_id, device_name, state ? "ON" : "OFF");
    if (device_id < NUM_ANTENNAS) {
      if (state) selectAntenna(device_id);
      else       selectAntenna(-1);
    } else {
      // "Antenne" → spegni tutto
      selectAntenna(-1);
    }
  });

  // ── WebServer porta 8080 ───────────────────────────────────────────────
  server.on("/",       HTTP_GET, []() { server.send_P(200, "text/html", HTML_PAGE); });
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/sel",    HTTP_GET, handleSelect);
  server.on("/wifi",   HTTP_GET, handleWiFi);
  server.on("/scan",   HTTP_GET, handleScan);
  server.on("/rename", HTTP_GET, handleRename);
  server.begin();
  Serial.println("[WEB] HTTP server avviato su porta 8080");

  // ── TCP server porta 8181 per Processing ──────────────────────────────
  tcpServer.begin();
  Serial.println("[TCP] TCP server avviato su porta 8181");

  // Ripristina antenna salvata
  if (selectedAntenna >= 0 && selectedAntenna < NUM_ANTENNAS)
    digitalWrite(antennaPins[selectedAntenna], RELAY_ON);

  Serial.println("═══════════════════════════════════════");
  Serial.println("  SISTEMA PRONTO!");
  Serial.println("  Web:       http://192.168.4.1:8080");
  if (staConnected) { Serial.print("  Web:       http://"); Serial.print(WiFi.localIP()); Serial.println(":8080"); }
  Serial.println("  TCP Processing: IP:8181");
  Serial.println("  Poi: Alexa, trova dispositivi");
  Serial.println("═══════════════════════════════════════");
}

// ══════════════════════════════════════════════════════════════════════════
//  LOOP
// ══════════════════════════════════════════════════════════════════════════

void loop() {
  fauxmo.handle();       // Alexa discovery e comandi (porta 80)
  server.handleClient(); // pagina web (porta 8080)
  handleTCP();           // Processing TCP (porta 8181)
  handleSerial();        // comandi USB seriale
  updateWiFi();          // riconnessione router
  updateLED();           // LED stato
}
