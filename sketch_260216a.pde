

import processing.serial.*;
import processing.net.*;
import java.util.*;
import java.text.SimpleDateFormat;

// ═══════════════════════════════════════════════════════════════════════════
//  CONFIGURAZIONE GLOBALE
// ═══════════════════════════════════════════════════════════════════════════

final String APP_NAME = "Remote Control";
final String APP_VERSION = "3.0";

// ═══════════════════════════════════════════════════════════════════════════
//  TEMA COLORI
// ═══════════════════════════════════════════════════════════════════════════

class ThemeColors {
  color primary = #000000;
  color secondary = #1A1A1A;
  color accent = #00FF88;
  color background = #0A0A0A;
  color panel = #111111;
  color panelLight = #1E1E1E;
  color text = #FFFFFF;
  color textDim = #888888;
  color success = #00FF88;
  color warning = #FFAA00;
  color error = #FF4444;
  color disabled = #333333;
  color hover = #2A2A2A;
  color border = #444444;
  color cwColor = #00FF00;
  color ccwColor = #FF8800;
  color haltColor = #FF3030;
  color rotatorPowerOn = #00AAFF;
  color rotatorPowerOff = #555555;
}

ThemeColors theme = new ThemeColors();

// ═══════════════════════════════════════════════════════════════════════════
//  NOTIFICHE
// ═══════════════════════════════════════════════════════════════════════════

class NotificationManager {
  ArrayList<Notification> items = new ArrayList<Notification>();
  
  void add(String msg, int type) {
    items.add(new Notification(msg, type));
    while (items.size() > 3) items.remove(0);
  }
  
  void update() {
    for (int i = items.size() - 1; i >= 0; i--) {
      items.get(i).update();
      if (items.get(i).isDead()) items.remove(i);
    }
  }
  
  void draw() {
    for (int i = 0; i < items.size(); i++) {
      Notification n = items.get(i);
      n.targetY = 70 + i * 60;
      n.draw();
    }
  }
}

class Notification {
  String message;
  int type;
  long timestamp;
  float alpha = 255, y = -60, targetY = 70;
  boolean removing = false;
  
  Notification(String msg, int t) { message = msg; type = t; timestamp = millis(); }
  
  void update() {
    y = lerp(y, targetY, 0.15);
    if (millis() - timestamp > 4000) removing = true;
    if (removing) alpha -= 8;
  }
  
  boolean isDead() { return removing && alpha <= 0; }
  
  void draw() {
    if (alpha <= 0) return;
    color bgColor = type == SUCCESS ? theme.success : type == WARNING ? theme.warning : type == ERROR ? theme.error : theme.accent;
    fill(0, 0, 0, alpha * 0.4);
    noStroke();
    rect(width - 264, y + 3, 220, 50, 10);
    fill(red(bgColor), green(bgColor), blue(bgColor), alpha);
    rect(width - 260, y, 220, 48, 10);
    fill(255, 255, 255, alpha);
    textFont(fontRegular);
    textSize(11);
    textAlign(LEFT, CENTER);
    text(message, width - 245, y + 24);
    float progress = 1.0 - (float)(millis() - timestamp) / 4000.0;
    if (progress > 0 && ! removing) {
      fill(255, 255, 255, alpha * 0.5);
      rect(width - 260, y + 42, 220 * progress, 3, 0, 0, 10, 10);
    }
  }
}

final int INFO = 0, SUCCESS = 1, WARNING = 2, ERROR = 3;
NotificationManager notificationManager = new NotificationManager();

void addNotification(String msg, int type) { notificationManager.add(msg, type); }

// ═══════════════════════════════════════════════════════════════════════════
//  SETTINGS MANAGER
// ═══════════════════════════════════════════════════════════════════════════

class SettingsManager {
  JSONObject config;
  String settingsFile = "config.json";
  
  SettingsManager() { loadSettings(); }
  
  void loadSettings() {
    try {
      File f = new File(sketchPath() + "/" + settingsFile);
      if (f.exists()) {
        config = loadJSONObject(settingsFile);
        applySettings();
      } else {
        createDefaultSettings();
      }
    } catch (Exception e) {
      createDefaultSettings();
    }
  }
  
  void createDefaultSettings() {
    config = new JSONObject();
    JSONArray antennasArray = new JSONArray();
    for (int i = 0; i < 6; i++) {
      JSONObject antenna = new JSONObject();
      antenna.setString("name", defaultAntennaNames[i]);
      antenna.setInt("pin", i + 4);
      antenna.setBoolean("directive", defaultAntennaDirective[i]);
      antennasArray.setJSONObject(i, antenna);
    }
    config.setJSONArray("antennas", antennasArray);
    
    config.setInt("antConnMode", 0);
    config.setString("antComPort", "COM4");
    config.setInt("antBaudRate", 9600);
    config.setString("antWifiIP", "192.168.1.100");
    config.setInt("antWifiPort", 8080);
    
    config.setInt("rotConnMode", 0);
    config.setString("rotComPort", "COM5");
    config.setInt("rotBaudRate", 9600);
    config.setString("rotWifiIP", "192.168.1.101");
    config.setInt("rotWifiPort", 8081);
    
    config.setBoolean("autoConnect", false);
    config.setBoolean("debugMode", true);
    config.setBoolean("showBrakeControls", true);
    config.setBoolean("showMapImage", true);
    config.setFloat("mapImageAlpha", 0.4);
    config.setString("mapImagePath", "");
    
    // Nuovi parametri
    config.setBoolean("disconnectRelaysOnExit", true);
    config.setBoolean("sendHaltOnExit", true);
    config.setBoolean("confirmOnExit", true);
    config.setBoolean("rememberLastAntenna", true);
    config.setBoolean("autoReconnect", true);
    config.setInt("lastSelectedAntenna", -1);
    config.setInt("currentThemeIdx", 0);
    config.setBoolean("showAnimations", true);
    config.setBoolean("showStatusBarFlag", true);
    config.setBoolean("showDegreeLabels", true);
    config.setBoolean("showCardinals", true);
    config.setBoolean("showBeamPattern", true);
    config.setFloat("beamPatternOpacity", 0.25);
    config.setFloat("beamPatternBeamWidth", 50.0);
    config.setFloat("mapZoom", 1.0);
    config.setFloat("mapOffsetX", 0.0);
    config.setFloat("mapOffsetY", 0.0);
    saveSettings();
  }
  
  void applySettings() {
    try {
      JSONArray antennasArray = config.getJSONArray("antennas");
      for (int i = 0; i < min(6, antennasArray.size()); i++) {
        JSONObject antenna = antennasArray.getJSONObject(i);
        antennaNames[i] = antenna.getString("name");
        antennaPins[i] = antenna.getInt("pin");
        antennaDirective[i] = antenna.getBoolean("directive");
      }
      
      antConnMode = config.getInt("antConnMode", 0);
      antComPort = config.getString("antComPort", "COM4");
      antBaudRate = config.getInt("antBaudRate", 9600);
      antWifiIP = config.getString("antWifiIP", "192.168.1.100");
      antWifiPort = config.getInt("antWifiPort", 8080);
      
      rotConnMode = config.getInt("rotConnMode", 0);
      rotComPort = config.getString("rotComPort", "COM5");
      rotBaudRate = config.getInt("rotBaudRate", 9600);
      rotWifiIP = config.getString("rotWifiIP", "192.168.1.101");
      rotWifiPort = config.getInt("rotWifiPort", 8081);
      
      autoConnect = config.getBoolean("autoConnect");
      debugMode = config.getBoolean("debugMode");
      showBrakeControls = config.getBoolean("showBrakeControls", true);
      showMapImage = config.getBoolean("showMapImage", true);
      mapImageAlpha = config.getFloat("mapImageAlpha", 0.4);
      mapImagePath = config.getString("mapImagePath", "");
      
      // Nuovi parametri
      disconnectRelaysOnExit = config.getBoolean("disconnectRelaysOnExit", true);
      sendHaltOnExit = config.getBoolean("sendHaltOnExit", true);
      confirmOnExit = config.getBoolean("confirmOnExit", true);
      rememberLastAntenna = config.getBoolean("rememberLastAntenna", true);
      autoReconnect = config.getBoolean("autoReconnect", true);
      lastSelectedAntenna = config.getInt("lastSelectedAntenna", -1);
      currentThemeIdx = config.getInt("currentThemeIdx", 0);
      showAnimations = config.getBoolean("showAnimations", true);
      showStatusBarFlag = config.getBoolean("showStatusBarFlag", true);
      showDegreeLabels = config.getBoolean("showDegreeLabels", true);
      showCardinals = config.getBoolean("showCardinals", true);
      showBeamPattern = config.getBoolean("showBeamPattern", true);
      beamPatternOpacity = config.getFloat("beamPatternOpacity", 0.25);
      beamPatternBeamWidth = config.getFloat("beamPatternBeamWidth", 50.0);
      mapZoom = config.getFloat("mapZoom", 1.0);
      mapOffsetX = config.getFloat("mapOffsetX", 0.0);
      mapOffsetY = config.getFloat("mapOffsetY", 0.0);
      
      if (currentThemeIdx != 0) applyTheme(currentThemeIdx);
    } catch (Exception e) { }
  }
  
  void saveSettings() {
    try {
      JSONArray antennasArray = new JSONArray();
      for (int i = 0; i < 6; i++) {
        JSONObject antenna = new JSONObject();
        antenna.setString("name", antennaNames[i]);
        antenna.setInt("pin", antennaPins[i]);
        antenna.setBoolean("directive", antennaDirective[i]);
        antennasArray.setJSONObject(i, antenna);
      }
      config.setJSONArray("antennas", antennasArray);
      
      config.setInt("antConnMode", antConnMode);
      config.setString("antComPort", antComPort);
      config.setInt("antBaudRate", antBaudRate);
      config.setString("antWifiIP", antWifiIP);
      config.setInt("antWifiPort", antWifiPort);
      
      config.setInt("rotConnMode", rotConnMode);
      config.setString("rotComPort", rotComPort);
      config.setInt("rotBaudRate", rotBaudRate);
      config.setString("rotWifiIP", rotWifiIP);
      config.setInt("rotWifiPort", rotWifiPort);
      
      config.setBoolean("autoConnect", autoConnect);
      config.setBoolean("debugMode", debugMode);
      config.setBoolean("showBrakeControls", showBrakeControls);
      config.setBoolean("showMapImage", showMapImage);
      config.setFloat("mapImageAlpha", mapImageAlpha);
      config.setString("mapImagePath", mapImagePath);
      
      // Nuovi parametri
      config.setBoolean("disconnectRelaysOnExit", disconnectRelaysOnExit);
      config.setBoolean("sendHaltOnExit", sendHaltOnExit);
      config.setBoolean("confirmOnExit", confirmOnExit);
      config.setBoolean("rememberLastAntenna", rememberLastAntenna);
      config.setBoolean("autoReconnect", autoReconnect);
      config.setInt("lastSelectedAntenna", lastSelectedAntenna);
      config.setInt("currentThemeIdx", currentThemeIdx);
      config.setBoolean("showAnimations", showAnimations);
      config.setBoolean("showStatusBarFlag", showStatusBarFlag);
      config.setBoolean("showDegreeLabels", showDegreeLabels);
      config.setBoolean("showCardinals", showCardinals);
      config.setBoolean("showBeamPattern", showBeamPattern);
      config.setFloat("beamPatternOpacity", beamPatternOpacity);
      config.setFloat("beamPatternBeamWidth", beamPatternBeamWidth);
      config.setFloat("mapZoom", mapZoom);
      config.setFloat("mapOffsetX", mapOffsetX);
      config.setFloat("mapOffsetY", mapOffsetY);
      
      saveJSONObject(config, settingsFile);
    } catch (Exception e) { }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  VARIABILI GLOBALI
// ═══════════════════════════════════════════════════════════════════════════

// ESP32 Antenna Switch
int antConnMode = 0; // 0=USB, 1=WiFi
Serial antSerial;
Client antClient;
boolean antConnected = false;
String antComPort = "COM4";
int antBaudRate = 9600;
String antWifiIP = "192.168.1.100";
int antWifiPort = 8080;

// ESP32 Rotatore
int rotConnMode = 0; // 0=USB, 1=WiFi
Serial rotSerial;
Client rotClient;
boolean rotConnected = false;
String rotComPort = "COM5";
int rotBaudRate = 9600;
String rotWifiIP = "192.168.1.101";
int rotWifiPort = 8081;

boolean autoConnect = false;
boolean debugMode = true;

SettingsManager settings;

String[] defaultAntennaNames = {"DxCommander", "3El 10-15-20", "Delta Loop 11m", "9el V/UHF", "Dipolo 80", "Dipolo 40"};
boolean[] defaultAntennaDirective = {true, false, false, true, false, false};

String[] antennaNames = new String[6];
int[] antennaPins = new int[6];
boolean[] antennaStates = new boolean[6];
boolean[] antennaDirective = new boolean[6];
int selectedAntenna = -1;

boolean systemOn = true;
boolean rotatorPowerOn = false;  // NUOVO: Stato ON/OFF rotatore
int currentScreen = 0;
float screenTransition = 0;
boolean transitioning = false;
int targetScreen = 0;

boolean rotatorCW = false;
boolean rotatorCCW = false;
boolean cwButtonPressed = false;
boolean ccwButtonPressed = false;
boolean brakeReleased = false;  // Brake release state
boolean brakeButtonPressed = false;
int brakeDelayMs = 500;
int brakeDelayMin = 100;
int brakeDelayMax = 3000;
boolean brakeSliderDragging = false;
float smoothingFactor = 0.15;       // EMA coefficient - used internally, not shown in UI
float relayCompensation = 17.0;     // Relay compensation - used internally, not shown in UI
long lastHttpPoll = 0;
int httpPollFailCount = 0;
float targetAzimuth = -1;  // -1 = nessun target
boolean goToActive = false;
float goToTarget = -1;
float currentAzimuth = 0;
float displayAzimuth = 0;
boolean overlapActive = false;
float rawAzimuth = 0;
float mapCenterX, mapCenterY;
float mapRadius = 110;

boolean[] buttonHover = new boolean[30];
float[] buttonAnim = new float[30];
float powerSwitchAnim = 1.0; // Animation value for power switch (0.0 to 1.0)

PFont fontRegular, fontBold, fontLarge, fontMono;

ArrayList<String> debugLog = new ArrayList<String>();
ArrayList<String> commandQueue = new ArrayList<String>();

// ─── Mappa immagine quadrante bussola ───────────────────────────────────────
PImage maskedMapImage = null;
boolean showMapImage = true;
float mapImageAlpha = 0.4;
String mapImagePath = "";
boolean mapAlphaSliderDragging = false;

// ─── Toggle visibilità controllo freno ──────────────────────────────────────
boolean showBrakeControls = true;

// ─── Pattern antenna avanzato ─────────────────────────────────────────────
float beamPatternOpacity = 0.25;
float beamPatternBeamWidth = 50.0;
boolean beamOpacitySliderDragging = false;
boolean beamWidthSliderDragging = false;

// ─── Mappa zoom e offset ──────────────────────────────────────────────────
float mapZoom = 1.0;
float mapOffsetX = 0;
float mapOffsetY = 0;
boolean mapZoomSliderDragging = false;
boolean mapOffsetXSliderDragging = false;
boolean mapOffsetYSliderDragging = false;
PImage sourceMapImage = null;

// ─── Statistiche comunicazione HTTP ─────────────────────────────────────────
int httpCommandCount = 0;
int httpErrorCount = 0;

// ─── Tempo rotazione ────────────────────────────────────────────────────────
long rotationStartTime = 0;

String[] tempAntennaNames = new String[6];
int[] tempAntennaPins = new int[6];
boolean[] tempAntennaDirective = new boolean[6];
int editingField = -1;
String inputBuffer = "";
int currentSettingsTab = 0;

// ─── Impostazioni chiusura / avvio ────────────────────────────────────────
boolean disconnectRelaysOnExit = true;
boolean sendHaltOnExit = true;
boolean confirmOnExit = true;
boolean rememberLastAntenna = true;
boolean autoReconnect = true;
int lastSelectedAntenna = -1;

// ─── Tema e aspetto ───────────────────────────────────────────────────────
int currentThemeIdx = 0;
boolean showAnimations = true;
boolean showStatusBarFlag = true;

// ─── Visualizzazione quadrante ────────────────────────────────────────────
boolean showDegreeLabels = true;
boolean showCardinals = true;
boolean showBeamPattern = true;

String[] availablePorts;

// ═══════════════════════════════════════════════════════════════════════════
//  SETUP
// ═══════════════════════════════════════════════════════════════════════════

void setup() {
  size(800, 600);
  smooth(8);
  frameRate(60);
  surface.setTitle(APP_NAME + " v" + APP_VERSION);
  
  fontRegular = createFont("Segoe UI", 12);
  fontBold = createFont("Segoe UI Bold", 12);
  fontLarge = createFont("Segoe UI Bold", 20);
  fontMono = createFont("Consolas", 10);
  
  for (int i = 0; i < 6; i++) {
    antennaNames[i] = defaultAntennaNames[i];
    antennaPins[i] = i + 4;
    antennaStates[i] = false;
    antennaDirective[i] = defaultAntennaDirective[i];
  }
  
  arrayCopy(antennaNames, tempAntennaNames);
  arrayCopy(antennaPins, tempAntennaPins);
  arrayCopy(antennaDirective, tempAntennaDirective);
  
  settings = new SettingsManager();
  if (mapImagePath.length() > 0) loadMapImage(mapImagePath);
  scanSerialPorts();
  
  addDebugLog("═══════════════════════════════════════");
  addDebugLog("  " + APP_NAME + " v" + APP_VERSION);
  addDebugLog("═══════════════════════════════════════");
  addDebugLog("Sistema inizializzato");
  
  if (autoConnect && availablePorts != null && availablePorts.length > 0) {
    addDebugLog("Auto-connect attivo...");
    connectAntESP32();
    connectRotESP32();
  }
}

void scanSerialPorts() {
  availablePorts = Serial.list();
  addDebugLog("Porte trovate: " + availablePorts.length);
}

String getTimestamp() {
  return new SimpleDateFormat("HH:mm:ss").format(new Date());
}

// ═══════════════════════════════════════════════════════════════════════════
//  EASING FUNCTIONS (for smoother animations)
// ═══════════════════════════════════════════════════════════════════════════

float easeOutCubic(float t) {
  return 1 - pow(1 - t, 3);
}

float easeInOutCubic(float t) {
  return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2;
}

float easeOutElastic(float t) {
  float c4 = (2 * PI) / 3;
  return t == 0 ? 0 : t == 1 ? 1 : pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1;
}

void addDebugLog(String msg) {
  String entry = "[" + getTimestamp() + "] " + msg;
  debugLog.add(entry);
  while (debugLog.size() > 100) debugLog.remove(0);
  println(entry);
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN DRAW LOOP
// ═══════════════════════════════════════════════════════════════════════════

void draw() {
  drawBackground();
  updateAnimations();
  
  // Read WiFi data if connected
  if (antConnMode == 1 && antClient != null && antClient.available() > 0) {
    String data = antClient.readStringUntil('\n');
    if (data != null) processAntennaData(data.trim());
  }
  
  if (rotConnMode == 1 && rotConnected) {
    // HTTP polling for WiFi mode
    if (millis() - lastHttpPoll > 500) {
      lastHttpPoll = millis();
      thread("pollRotatorStatusThread");
    }
  }
  
  if (transitioning) {
    screenTransition += 0.1;
    if (screenTransition >= 1.0) {
      screenTransition = 0;
      transitioning = false;
      currentScreen = targetScreen;
    }
  }
  
  pushMatrix();
  if (transitioning) translate(-width * screenTransition, 0);
  drawCurrentScreen();
  popMatrix();
  
  if (transitioning) {
    pushMatrix();
    translate(width * (1 - screenTransition), 0);
    drawTargetScreen();
    popMatrix();
  }
  
  drawTopBar();
  drawNavigationBar();
  
  notificationManager.update();
  notificationManager.draw();
}

void drawBackground() {
  for (int i = 0; i < height; i++) {
    float inter = map(i, 0, height, 0, 1);
    stroke(lerpColor(theme.background, color(5, 5, 10), inter));
    line(0, i, width, i);
  }
}

void updateAnimations() {
  for (int i = 0; i < buttonAnim.length; i++) {
    if (showAnimations) {
      // Smoother animation with faster response
      float speed = buttonHover[i] ? 0.25 : 0.18;
      buttonAnim[i] = lerp(buttonAnim[i], buttonHover[i] ? 1.0 : 0.0, speed);
    } else {
      buttonAnim[i] = buttonHover[i] ? 1.0 : 0.0;
    }
  }
  // Smoother azimuth animation
  displayAzimuth = lerp(displayAzimuth, currentAzimuth, 0.18);
  
  // Smooth power switch animation
  powerSwitchAnim = lerp(powerSwitchAnim, systemOn ? 1.0 : 0.0, 0.22);
}

void drawCurrentScreen() {
  switch(currentScreen) {
    case 0: drawControlScreen(); break;
    case 1: drawSettingsScreen(); break;
    case 2: drawDebugScreen(); break;
  }
}

void drawTargetScreen() {
  switch(targetScreen) {
    case 0: drawControlScreen(); break;
    case 1: drawSettingsScreen(); break;
    case 2: drawDebugScreen(); break;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCHERMATA CONTROLLO
// ═══════════════════════════════════════════════════════════════════════════

void drawControlScreen() {
  drawAntennaPanel();
  drawRotatorPanel();
  if (showStatusBarFlag) drawStatusBar();
}

void drawAntennaPanel() {
  float px = 20, py = 55, pw = 290, ph = 420;
  drawPanel(px, py, pw, ph, "ANTENNA SELECTOR", true);
  
  if (selectedAntenna < 0) {
    fill(theme.textDim);
    textFont(fontRegular);
    textSize(10);
    textAlign(LEFT, TOP);
    text("Nessuna antenna attiva", px + 20, py + 45);
  } else {
    fill(theme.accent);
    textFont(fontRegular);
    textSize(10);
    textAlign(LEFT, TOP);
    text("Attiva: " + antennaNames[selectedAntenna], px + 20, py + 45);
  }
  
  float startX = px + 15, startY = py + 70;
  float btnW = 125, btnH = 52, gapX = 10, gapY = 8;
  
  for (int i = 0; i < 6; i++) {
    int col = i % 2, row = i / 2;
    float bx = startX + col * (btnW + gapX);
    float by = startY + row * (btnH + gapY);
    drawAntennaButton(i, bx, by, btnW, btnH);
  }
}

void drawAntennaButton(int idx, float x, float y, float w, float h) {
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h && systemOn;
  buttonHover[idx] = hover;
  boolean selected = (selectedAntenna == idx);
  boolean active = antennaStates[idx];
  
  float animValue = easeOutCubic(buttonAnim[idx]);
  
  pushMatrix();
  if (hover) translate(0, -3 * animValue);
  
  // Enhanced shadow with animation
  fill(0, 0, 0, 40 + 60 * animValue);
  noStroke();
  rect(x + 2, y + 4, w, h, 10);
  
  // Main button background
  color bgColor = !systemOn ? theme.disabled : selected ? theme.accent : hover ? theme.hover : theme.secondary;
  fill(bgColor);
  stroke(selected ? theme.accent : theme.border);
  strokeWeight(selected ? 2 : 1);
  rect(x, y, w, h, 10);
  
  // Glow effect when selected or hovered
  if (selected || hover) {
    noFill();
    stroke(selected ? theme.accent : theme.hover, 80 * animValue);
    strokeWeight(2);
    rect(x - 1, y - 1, w + 2, h + 2, 11);
  }
  
  // Antenna active LED with enhanced glow
  float ledX = x + w - 14, ledY = y + 12;
  if (active) {
    // Outer glow
    fill(theme.success, 60);
    noStroke();
    ellipse(ledX, ledY, 16, 16);
    fill(theme.success, 100);
    ellipse(ledX, ledY, 12, 12);
    // Pulsing border for active antenna
    float pulse = 0.5 + 0.5 * sin(millis() * 0.006);
    noFill();
    stroke(theme.success, 120 + 120 * pulse);
    strokeWeight(2.5);
    rect(x - 1, y - 1, w + 2, h + 2, 11);
  }
  fill(active ? theme.success : theme.disabled);
  ellipse(ledX, ledY, 8, 8);
  
  // Directive indicator
  if (antennaDirective[idx]) {
    fill(theme.warning);
    ellipse(x + 12, y + 12, 8, 8);
    fill(0);
    textFont(fontBold);
    textSize(6);
    textAlign(CENTER, CENTER);
    text("D", x + 12, y + 12);
  }
  
  // Antenna name
  fill(selected ? theme.primary : theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  String name = antennaNames[idx];
  if (name.length() > 14) name = name.substring(0, 12) + "...";
  text(name, x + w/2, y + h/2 - 6);
  
  // PIN label
  fill(selected ? color(0, 0, 0, 150) : theme.textDim);
  textFont(fontRegular);
  textSize(8);
  text("PIN " + antennaPins[idx], x + w/2, y + h/2 + 10);
  
  popMatrix();
}

void drawRotatorPanel() {
  float px = 330, py = 55, pw = 450, ph = 420;
  drawPanel(px, py, pw, ph, "ROTATOR CONTROL", true);
  
  mapCenterX = px + pw/2;
  mapCenterY = py + 185;
  
  // Pulsante ON/OFF rotatore
  drawRotatorPowerSwitch(px + 20, py + 45);
  
  // Display azimuth digitale grande (a destra del power switch)
  drawLargeAzimuthDisplay(px + 295, py + 42, pw - 325);
  
  drawAzimuthMap();
  drawRotatorButtons();
}

// NUOVO: Switch ON/OFF rotatore
void drawRotatorPowerSwitch(float x, float y) {
  float w = 120, h = 30;
  
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h && systemOn;
  buttonHover[27] = hover;
  
  // Background
  fill(rotatorPowerOn ? theme.rotatorPowerOn : theme.rotatorPowerOff);
  stroke(rotatorPowerOn ? theme.rotatorPowerOn : theme.border);
  strokeWeight(hover ? 2 : 1);
  rect(x, y, w, h, 8);
  
  // LED indicatore
  float ledX = x + 15;
  fill(rotatorPowerOn ? theme.success : theme.error);
  noStroke();
  ellipse(ledX, y + h/2, 10, 10);
  if (rotatorPowerOn) {
    fill(theme.success, 100);
    ellipse(ledX, y + h/2, 16, 16);
  }
  
  // Testo
  fill(theme.text);
  textFont(fontBold);
  textSize(11);
  textAlign(LEFT, CENTER);
  text("ROTATOR: " + (rotatorPowerOn ? "ON" : "OFF"), x + 28, y + h/2);
  
  // Etichetta
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(9);
  textAlign(LEFT, CENTER);
  text("Power (A3)", x + w + 10, y + h/2);
}

void drawLargeAzimuthDisplay(float x, float y, float w) {
  float h = 36;
  
  fill(theme.primary);
  stroke(rotatorPowerOn ? theme.rotatorPowerOn : theme.border);
  strokeWeight(rotatorPowerOn ? 2 : 1);
  rect(x, y, w, h, 6);
  
  // Azimuth valore grande
  color aziColor = !rotatorPowerOn ? theme.disabled
                 : overlapActive ? color(255, 140, 0) : theme.accent;
  fill(aziColor);
  textFont(fontLarge);
  textSize(20);
  textAlign(CENTER, CENTER);
  String aziStr = nf(displayAzimuth, 1, 1) + "°";
  if (overlapActive) aziStr += " (" + int(displayAzimuth % 360) + "°)";
  text(aziStr, x + w/2, y + h/2 - 4);
  
  // Stato sotto il numero
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(8);
  if (rotatorCW || rotatorCCW) {
    long elapsed = (millis() - rotationStartTime) / 1000;
    fill(rotatorCW ? theme.cwColor : theme.ccwColor);
    text((rotatorCW ? "\u2192 CW" : "\u2190 CCW") + "  " + elapsed + "s", x + w/2, y + h - 5);
  } else if (goToActive) {
    fill(theme.warning);
    text("\u2192 GOTO " + nf(goToTarget, 1, 0) + "\u00b0", x + w/2, y + h - 5);
  } else if (overlapActive) {
    fill(color(255, 140, 0));
    text("OVERLAP", x + w/2, y + h - 5);
  } else if (!rotatorPowerOn) {
    fill(theme.disabled);
    text("OFF", x + w/2, y + h - 5);
  }
}

void drawAzimuthMap() {
  pushMatrix();
  translate(mapCenterX, mapCenterY);
  
  // ─── Mappa immagine con maschera circolare ──────────────────────────────
  if (showMapImage && maskedMapImage != null) {
    tint(255, mapImageAlpha * 255);
    imageMode(CENTER);
    image(maskedMapImage, 0, 0);
    noTint();
  }
  noFill();
  for (int i = 3; i >= 1; i--) {
    stroke(theme.border, 40 + i * 20);
    strokeWeight(1);
    ellipse(0, 0, mapRadius * 2 * i / 3, mapRadius * 2 * i / 3);
  }
  
  stroke(overlapActive ? color(255, 100, 0, 180) : theme.accent, 180);
  strokeWeight(2);
  ellipse(0, 0, mapRadius * 2, mapRadius * 2);
  
  // Zona OVERLAP (0°-90° = equivalente a 360°-450°)
  if (overlapActive) {
    float overlapStart = radians(0 - 90);   // da Nord (0°)
    float overlapEnd   = radians(90 - 90);  // a Est (90° = 450°)
    fill(255, 100, 0, 30);
    stroke(255, 100, 0, 120);
    strokeWeight(1);
    beginShape();
    vertex(0, 0);
    for (float a = overlapStart; a <= overlapEnd; a += 0.02) {
      vertex(cos(a) * mapRadius, sin(a) * mapRadius);
    }
    endShape(CLOSE);
    
    // Bordo overlap
    noFill();
    stroke(255, 100, 0, 180);
    strokeWeight(2);
    arc(0, 0, mapRadius * 2, mapRadius * 2, overlapStart, overlapEnd);
    
    // Etichetta OVERLAP
    float midAngle = (overlapStart + overlapEnd) / 2;
    fill(255, 140, 0, 200);
    textFont(fontRegular);
    textSize(9);
    textAlign(CENTER, CENTER);
    text("OVERLAP", cos(midAngle) * (mapRadius * 0.55), sin(midAngle) * (mapRadius * 0.55));
  }
  
  // Tacche minori ogni 10°
  for (int deg = 0; deg < 360; deg += 10) {
    if (deg % 30 == 0) continue;
    float angle = radians(deg - 90);
    stroke(theme.border, 70);
    strokeWeight(0.8);
    float innerR = mapRadius - 5;
    line(cos(angle) * innerR, sin(angle) * innerR, cos(angle) * mapRadius, sin(angle) * mapRadius);
  }
  
  // Tacche maggiori ogni 30°
  for (int deg = 0; deg < 360; deg += 30) {
    float angle = radians(deg - 90);
    float innerR = (deg % 90 == 0) ? mapRadius - 15 : mapRadius - 10;
    stroke(deg % 90 == 0 ? theme.text : theme.textDim, deg % 90 == 0 ? 200 : 100);
    strokeWeight(deg % 90 == 0 ? 2 : 1);
    line(cos(angle) * innerR, sin(angle) * innerR, cos(angle) * mapRadius, sin(angle) * mapRadius);
    
    if (showDegreeLabels) {
      fill(theme.textDim);
      textFont(fontRegular);
      textSize(deg % 90 == 0 ? 10 : 9);
      textAlign(CENTER, CENTER);
      text(deg + "\u00b0", cos(angle) * (mapRadius + 18), sin(angle) * (mapRadius + 18));
    }
  }
  
  if (showCardinals) {
    String[] cardinals = {"N", "E", "S", "W"};
    for (int i = 0; i < 4; i++) {
      float angle = radians(i * 90 - 90);
      fill(theme.text);
      textFont(fontBold);
      textSize(14);
      textAlign(CENTER, CENTER);
      text(cardinals[i], cos(angle) * (mapRadius + 35), sin(angle) * (mapRadius + 35));
    }
  }
  
  if (selectedAntenna >= 0 && antennaDirective[selectedAntenna] && showBeamPattern) {
    float patternAngle = radians(displayAzimuth - 90);
    float beamWidth = radians(beamPatternBeamWidth);
    int bpAlpha = int(beamPatternOpacity * 255);
    fill(theme.accent, max(5, bpAlpha / 4));
    stroke(theme.accent, bpAlpha);
    strokeWeight(1);
    beginShape();
    vertex(0, 0);
    for (float a = patternAngle - beamWidth/2; a <= patternAngle + beamWidth/2; a += 0.05) {
      vertex(cos(a) * mapRadius, sin(a) * mapRadius);
    }
    endShape(CLOSE);
  }
  
  // Draw target azimuth if Go To is active
  if (targetAzimuth >= 0) {
    float targetAngle = radians(targetAzimuth - 90);
    
    // Draw dashed target line
    stroke(theme.warning, 180);
    strokeWeight(2);
    float dashLen = 8, gapLen = 6;
    for (float r = 25; r < mapRadius; r += dashLen + gapLen) {
      float r1 = r;
      float r2 = min(r + dashLen, mapRadius);
      line(cos(targetAngle) * r1, sin(targetAngle) * r1, cos(targetAngle) * r2, sin(targetAngle) * r2);
    }
    
    // Draw target marker (triangle)
    pushMatrix();
    translate(cos(targetAngle) * (mapRadius - 8), sin(targetAngle) * (mapRadius - 8));
    rotate(targetAngle + HALF_PI);
    fill(theme.warning, 200);
    noStroke();
    triangle(-6, -8, 6, -8, 0, 0);
    popMatrix();
  }
  
  float needleAngle = radians(displayAzimuth - 90);
  color needleColor = overlapActive ? color(255, 100, 0) : theme.accent;
  
  // Glow pronunciato quando in rotazione
  if (rotatorCW || rotatorCCW) {
    float glowPulse = 0.5 + 0.5 * sin(millis() * 0.008);
    stroke(red(needleColor), green(needleColor), blue(needleColor), 40 + 60 * glowPulse);
    strokeWeight(14);
    line(0, 0, cos(needleAngle) * (mapRadius - 15), sin(needleAngle) * (mapRadius - 15));
    stroke(red(needleColor), green(needleColor), blue(needleColor), 80 + 80 * glowPulse);
    strokeWeight(8);
    line(0, 0, cos(needleAngle) * (mapRadius - 15), sin(needleAngle) * (mapRadius - 15));
  }
  
  stroke(0, 0, 0, 80);
  strokeWeight(4);
  line(2, 2, cos(needleAngle) * (mapRadius - 15) + 2, sin(needleAngle) * (mapRadius - 15) + 2);
  
  stroke(needleColor);
  strokeWeight(3);
  line(0, 0, cos(needleAngle) * (mapRadius - 15), sin(needleAngle) * (mapRadius - 15));
  
  pushMatrix();
  translate(cos(needleAngle) * (mapRadius - 15), sin(needleAngle) * (mapRadius - 15));
  rotate(needleAngle + HALF_PI);
  fill(needleColor);
  noStroke();
  triangle(-5, -10, 5, -10, 0, 0);
  popMatrix();
  
  if (rotatorCW || rotatorCCW) {
    stroke(rotatorCW ? theme.cwColor : theme.ccwColor, 120 + 80 * sin(millis() * 0.01));
    strokeWeight(2);
    noFill();
    ellipse(0, 0, 50, 50);
  }
  
  // Small center pivot dot (no opaque overlay - keeps map visible)
  fill(theme.secondary);
  stroke(rotatorPowerOn ? theme.rotatorPowerOn : theme.border);
  strokeWeight(1);
  ellipse(0, 0, 10, 10);
  
  popMatrix();
}

void drawRotatorButtons() {
  float centerX = mapCenterX;
  float btnY = mapCenterY + 170;
  float btnH = 38, gap = 8;
  
  boolean rotatorEnabled = systemOn && rotatorPowerOn;
  
  if (showBrakeControls) {
    // Layout 4 pulsanti: CCW | HALT | FRENO | CW
    float btnW = 60;
    float totalWidth = btnW * 4 + gap * 3;
    float startX = centerX - totalWidth / 2;
    
    drawMomentaryButton("CCW", startX, btnY, btnW, btnH, 20, ccwButtonPressed, theme.ccwColor, rotatorEnabled);
    drawHaltButton("HALT", startX + btnW + gap, btnY, btnW, btnH, 23, rotatorEnabled);
    drawBrakeButton("FRENO", startX + (btnW + gap) * 2, btnY, btnW, btnH, 21, rotatorEnabled);
    drawMomentaryButton("CW", startX + (btnW + gap) * 3, btnY, btnW, btnH, 22, cwButtonPressed, theme.cwColor, rotatorEnabled);
    
    drawBrakeDelaySlider(centerX, btnY + btnH + 55);
    
  } else {
    // Layout 3 pulsanti senza freno
    float totalWidth = 60.0 * 4 + gap * 3;
    float btnW = (totalWidth - gap * 2) / 3;
    float startX = centerX - totalWidth / 2;
    
    drawMomentaryButton("CCW", startX, btnY, btnW, btnH, 20, ccwButtonPressed, theme.ccwColor, rotatorEnabled);
    drawHaltButton("HALT", startX + btnW + gap, btnY, btnW, btnH, 23, rotatorEnabled);
    drawMomentaryButton("CW", startX + (btnW + gap) * 2, btnY, btnW, btnH, 22, cwButtonPressed, theme.cwColor, rotatorEnabled);
  }
}

void drawMomentaryButton(String label, float x, float y, float w, float h, int idx, boolean pressed, color activeColor, boolean enabled) {
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h && enabled;
  buttonHover[idx] = hover;
  
  float animValue = easeOutCubic(buttonAnim[idx]);
  
  pushMatrix();
  if (hover || pressed) translate(0, -3 * animValue);
  
  // Enhanced shadow
  fill(0, 0, 0, 60 + 60 * animValue);
  noStroke();
  rect(x + 2, y + 3, w, h, 8);
  
  // Main button
  color bgColor = !enabled ? theme.disabled : pressed ? activeColor : theme.secondary;
  fill(bgColor);
  stroke(pressed ? activeColor : theme.border);
  strokeWeight(pressed ? 2 : 1);
  rect(x, y, w, h, 8);
  
  // Glow effect when pressed
  if (pressed && enabled) {
    noFill();
    stroke(activeColor, 120);
    strokeWeight(3);
    rect(x - 2, y - 2, w + 4, h + 4, 10);
    stroke(activeColor, 60);
    strokeWeight(5);
    rect(x - 4, y - 4, w + 8, h + 8, 12);
  }
  // Subtle hover glow
  else if (hover && enabled) {
    noFill();
    stroke(theme.accent, 60 * animValue);
    strokeWeight(2);
    rect(x - 1, y - 1, w + 2, h + 2, 9);
  }
  
  fill(enabled ? (pressed ? theme.primary : theme.text) : theme.textDim);
  textFont(fontBold);
  textSize(11);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
  
  popMatrix();
}

void drawBrakeButton(String label, float x, float y, float w, float h, int idx, boolean enabled) {
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h && enabled;
  buttonHover[idx] = hover;
  
  float animValue = easeOutCubic(buttonAnim[idx]);
  
  pushMatrix();
  if (hover) translate(0, -3 * animValue);
  
  // Shadow
  fill(0, 0, 0, 60 + 60 * animValue);
  noStroke();
  rect(x + 2, y + 3, w, h, 8);
  
  // Background: orange-red when released (danger), dark red when engaged
  color bgColor = !enabled ? theme.disabled
                : brakeReleased ? color(220, 70, 30) : color(120, 20, 20);
  fill(bgColor);
  noStroke();
  rect(x, y, w, h, 8);
  
  if (enabled) {
    // Diagonal danger stripes
    stroke(brakeReleased ? color(255, 140, 60) : color(180, 0, 0), brakeReleased ? 200 : 100);
    strokeWeight(2);
    for (float i = -h; i < w + h; i += 8) {
      line(x + i, y, x + i + h, y + h);
    }
  }
  
  // Border
  noFill();
  stroke(brakeReleased ? color(255, 100, 40) : color(180, 30, 30));
  strokeWeight(hover ? 2 : 1);
  rect(x, y, w, h, 8);
  
  // Glow when released (danger state)
  if (brakeReleased && enabled) {
    noFill();
    stroke(color(255, 80, 30), 140 + 80 * sin(millis() * 0.008));
    strokeWeight(3);
    rect(x - 2, y - 2, w + 4, h + 4, 10);
    stroke(color(255, 80, 30), 60 + 40 * sin(millis() * 0.008));
    strokeWeight(5);
    rect(x - 5, y - 5, w + 10, h + 10, 13);
  } else if (hover && enabled) {
    noFill();
    stroke(theme.haltColor, 100 * animValue);
    strokeWeight(2);
    rect(x - 1, y - 1, w + 2, h + 2, 9);
  }
  
  // LED stato: verde = rilasciato, rosso = inserito
  float ledX = x + w - 9;
  float ledY = y + 9;
  if (enabled) {
    fill(brakeReleased ? theme.success : theme.error, 80);
    noStroke();
    ellipse(ledX, ledY, 14, 14);
  }
  fill(enabled ? (brakeReleased ? theme.success : theme.error) : theme.disabled);
  noStroke();
  ellipse(ledX, ledY, 8, 8);
  
  // Label
  fill(enabled ? theme.text : theme.textDim);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2 - 5);
  
  // Sub-text: stato corrente ENGAGED / RELEASED
  textSize(8);
  fill(brakeReleased ? color(255, 140, 60) : color(200, 200, 200));
  text(brakeReleased ? "RELEASED" : "ENGAGED", x + w/2, y + h/2 + 7);
  
  popMatrix();
}

void drawHaltButton(String label, float x, float y, float w, float h, int idx, boolean enabled) {
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h && enabled;
  buttonHover[idx] = hover;
  
  float animValue = easeOutCubic(buttonAnim[idx]);
  
  pushMatrix();
  if (hover) translate(0, -3 * animValue);
  
  // Enhanced shadow
  fill(0, 0, 0, 60 + 60 * animValue);
  noStroke();
  rect(x + 2, y + 3, w, h, 8);
  
  // Background
  color bgColor = !enabled ? theme.disabled : theme.haltColor;
  fill(bgColor);
  noStroke();
  rect(x, y, w, h, 8);
  
  // Border
  noFill();
  stroke(theme.haltColor);
  strokeWeight(hover ? 2 : 1);
  rect(x, y, w, h, 8);
  
  // Glow effect on hover
  if (hover && enabled) {
    noFill();
    stroke(theme.haltColor, 100 * animValue);
    strokeWeight(2);
    rect(x - 1, y - 1, w + 2, h + 2, 9);
    stroke(theme.haltColor, 50 * animValue);
    strokeWeight(4);
    rect(x - 3, y - 3, w + 6, h + 6, 11);
  }
  
  fill(enabled ? theme.text : theme.textDim);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
  
  popMatrix();
}

void drawBrakeDelaySlider(float x, float y) {
  float sliderW = 200;
  float sliderH = 4;
  float knobSize = 14;
  float sliderX = x - sliderW / 2;
  
  // Label
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(9);
  textAlign(CENTER, TOP);
  text("Brake Delay", x, y - 18);
  
  // Slider track
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(sliderX, y, sliderW, sliderH, 2);
  
  // Tick marks
  stroke(theme.border);
  int[] tickValues = {100, 500, 1000, 1500, 2000, 2500, 3000};
  for (int i = 0; i < tickValues.length; i++) {
    float tickX = map(tickValues[i], brakeDelayMin, brakeDelayMax, sliderX, sliderX + sliderW);
    line(tickX, y + sliderH + 2, tickX, y + sliderH + 6);
  }
  
  // Knob position
  float knobX = map(brakeDelayMs, brakeDelayMin, brakeDelayMax, sliderX, sliderX + sliderW);
  boolean hoverKnob = dist(mouseX, mouseY, knobX, y + sliderH/2) < knobSize;
  
  // Knob
  if (hoverKnob || brakeSliderDragging) {
    fill(theme.accent, 60);
    noStroke();
    ellipse(knobX, y + sliderH/2, knobSize + 8, knobSize + 8);
  }
  
  fill(brakeSliderDragging ? theme.accent : theme.text);
  stroke(theme.accent);
  strokeWeight(2);
  ellipse(knobX, y + sliderH/2, knobSize, knobSize);
  
  // Value display
  fill(theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, TOP);
  text(brakeDelayMs + " ms", x, y + 15);
  
  // Brake state text
  fill(brakeReleased ? theme.success : theme.warning);
  textSize(8);
  text(brakeReleased ? "BRAKE FREE" : "BRAKE ON", x, y + 28);
}

void drawStatusBar() {
  float px = 20, py = 485, pw = 760, ph = 45;
  
  fill(theme.panel);
  stroke(theme.border);
  strokeWeight(1);
  rect(px, py, pw, ph, 8);
  
  float iconY = py + ph/2;
  float startX = px + 15;
  float spacing = 100;
  
  // ANT status
  String antStatus = antConnected ? (antConnMode == 1 ? "WiFi" : "USB") : "DISC";
  drawStatusItem(startX, iconY, "ANT", antStatus, antConnected ? theme.success : theme.error);
  
  // ROT status (con IP se WiFi)
  String rotStatus = rotConnected ? (rotConnMode == 1 ? rotWifiIP : "USB") : "DISC";
  drawStatusItem(startX + spacing, iconY, "ROT", rotStatus, rotConnected ? theme.success : theme.error);
  
  // Sistema
  drawStatusItem(startX + spacing * 2, iconY, "Sist", systemOn ? "ON" : "OFF", systemOn ? theme.success : theme.warning);
  
  // Direzione
  String rotatorSt = "STOP";
  color rotatorCol = theme.disabled;
  if (rotatorCW)  { rotatorSt = "→CW";  rotatorCol = theme.cwColor; }
  else if (rotatorCCW) { rotatorSt = "←CCW"; rotatorCol = theme.ccwColor; }
  drawStatusItem(startX + spacing * 3, iconY, "Dir", rotatorSt, rotatorCol);
  
  // Antenna
  String antSt = selectedAntenna >= 0 ? "ANT" + (selectedAntenna + 1) : "NESSUNA";
  drawStatusItem(startX + spacing * 4, iconY, "Ant", antSt, selectedAntenna >= 0 ? theme.accent : theme.disabled);
  
  // OVERLAP (solo se attivo)
  if (overlapActive) {
    float ovX = startX + spacing * 5;
    fill(color(255, 120, 0));
    noStroke();
    ellipse(ovX, iconY, 10, 10);
    fill(color(255, 120, 0), 50);
    ellipse(ovX, iconY, 16, 16);
    fill(color(255, 120, 0));
    textFont(fontBold);
    textSize(9);
    textAlign(LEFT, CENTER);
    text("OVERLAP", ovX + 8, iconY);
  }
  
  // FRENO (solo se visibile)
  if (showBrakeControls) {
    float brX = startX + spacing * 5 + (overlapActive ? 70 : 0);
    color brakeCol = brakeReleased ? theme.warning : theme.textDim;
    fill(brakeCol);
    noStroke();
    ellipse(brX, iconY, 8, 8);
    fill(brakeCol);
    textFont(fontRegular);
    textSize(9);
    textAlign(LEFT, CENTER);
    text("BRK:" + (brakeReleased ? "LIB" : "ON"), brX + 7, iconY);
  }
  
  // Azimuth con decimale
  float azX = px + pw - 155;
  String azStr = "AZ: " + nf(displayAzimuth, 1, 1) + "\u00b0";
  if (overlapActive) azStr += " (=" + int(displayAzimuth % 360) + "\u00b0)";
  fill(overlapActive ? color(255, 140, 0) : theme.text);
  textFont(fontBold);
  textSize(11);
  textAlign(LEFT, CENTER);
  text(azStr, azX, iconY);
  
  // Timestamp
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(10);
  textAlign(RIGHT, CENTER);
  text(getTimestamp(), px + pw - 15, iconY);
}

void drawStatusItem(float x, float y, String label, String value, color c) {
  fill(c);
  noStroke();
  ellipse(x, y, 10, 10);
  fill(c, 50);
  ellipse(x, y, 16, 16);
  
  fill(theme.text);
  textFont(fontRegular);
  textSize(9);
  textAlign(LEFT, CENTER);
  text(label + ":" + value, x + 10, y);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCHERMATA IMPOSTAZIONI
// ═══════════════════════════════════════════════════════════════════════════

void drawSettingsScreen() {
  float px = 40, py = 60, pw = 720, ph = 400;
  drawPanel(px, py, pw, ph, "IMPOSTAZIONI", false);
  drawSettingsTabs(px + 20, py + 45);
  
  switch(currentSettingsTab) {
    case 0: drawConnectionSettings(px, py + 90); break;
    case 1: drawAntennaSettings(px, py + 90); break;
    case 2: drawMapSettings(px, py + 90); break;
    case 3: drawLookSettings(px, py + 90); break;
    case 4: drawPreferencesSettings(px, py + 90); break;
  }
  
  // Global Save/Cancel only needed for Antenne tab (temp values)
  if (currentSettingsTab == 1) drawSettingsButtons(px, py + ph - 50);
}

void drawSettingsTabs(float x, float y) {
  String[] tabs = {"Connessioni", "Antenne", "Mappa", "Look", "Preferenze"};
  float tabW = 120, tabH = 32, gap = 8;
  
  for (int i = 0; i < tabs.length; i++) {
    float tx = x + i * (tabW + gap);
    boolean hover = mouseX > tx && mouseX < tx + tabW && mouseY > y && mouseY < y + tabH;
    boolean active = (currentSettingsTab == i);
    
    fill(active ? theme.accent : hover ? theme.hover : theme.secondary);
    stroke(active ? theme.accent : theme.border);
    strokeWeight(1);
    rect(tx, y, tabW, tabH, 6, 6, 0, 0);
    
    fill(active ? theme.primary : theme.text);
    textFont(fontBold);
    textSize(11);
    textAlign(CENTER, CENTER);
    text(tabs[i], tx + tabW/2, y + tabH/2);
  }
}

void drawAntennaSettings(float px, float py) {
  float fieldW = 140, fieldH = 26, rowH = 34;
  
  fill(theme.textDim);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("ANTENNA", px + 30, py + 5);
  text("NOME", px + 100, py + 5);
  text("PIN", px + 260, py + 5);
  text("DIR", px + 320, py + 5);
  
  for (int i = 0; i < 6; i++) {
    float rowY = py + 25 + i * rowH;
    
    fill(theme.accent);
    textFont(fontBold);
    textSize(11);
    textAlign(LEFT, CENTER);
    text("ANT " + (i + 1), px + 30, rowY + fieldH/2);
    
    drawTextField(px + 100, rowY, fieldW, fieldH, i, tempAntennaNames[i], "Nome");
    drawTextField(px + 250, rowY, 50, fieldH, i + 10, str(tempAntennaPins[i]), "Pin");
    drawCheckbox(px + 320, rowY + 5, tempAntennaDirective[i], i);
  }
}

void drawTextField(float x, float y, float w, float h, int idx, String value, String placeholder) {
  boolean editing = (editingField == idx);
  boolean hover = mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h;
  
  fill(editing ? theme.panelLight : hover ? theme.hover : theme.panel);
  stroke(editing ? theme.accent : theme.border);
  strokeWeight(editing ? 2 : 1);
  rect(x, y, w, h, 4);
  
  String display = editing ? inputBuffer : value;
  fill(display.length() == 0 ? theme.textDim : theme.text);
  if (display.length() == 0) display = placeholder;
  
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  if (display.length() > 16) display = display.substring(0, 14) + "...";
  text(display, x + 8, y + h/2);
  
  if (editing && millis() % 1000 < 500) {
    float tw = textWidth(inputBuffer);
    stroke(theme.accent);
    strokeWeight(1);
    line(x + 8 + tw, y + 5, x + 8 + tw, y + h - 5);
  }
}

void drawCheckbox(float x, float y, boolean checked, int idx) {
  float size = 18;
  boolean hover = mouseX > x && mouseX < x + size && mouseY > y && mouseY < y + size;
  
  fill(checked ? theme.accent : hover ? theme.hover : theme.panel);
  stroke(checked ? theme.accent : theme.border);
  strokeWeight(1);
  rect(x, y, size, size, 4);
  
  if (checked) {
    stroke(theme.primary);
    strokeWeight(2);
    noFill();
    line(x + 4, y + size/2, x + size/2 - 1, y + size - 5);
    line(x + size/2 - 1, y + size - 5, x + size - 4, y + 4);
  }
}

void drawConnectionSettings(float px, float py) {
  // ========== ESP32 ANTENNA SWITCH SECTION ==========
  fill(theme.accent);
  textFont(fontBold);
  textSize(12);
  textAlign(LEFT, TOP);
  text("ESP32 ANTENNA SWITCH", px + 30, py);
  
  // WiFi/USB Toggle
  float toggleY = py + 25;
  float toggleW = 60, toggleH = 25, toggleGap = 10;
  
  boolean usbHover = mouseX > px + 30 && mouseX < px + 30 + toggleW && mouseY > toggleY && mouseY < toggleY + toggleH;
  boolean wifiHover = mouseX > px + 30 + toggleW + toggleGap && mouseX < px + 30 + toggleW * 2 + toggleGap && mouseY > toggleY && mouseY < toggleY + toggleH;
  
  fill(antConnMode == 0 ? theme.accent : (usbHover ? theme.hover : theme.secondary));
  stroke(antConnMode == 0 ? theme.accent : theme.border);
  rect(px + 30, toggleY, toggleW, toggleH, 6);
  
  fill(antConnMode == 1 ? theme.accent : (wifiHover ? theme.hover : theme.secondary));
  stroke(antConnMode == 1 ? theme.accent : theme.border);
  rect(px + 30 + toggleW + toggleGap, toggleY, toggleW, toggleH, 6);
  
  fill(antConnMode == 0 ? theme.primary : theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("USB", px + 30 + toggleW/2, toggleY + toggleH/2);
  
  fill(antConnMode == 1 ? theme.primary : theme.text);
  text("WiFi", px + 30 + toggleW + toggleGap + toggleW/2, toggleY + toggleH/2);
  
  float configY = toggleY + 35;
  
  if (antConnMode == 0) {
    // USB Mode - Show COM ports
    fill(theme.text);
    textFont(fontRegular);
    textSize(10);
    textAlign(LEFT, CENTER);
    text("Porta: " + antComPort, px + 30, configY);
    
    // Mini port selector
    if (availablePorts != null && availablePorts.length > 0) {
      float portBtnW = 70, portBtnH = 22;
      for (int i = 0; i < min(availablePorts.length, 4); i++) {
        float pbx = px + 120 + i * (portBtnW + 5);
        boolean portSelected = availablePorts[i].equals(antComPort);
        boolean portHover = mouseX > pbx && mouseX < pbx + portBtnW && mouseY > configY - 11 && mouseY < configY + 11;
        
        fill(portSelected ? theme.accent : (portHover ? theme.hover : theme.secondary));
        stroke(portSelected ? theme.accent : theme.border);
        rect(pbx, configY - 11, portBtnW, portBtnH, 4);
        
        fill(portSelected ? theme.primary : theme.text);
        textAlign(CENTER, CENTER);
        textSize(9);
        text(availablePorts[i], pbx + portBtnW/2, configY);
      }
    }
  } else {
    // WiFi Mode - Show IP and Port as editable fields (labels LEFT of field)
    float ipLabelW = 22;
    fill(theme.textDim);
    textFont(fontRegular);
    textSize(10);
    textAlign(RIGHT, CENTER);
    text("IP:", px + 30 + ipLabelW, configY + 13);
    text("Porta:", px + 230, configY + 13);
    
    // IP field
    drawTextField(px + 56, configY, 130, 26, 20, antWifiIP, "192.168.1.100");
    
    // Port field
    drawTextField(px + 238, configY, 70, 26, 21, str(antWifiPort), "8080");
  }
  
  // Connect/Disconnect Button
  float antBtnY = configY + 30;
  color antConnColor = antConnected ? theme.error : theme.success;
  String antConnText = antConnected ? "DISCONNETTI" : "CONNETTI";
  boolean antConnHover = mouseX > px + 30 && mouseX < px + 150 && mouseY > antBtnY && mouseY < antBtnY + 32;
  
  fill(antConnHover ? lerpColor(antConnColor, theme.text, 0.2) : antConnColor);
  stroke(antConnColor);
  rect(px + 30, antBtnY, 120, 32, 6);
  
  fill(theme.primary);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text(antConnText, px + 90, antBtnY + 16);
  
  // Status LED
  float ledX = px + 160;
  fill(antConnected ? theme.success : theme.error);
  noStroke();
  ellipse(ledX, antBtnY + 16, 10, 10);
  
  // ========== ESP32 ROTATORE SECTION ==========
  float rotY = antBtnY + 50;
  fill(theme.accent);
  textFont(fontBold);
  textSize(12);
  textAlign(LEFT, TOP);
  text("ESP32 ROTATORE", px + 30, rotY);
  
  // WiFi/USB Toggle
  float rotToggleY = rotY + 25;
  
  boolean rotUsbHover = mouseX > px + 30 && mouseX < px + 30 + toggleW && mouseY > rotToggleY && mouseY < rotToggleY + toggleH;
  boolean rotWifiHover = mouseX > px + 30 + toggleW + toggleGap && mouseX < px + 30 + toggleW * 2 + toggleGap && mouseY > rotToggleY && mouseY < rotToggleY + toggleH;
  
  fill(rotConnMode == 0 ? theme.accent : (rotUsbHover ? theme.hover : theme.secondary));
  stroke(rotConnMode == 0 ? theme.accent : theme.border);
  rect(px + 30, rotToggleY, toggleW, toggleH, 6);
  
  fill(rotConnMode == 1 ? theme.accent : (rotWifiHover ? theme.hover : theme.secondary));
  stroke(rotConnMode == 1 ? theme.accent : theme.border);
  rect(px + 30 + toggleW + toggleGap, rotToggleY, toggleW, toggleH, 6);
  
  fill(rotConnMode == 0 ? theme.primary : theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("USB", px + 30 + toggleW/2, rotToggleY + toggleH/2);
  
  fill(rotConnMode == 1 ? theme.primary : theme.text);
  text("WiFi", px + 30 + toggleW + toggleGap + toggleW/2, rotToggleY + toggleH/2);
  
  float rotConfigY = rotToggleY + 35;
  
  if (rotConnMode == 0) {
    // USB Mode
    fill(theme.text);
    textFont(fontRegular);
    textSize(10);
    textAlign(LEFT, CENTER);
    text("Porta: " + rotComPort, px + 30, rotConfigY);
    
    if (availablePorts != null && availablePorts.length > 0) {
      float portBtnW = 70, portBtnH = 22;
      for (int i = 0; i < min(availablePorts.length, 4); i++) {
        float pbx = px + 120 + i * (portBtnW + 5);
        boolean portSelected = availablePorts[i].equals(rotComPort);
        boolean portHover = mouseX > pbx && mouseX < pbx + portBtnW && mouseY > rotConfigY - 11 && mouseY < rotConfigY + 11;
        
        fill(portSelected ? theme.accent : (portHover ? theme.hover : theme.secondary));
        stroke(portSelected ? theme.accent : theme.border);
        rect(pbx, rotConfigY - 11, portBtnW, portBtnH, 4);
        
        fill(portSelected ? theme.primary : theme.text);
        textAlign(CENTER, CENTER);
        textSize(9);
        text(availablePorts[i], pbx + portBtnW/2, rotConfigY);
      }
    }
  } else {
    // WiFi Mode - Show IP and Port as editable fields (labels LEFT of field)
    fill(theme.textDim);
    textFont(fontRegular);
    textSize(10);
    textAlign(RIGHT, CENTER);
    text("IP:", px + 52, rotConfigY + 13);
    text("Porta:", px + 230, rotConfigY + 13);
    
    // IP field
    drawTextField(px + 56, rotConfigY, 130, 26, 22, rotWifiIP, "192.168.1.101");
    
    // Port field
    drawTextField(px + 238, rotConfigY, 70, 26, 23, str(rotWifiPort), "8081");
  }
  
  // Connect/Disconnect Button
  float rotBtnY = rotConfigY + 30;
  color rotConnColor = rotConnected ? theme.error : theme.success;
  String rotConnText = rotConnected ? "DISCONNETTI" : "CONNETTI";
  boolean rotConnHover = mouseX > px + 30 && mouseX < px + 150 && mouseY > rotBtnY && mouseY < rotBtnY + 32;
  
  fill(rotConnHover ? lerpColor(rotConnColor, theme.text, 0.2) : rotConnColor);
  stroke(rotConnColor);
  rect(px + 30, rotBtnY, 120, 32, 6);
  
  fill(theme.primary);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text(rotConnText, px + 90, rotBtnY + 16);
  
  // Status LED
  ledX = px + 160;
  fill(rotConnected ? theme.success : theme.error);
  noStroke();
  ellipse(ledX, rotBtnY + 16, 10, 10);
  
  // Scan Ports Button (moved lower to avoid collision with Disconnetti)
  float scanBtnY = rotBtnY + 50;
  boolean scanHover = mouseX > px + 30 && mouseX < px + 130 && mouseY > scanBtnY && mouseY < scanBtnY + 28;
  fill(scanHover ? lerpColor(theme.warning, theme.text, 0.2) : theme.warning);
  stroke(theme.warning);
  rect(px + 30, scanBtnY, 100, 28, 6);
  
  fill(theme.primary);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("SCAN PORTE", px + 80, scanBtnY + 14);
}

void drawMapSettings(float px, float py) {
  // ── Mostra mappa nel quadrante ─────────────────────────────────────────
  drawCheckbox("Mostra immagine mappa", showMapImage, px + 30, py);
  
  // Percorso immagine mappa
  float pathY = py + 28;
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(9);
  textAlign(LEFT, CENTER);
  text("Percorso mappa:", px + 30, pathY + 6);
  
  fill(theme.panel);
  stroke(theme.border);
  strokeWeight(1);
  float pathFieldX = px + 130, pathFieldW = 220, pathFieldH = 22;
  rect(pathFieldX, pathY - 4, pathFieldW, pathFieldH, 4);
  
  String dispPath = mapImagePath.length() == 0 ? "(nessun file)" :
    (mapImagePath.length() > 30 ? "..." + mapImagePath.substring(mapImagePath.length() - 27) : mapImagePath);
  fill(mapImagePath.length() == 0 ? theme.textDim : theme.text);
  textFont(fontRegular);
  textSize(9);
  textAlign(LEFT, CENTER);
  text(dispPath, pathFieldX + 5, pathY + 7);
  
  // Sfoglia PNG/JPG button
  boolean sfogliaHover = mouseX > px + 360 && mouseX < px + 420 && mouseY > pathY - 4 && mouseY < pathY + 18;
  fill(sfogliaHover ? lerpColor(theme.accent, theme.text, 0.2) : theme.accent);
  stroke(theme.accent);
  rect(px + 360, pathY - 4, 60, 22, 6);
  fill(theme.primary);
  textFont(fontBold);
  textSize(9);
  textAlign(CENTER, CENTER);
  text("Sfoglia", px + 390, pathY + 7);
  
  // PDF info button
  boolean pdfHover = mouseX > px + 428 && mouseX < px + 488 && mouseY > pathY - 4 && mouseY < pathY + 18;
  fill(pdfHover ? lerpColor(theme.warning, theme.text, 0.2) : theme.warning);
  stroke(theme.warning);
  rect(px + 428, pathY - 4, 60, 22, 6);
  fill(theme.primary);
  textFont(fontBold);
  textSize(9);
  textAlign(CENTER, CENTER);
  text("PDF...", px + 458, pathY + 7);
  
  if (mapImagePath.length() > 0) {
    fill(maskedMapImage != null ? theme.success : theme.error);
    textFont(fontRegular);
    textSize(9);
    textAlign(LEFT, CENTER);
    text((maskedMapImage != null ? "(OK)" : "(ERR)"), px + 30, pathY + 29);
  }
  
  // ── Opacita mappa ──────────────────────────────────────────────────────
  float maY = py + 68;
  float maSliderX = px + 170, maSliderW = 200, maSliderH = 4, maKnobSize = 14;
  
  fill(showMapImage ? theme.textDim : color(red(theme.textDim), green(theme.textDim), blue(theme.textDim), 80));
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("Opacit\u00e0 mappa:", px + 30, maY + 2);
  
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(maSliderX, maY - 2, maSliderW, maSliderH, 2);
  
  float maKnobX = map(mapImageAlpha, 0.0, 1.0, maSliderX, maSliderX + maSliderW);
  boolean maHover = dist(mouseX, mouseY, maKnobX, maY - 2 + maSliderH/2) < maKnobSize;
  if ((maHover || mapAlphaSliderDragging) && showMapImage) {
    fill(theme.accent, 60); noStroke(); ellipse(maKnobX, maY - 2 + maSliderH/2, maKnobSize + 8, maKnobSize + 8);
  }
  fill(mapAlphaSliderDragging ? theme.accent : (showMapImage ? theme.text : theme.textDim));
  stroke(showMapImage ? theme.accent : theme.border);
  strokeWeight(2);
  ellipse(maKnobX, maY - 2 + maSliderH/2, maKnobSize, maKnobSize);
  fill(showMapImage ? theme.text : theme.textDim);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(int(mapImageAlpha * 100) + "%", maSliderX + maSliderW + 10, maY + 2);
  
  // ── Zoom mappa ─────────────────────────────────────────────────────────
  float zY = maY + 22;
  float zSliderX = px + 170, zSliderW = 200, zSliderH = 4, zKnobSize = 14;
  
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("Zoom mappa:", px + 30, zY + 2);
  
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(zSliderX, zY - 2, zSliderW, zSliderH, 2);
  
  float zKnobX = map(mapZoom, 0.5, 2.5, zSliderX, zSliderX + zSliderW);
  boolean zHover = dist(mouseX, mouseY, zKnobX, zY - 2 + zSliderH/2) < zKnobSize;
  if (zHover || mapZoomSliderDragging) {
    fill(theme.accent, 60); noStroke(); ellipse(zKnobX, zY - 2 + zSliderH/2, zKnobSize + 8, zKnobSize + 8);
  }
  fill(mapZoomSliderDragging ? theme.accent : theme.text);
  stroke(theme.accent);
  strokeWeight(2);
  ellipse(zKnobX, zY - 2 + zSliderH/2, zKnobSize, zKnobSize);
  fill(theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(nf(mapZoom, 1, 1) + "x", zSliderX + zSliderW + 10, zY + 2);
  
  // ── Offset X ───────────────────────────────────────────────────────────
  float oxY = zY + 22;
  float oxSliderX = px + 170, oxSliderW = 160, oxSliderH = 4, oxKnobSize = 14;
  
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("Offset X:", px + 30, oxY + 2);
  
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(oxSliderX, oxY - 2, oxSliderW, oxSliderH, 2);
  
  float oxKnobX = map(mapOffsetX, -100, 100, oxSliderX, oxSliderX + oxSliderW);
  boolean oxHover = dist(mouseX, mouseY, oxKnobX, oxY - 2 + oxSliderH/2) < oxKnobSize;
  if (oxHover || mapOffsetXSliderDragging) {
    fill(theme.accent, 60); noStroke(); ellipse(oxKnobX, oxY - 2 + oxSliderH/2, oxKnobSize + 8, oxKnobSize + 8);
  }
  fill(mapOffsetXSliderDragging ? theme.accent : theme.text);
  stroke(theme.accent);
  strokeWeight(2);
  ellipse(oxKnobX, oxY - 2 + oxSliderH/2, oxKnobSize, oxKnobSize);
  fill(theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(int(mapOffsetX) + "px", oxSliderX + oxSliderW + 10, oxY + 2);
  
  // ── Offset Y ───────────────────────────────────────────────────────────
  float oyY = oxY + 22;
  float oySliderX = px + 170, oySliderW = 160, oySliderH = 4, oyKnobSize = 14;
  
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("Offset Y:", px + 30, oyY + 2);
  
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(oySliderX, oyY - 2, oySliderW, oySliderH, 2);
  
  float oyKnobX = map(mapOffsetY, -100, 100, oySliderX, oySliderX + oySliderW);
  boolean oyHover = dist(mouseX, mouseY, oyKnobX, oyY - 2 + oySliderH/2) < oyKnobSize;
  if (oyHover || mapOffsetYSliderDragging) {
    fill(theme.accent, 60); noStroke(); ellipse(oyKnobX, oyY - 2 + oySliderH/2, oyKnobSize + 8, oyKnobSize + 8);
  }
  fill(mapOffsetYSliderDragging ? theme.accent : theme.text);
  stroke(theme.accent);
  strokeWeight(2);
  ellipse(oyKnobX, oyY - 2 + oySliderH/2, oyKnobSize, oyKnobSize);
  fill(theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(int(mapOffsetY) + "px", oySliderX + oySliderW + 10, oyY + 2);
  
  // Reset offset button (rect: px+360 to px+440, oxY-2 to oxY+40)
  boolean resetOfsHover = mouseX > px + 360 && mouseX < px + 440 && mouseY > oxY - 2 && mouseY < oxY + 40;
  fill(resetOfsHover ? lerpColor(theme.warning, theme.text, 0.2) : theme.warning);
  stroke(theme.warning);
  rect(px + 360, oxY - 2, 80, 42, 6);
  fill(theme.primary);
  textFont(fontBold);
  textSize(9);
  textAlign(CENTER, CENTER);
  text("Reset Pos", px + 400, oxY + 19);
  
  // ── Separator ──────────────────────────────────────────────────────────
  float sepY = oyY + 28;
  stroke(theme.border, 80);
  strokeWeight(1);
  line(px + 30, sepY, px + 680, sepY);
  
  // ── Checkboxes visibilita ──────────────────────────────────────────────
  float chkY = sepY + 10;
  float rowH = 26;
  drawCheckbox("Mostra controlli freno", showBrakeControls, px + 30, chkY);
  drawCheckbox("Mostra etichette gradi", showDegreeLabels, px + 30, chkY + rowH);
  drawCheckbox("Mostra punti cardinali (N/E/S/W)", showCardinals, px + 30, chkY + rowH * 2);
  drawCheckbox("Mostra pattern antenna direttiva", showBeamPattern, px + 30, chkY + rowH * 3);
  
  // ── Pattern beam opacity and width ───────────────────────────────────
  float bpY = chkY + rowH * 4 + 8;
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("Opacit\u00e0 pattern:", px + 30, bpY + 2);
  float bpSliderX = px + 165, bpSliderW = 150, bpSliderH = 4, bpKnobSize = 14;
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(bpSliderX, bpY - 2, bpSliderW, bpSliderH, 2);
  float bpKnobX = map(beamPatternOpacity, 0.0, 1.0, bpSliderX, bpSliderX + bpSliderW);
  boolean bpHover = dist(mouseX, mouseY, bpKnobX, bpY - 2 + bpSliderH/2) < bpKnobSize;
  if (bpHover || beamOpacitySliderDragging) { fill(theme.accent, 60); noStroke(); ellipse(bpKnobX, bpY - 2 + bpSliderH/2, bpKnobSize + 8, bpKnobSize + 8); }
  fill(beamOpacitySliderDragging ? theme.accent : theme.text);
  stroke(theme.accent);
  strokeWeight(2);
  ellipse(bpKnobX, bpY - 2 + bpSliderH/2, bpKnobSize, bpKnobSize);
  fill(theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(int(beamPatternOpacity * 100) + "%", bpSliderX + bpSliderW + 10, bpY + 2);
  
  float bwY = bpY + 22;
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("Apertura beam:", px + 30, bwY + 2);
  float bwSliderX = px + 165, bwSliderW = 150, bwSliderH = 4, bwKnobSize = 14;
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(bwSliderX, bwY - 2, bwSliderW, bwSliderH, 2);
  float bwKnobX = map(beamPatternBeamWidth, 10.0, 120.0, bwSliderX, bwSliderX + bwSliderW);
  boolean bwHover = dist(mouseX, mouseY, bwKnobX, bwY - 2 + bwSliderH/2) < bwKnobSize;
  if (bwHover || beamWidthSliderDragging) { fill(theme.accent, 60); noStroke(); ellipse(bwKnobX, bwY - 2 + bwSliderH/2, bwKnobSize + 8, bwKnobSize + 8); }
  fill(beamWidthSliderDragging ? theme.accent : theme.text);
  stroke(theme.accent);
  strokeWeight(2);
  ellipse(bwKnobX, bwY - 2 + bwSliderH/2, bwKnobSize, bwKnobSize);
  fill(theme.text);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(int(beamPatternBeamWidth) + "\u00b0", bwSliderX + bwSliderW + 10, bwY + 2);
}

void drawLookSettings(float px, float py) {
  // ── Selezione tema ─────────────────────────────────────────────────────
  fill(theme.textDim);
  textFont(fontBold);
  textSize(11);
  textAlign(LEFT, CENTER);
  text("TEMA COLORI:", px + 30, py + 10);
  
  String[] themeNames = {"Dark (Default)", "Midnight Blue", "Green Terminal"};
  float themeBtnW = 130, themeBtnH = 34, themeBtnGap = 12;
  float themeBtnY = py + 22;
  
  for (int i = 0; i < themeNames.length; i++) {
    float tbx = px + 30 + i * (themeBtnW + themeBtnGap);
    boolean tHover = mouseX > tbx && mouseX < tbx + themeBtnW && mouseY > themeBtnY && mouseY < themeBtnY + themeBtnH;
    boolean tActive = (currentThemeIdx == i);
    
    fill(tActive ? theme.accent : tHover ? theme.hover : theme.secondary);
    stroke(tActive ? theme.accent : theme.border);
    strokeWeight(tActive ? 2 : 1);
    rect(tbx, themeBtnY, themeBtnW, themeBtnH, 8);
    
    fill(tActive ? theme.primary : theme.text);
    textFont(fontBold);
    textSize(10);
    textAlign(CENTER, CENTER);
    text(themeNames[i], tbx + themeBtnW / 2, themeBtnY + themeBtnH / 2);
  }
  
  // ── Separator ──────────────────────────────────────────────────────────
  stroke(theme.border, 80);
  strokeWeight(1);
  line(px + 30, py + 72, px + 680, py + 72);
  
  // ── Checkboxes aspetto ─────────────────────────────────────────────────
  float chkY = py + 84;
  float rowH = 26;
  drawCheckbox("Attiva animazioni", showAnimations, px + 30, chkY);
  drawCheckbox("Mostra barra stato", showStatusBarFlag, px + 30, chkY + rowH);
}

void drawPreferencesSettings(float px, float py) {
  float rowH = 22;
  float y = py;
  
  // ── Checkboxes comportamento ───────────────────────────────────────────
  drawCheckbox("Spegni rele switch alla chiusura", disconnectRelaysOnExit, px + 30, y);
  drawCheckbox("Invia HALT al rotore alla chiusura", sendHaltOnExit, px + 30, y + rowH);
  drawCheckbox("Chiedi conferma prima di uscire", confirmOnExit, px + 30, y + rowH * 2);
  drawCheckbox("Auto-connetti all'avvio", autoConnect, px + 30, y + rowH * 3);
  drawCheckbox("Ricorda ultima antenna selezionata", rememberLastAntenna, px + 30, y + rowH * 4);
  drawCheckbox("Modalit\u00e0 debug", debugMode, px + 30, y + rowH * 5);
  
  // ── Separator ──────────────────────────────────────────────────────────
  float sepY = y + rowH * 6 + 6;
  stroke(theme.border, 80);
  strokeWeight(1);
  line(px + 30, sepY, px + 680, sepY);
  
  // ── Pulsanti Salva/Reset ────────────────────────────────────────────────
  float btnY = sepY + 20;
  boolean savePrefHover = mouseX > px + 30 && mouseX < px + 160 && mouseY > btnY && mouseY < btnY + 32;
  fill(savePrefHover ? lerpColor(theme.success, theme.text, 0.2) : theme.success);
  stroke(theme.success);
  rect(px + 30, btnY, 130, 32, 8);
  fill(theme.primary);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("Salva Preferenze", px + 95, btnY + 16);
  
  boolean resetPrefHover = mouseX > px + 175 && mouseX < px + 305 && mouseY > btnY && mouseY < btnY + 32;
  fill(resetPrefHover ? lerpColor(theme.warning, theme.text, 0.2) : theme.warning);
  stroke(theme.warning);
  rect(px + 175, btnY, 130, 32, 8);
  fill(theme.primary);
  text("Reset Default", px + 240, btnY + 16);
  
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(9);
  textAlign(LEFT, CENTER);
  text("v" + APP_VERSION + "  |  TX HTTP: " + httpCommandCount + "  |  Errori: " + httpErrorCount, px + 330, btnY + 16);
}

void drawSettingsButtons(float px, float py) {
  float btnW = 100, btnH = 35;
  float centerX = px + 360;
  
  boolean saveHover = mouseX > centerX - btnW - 10 && mouseX < centerX - 10 && mouseY > py && mouseY < py + btnH;
  fill(saveHover ? lerpColor(theme.success, theme.text, 0.2) : theme.success);
  stroke(theme.success);
  rect(centerX - btnW - 10, py, btnW, btnH, 8);
  
  fill(theme.primary);
  textFont(fontBold);
  textSize(11);
  textAlign(CENTER, CENTER);
  text("SALVA", centerX - btnW/2 - 10, py + btnH/2);
  
  boolean cancelHover = mouseX > centerX + 10 && mouseX < centerX + btnW + 10 && mouseY > py && mouseY < py + btnH;
  fill(cancelHover ? lerpColor(theme.warning, theme.text, 0.2) : theme.warning);
  stroke(theme.warning);
  rect(centerX + 10, py, btnW, btnH, 8);
  
  fill(theme.primary);
  text("ANNULLA", centerX + btnW/2 + 10, py + btnH/2);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCHERMATA DEBUG
// ═══════════════════════════════════════════════════════════════════════════

void drawDebugScreen() {
  float px = 40, py = 60, pw = 720, ph = 400;
  drawPanel(px, py, pw, ph, "DEBUG CONSOLE", false);
  
  // Stats bar
  fill(theme.secondary);
  noStroke();
  rect(px + 15, py + 42, pw - 30, 18, 3);
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(9);
  textAlign(LEFT, CENTER);
  text("HTTP TX: " + httpCommandCount + "  |  Errori: " + httpErrorCount +
       "  |  Linee log: " + debugLog.size() +
       (rotConnected && rotConnMode == 1 ? "  |  Connesso: " + rotWifiIP : ""),
       px + 25, py + 51);
  
  fill(theme.primary);
  noStroke();
  rect(px + 15, py + 62, pw - 30, ph - 112, 6);
  
  textFont(fontMono);
  textSize(10);
  textAlign(LEFT, TOP);
  
  int maxLines = (int)((ph - 132) / 14);
  int startIdx = max(0, debugLog.size() - maxLines);
  
  for (int i = startIdx; i < debugLog.size(); i++) {
    String line = debugLog.get(i);
    color lineColor = theme.success;
    if (line.contains("ERRORE") || line.contains("ERROR")) lineColor = theme.error;
    else if (line.contains("WARNING") || line.contains("HALT")) lineColor = theme.warning;
    else if (line.contains("TX:") || line.contains("RX:")) lineColor = theme.accent;
    else if (line.contains("OVERLAP")) lineColor = color(255, 140, 0);
    
    fill(lineColor);
    text(line, px + 25, py + 72 + (i - startIdx) * 14);
  }
  
  float btnX = px + pw - 90, btnY = py + ph - 40;
  boolean clearHover = mouseX > btnX && mouseX < btnX + 70 && mouseY > btnY && mouseY < btnY + 28;
  
  fill(clearHover ? lerpColor(theme.warning, theme.text, 0.2) : theme.warning);
  stroke(theme.warning);
  rect(btnX, btnY, 70, 28, 6);
  
  fill(theme.primary);
  textFont(fontBold);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("CLEAR", btnX + 35, btnY + 14);
}

// ═══════════════════════════════════════════════════════════════════════════
//  UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════

void drawPanel(float x, float y, float w, float h, String title, boolean showGlow) {
  fill(0, 0, 0, 50);
  noStroke();
  rect(x + 5, y + 5, w, h, 15);
  
  fill(theme.panel);
  stroke(theme.border);
  strokeWeight(1);
  rect(x, y, w, h, 15);
  
  if (showGlow) {
    stroke(theme.accent, 80);
    strokeWeight(2);
    noFill();
    arc(x + w/2, y, w - 40, 30, PI, TWO_PI);
  }
  
  fill(theme.accent);
  textFont(fontLarge);
  textSize(15);
  textAlign(LEFT, TOP);
  // Strip non-ASCII characters (emoji, Unicode icons) that Processing cannot render
  String cleanTitle = title.replaceAll("[^\\x00-\\x7F]", "").trim();
  text(cleanTitle, x + 20, y + 15);
  
  stroke(theme.border);
  strokeWeight(1);
  line(x + 20, y + 38, x + w - 20, y + 38);
}

// ─── Checkbox con etichetta (overload con label) ─────────────────────────
void drawCheckbox(String label, boolean checked, float x, float y) {
  float size = 18;
  boolean hover = mouseX > x && mouseX < x + size && mouseY > y && mouseY < y + size;
  
  fill(checked ? theme.accent : hover ? theme.hover : theme.panel);
  stroke(checked ? theme.accent : theme.border);
  strokeWeight(1);
  rect(x, y, size, size, 4);
  
  if (checked) {
    stroke(theme.primary);
    strokeWeight(2);
    noFill();
    line(x + 4, y + size/2, x + size/2 - 1, y + size - 5);
    line(x + size/2 - 1, y + size - 5, x + size - 4, y + 4);
  }
  
  fill(theme.text);
  textFont(fontRegular);
  textSize(11);
  textAlign(LEFT, CENTER);
  text(label, x + size + 8, y + size/2);
}

// ─── Sotto-pannello per raggruppare opzioni ─────────────────────────────
void drawSettingsSubPanel(float x, float y, float w, float h, String title) {
  fill(theme.secondary);
  stroke(theme.border);
  strokeWeight(1);
  rect(x, y, w, h, 8);
  
  fill(theme.accent);
  textFont(fontBold);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(title, x + 10, y + 12);
  
  stroke(theme.border, 60);
  strokeWeight(1);
  line(x + 10, y + 22, x + w - 10, y + 22);
}

// ─── Etichetta grigia ───────────────────────────────────────────────────
void drawSettingsLabel(String label, float x, float y) {
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text(label, x, y);
}

// ─── Applica tema colori ─────────────────────────────────────────────────
void applyTheme(int idx) {
  currentThemeIdx = idx;
  if (idx == 0) {
    // Dark (Default)
    theme.primary    = #000000;
    theme.secondary  = #1A1A1A;
    theme.accent     = #00FF88;
    theme.background = #0A0A0A;
    theme.panel      = #111111;
    theme.panelLight = #1E1E1E;
    theme.text       = #FFFFFF;
    theme.textDim    = #888888;
    theme.border     = #444444;
    theme.hover      = #2A2A2A;
  } else if (idx == 1) {
    // Midnight Blue
    theme.primary    = #0A0A1A;
    theme.secondary  = #151530;
    theme.accent     = #4488FF;
    theme.background = #080815;
    theme.panel      = #101025;
    theme.panelLight = #1A1A35;
    theme.text       = #DDDDFF;
    theme.textDim    = #7777AA;
    theme.border     = #333366;
    theme.hover      = #20204A;
  } else if (idx == 2) {
    // Green Terminal
    theme.primary    = #001100;
    theme.secondary  = #0A1A0A;
    theme.accent     = #00FF00;
    theme.background = #000800;
    theme.panel      = #0A140A;
    theme.panelLight = #122012;
    theme.text       = #00EE00;
    theme.textDim    = #007700;
    theme.border     = #003300;
    theme.hover      = #1A2A1A;
  }
}

void drawTopBar() {
  fill(theme.secondary);
  noStroke();
  rect(0, 0, width, 45);
  
  stroke(theme.border);
  strokeWeight(1);
  line(0, 45, width, 45);
  
  fill(theme.accent);
  textFont(fontLarge);
  textSize(16);
  textAlign(LEFT, CENTER);
  text(APP_NAME, 20, 22);
  
  fill(theme.textDim);
  textFont(fontRegular);
  textSize(9);
  text("v" + APP_VERSION, 195, 22);
  
  float ledX = width - 310;
  float pulse = 0.5 + 0.5 * sin(millis() * 0.005);
  
  // ANT LED
  fill(antConnected ? lerpColor(theme.success, color(255), pulse * 0.3) : theme.error);
  noStroke();
  ellipse(ledX, 22, 10, 10);
  
  fill(theme.text);
  textFont(fontRegular);
  textSize(10);
  textAlign(LEFT, CENTER);
  text("ANT: " + (antConnected ? "OK" : "Disc."), ledX + 12, 22);
  
  // ROT LED
  float ledX2 = ledX + 120;
  fill(rotConnected ? lerpColor(theme.success, color(255), pulse * 0.3) : theme.error);
  noStroke();
  ellipse(ledX2, 22, 10, 10);
  
  fill(theme.text);
  text("ROT: " + (rotConnected ? "OK" : "Disc."), ledX2 + 12, 22);
  
  drawPowerSwitch(width - 75, 12);
}

void drawPowerSwitch(float x, float y) {
  float w = 55, h = 22;
  
  // Smooth color transition
  color switchColor = lerpColor(theme.disabled, theme.success, powerSwitchAnim);
  color borderColor = lerpColor(theme.border, theme.success, powerSwitchAnim);
  
  fill(switchColor);
  stroke(borderColor);
  strokeWeight(1);
  rect(x, y, w, h, 11);
  
  // Smooth handle position with easing
  float targetX = systemOn ? x + w - 18 : x + 3;
  float handleX = lerp(x + 3, x + w - 18, easeInOutCubic(powerSwitchAnim));
  
  // Handle
  fill(255);
  noStroke();
  ellipse(handleX + 7, y + 11, 16, 16);
  
  // Glow effect when ON
  if (powerSwitchAnim > 0.1) {
    fill(theme.success, 60 * powerSwitchAnim);
    ellipse(handleX + 7, y + 11, 22, 22);
  }
  
  fill(theme.textDim);
  textFont(fontBold);
  textSize(8);
  textAlign(RIGHT, CENTER);
  text("PWR", x - 8, y + 11);
}

void drawNavigationBar() {
  String[] items = {"CONTROLLO", "IMPOSTAZIONI", "DEBUG"};
  float barW = 320, barH = 40;
  float startX = (width - barW) / 2;
  float startY = height - 48;
  float itemW = barW / items.length - 8;
  
  for (int i = 0; i < items.length; i++) {
    float ix = startX + i * (itemW + 8);
    boolean hover = mouseX > ix && mouseX < ix + itemW && mouseY > startY && mouseY < startY + barH;
    boolean active = (currentScreen == i);
    
    buttonHover[23 + i] = hover;
    float animValue = easeOutCubic(buttonAnim[23 + i]);
    
    pushMatrix();
    if (hover && !active) translate(0, -3 * animValue);
    
    // Enhanced shadow
    fill(0, 0, 0, 40 + 40 * animValue);
    noStroke();
    rect(ix + 2, startY + 3, itemW, barH, 8);
    
    fill(active ? theme.accent : hover ? theme.hover : theme.secondary);
    stroke(active ? theme.accent : theme.border);
    strokeWeight(active ? 2 : 1);
    rect(ix, startY, itemW, barH, 8);
    
    // Glow effect on active or hover
    if (active || hover) {
      noFill();
      stroke(active ? theme.accent : theme.hover, active ? 100 : 60 * animValue);
      strokeWeight(2);
      rect(ix - 1, startY - 1, itemW + 2, barH + 2, 9);
    }
    
    fill(active ? theme.primary : theme.text);
    textFont(fontBold);
    textSize(10);
    textAlign(CENTER, CENTER);
    text(items[i], ix + itemW/2, startY + barH/2);
    
    popMatrix();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EVENT HANDLERS
// ═══════════════════════════════════════════════════════════════════════════

void mousePressed() {
  if (currentScreen == 0) {
    checkAntennaClick();
    checkRotatorPowerClick();
    checkRotatorButtonsPressed();
    checkAzimuthDialClick();
  } else if (currentScreen == 1) {
    checkSettingsClick();
  } else if (currentScreen == 2) {
    checkDebugClick();
  }
  
  checkTopBarClick();
  checkNavigationClick();
}

void mouseReleased() {
  if (cwButtonPressed || ccwButtonPressed) {
    deactivateRotatorRelays();
  }
  
  // Send command when brake delay slider finishes dragging
  if (brakeSliderDragging) {
    sendRotatorCommand("DELAY:" + brakeDelayMs);
  }
  
  // Stop all slider dragging
  brakeSliderDragging = false;
  if (mapAlphaSliderDragging || mapZoomSliderDragging || mapOffsetXSliderDragging || mapOffsetYSliderDragging) {
    settings.saveSettings();
    if (mapZoomSliderDragging || mapOffsetXSliderDragging || mapOffsetYSliderDragging) {
      rebuildMaskedMap();
    }
  }
  mapAlphaSliderDragging = false;
  mapZoomSliderDragging = false;
  mapOffsetXSliderDragging = false;
  mapOffsetYSliderDragging = false;
  if (beamOpacitySliderDragging || beamWidthSliderDragging) {
    settings.saveSettings();
  }
  beamOpacitySliderDragging = false;
  beamWidthSliderDragging = false;
}

void mouseDragged() {
  // Handle brake delay slider in rotator panel (screen 0, showBrakeControls)
  if (currentScreen == 0 && showBrakeControls) {
    float centerX = mapCenterX;
    float btnY = mapCenterY + 170;
    float btnH = 38;
    float brakeSliderY = btnY + btnH + 55;
    float sliderW = 200, sliderH = 4, sliderX = centerX - sliderW / 2;
    float knobSize = 14;
    
    // Brake delay knob
    float brakeKnobX = map(brakeDelayMs, brakeDelayMin, brakeDelayMax, sliderX, sliderX + sliderW);
    if (!brakeSliderDragging && dist(mouseX, mouseY, brakeKnobX, brakeSliderY + sliderH/2) < knobSize) {
      brakeSliderDragging = true;
    }
    if (brakeSliderDragging) {
      float newValue = map(constrain(mouseX, sliderX, sliderX + sliderW), sliderX, sliderX + sliderW, brakeDelayMin, brakeDelayMax);
      brakeDelayMs = int(newValue / 50) * 50;
      brakeDelayMs = constrain(brakeDelayMs, brakeDelayMin, brakeDelayMax);
      return;
    }
  }
  
  // Handle sliders in Mappa settings (screen 1, tab 2)
  if (currentScreen == 1 && currentSettingsTab == 2) {
    float px = 40;
    float contentY = 60 + 90;
    float maY = contentY + 68;
    float zY = maY + 22;
    float oxY = zY + 22;
    float oyY = oxY + 22;
    
    // Map alpha slider
    float maSliderX = px + 170, maSliderW = 200, maSliderH = 4, maKnobSize = 14;
    float maKnobX = map(mapImageAlpha, 0.0, 1.0, maSliderX, maSliderX + maSliderW);
    if (!mapAlphaSliderDragging && !mapZoomSliderDragging && !mapOffsetXSliderDragging && !mapOffsetYSliderDragging
        && !beamOpacitySliderDragging && !beamWidthSliderDragging && showMapImage
        && dist(mouseX, mouseY, maKnobX, maY - 2 + maSliderH/2) < maKnobSize) {
      mapAlphaSliderDragging = true;
    }
    if (mapAlphaSliderDragging) {
      mapImageAlpha = map(constrain(mouseX, maSliderX, maSliderX + maSliderW), maSliderX, maSliderX + maSliderW, 0.0, 1.0);
      mapImageAlpha = constrain(mapImageAlpha, 0.0, 1.0);
      return;
    }
    
    // Map zoom slider
    float zSliderX = px + 170, zSliderW = 200, zSliderH = 4, zKnobSize = 14;
    float zKnobX = map(mapZoom, 0.5, 2.5, zSliderX, zSliderX + zSliderW);
    if (!mapAlphaSliderDragging && !mapZoomSliderDragging && !mapOffsetXSliderDragging && !mapOffsetYSliderDragging
        && !beamOpacitySliderDragging && !beamWidthSliderDragging
        && dist(mouseX, mouseY, zKnobX, zY - 2 + zSliderH/2) < zKnobSize) {
      mapZoomSliderDragging = true;
    }
    if (mapZoomSliderDragging) {
      mapZoom = map(constrain(mouseX, zSliderX, zSliderX + zSliderW), zSliderX, zSliderX + zSliderW, 0.5, 2.5);
      mapZoom = constrain(mapZoom, 0.5, 2.5);
      return;
    }
    
    // Offset X slider
    float oxSliderX = px + 170, oxSliderW = 160, oxSliderH = 4, oxKnobSize = 14;
    float oxKnobX = map(mapOffsetX, -100, 100, oxSliderX, oxSliderX + oxSliderW);
    if (!mapAlphaSliderDragging && !mapZoomSliderDragging && !mapOffsetXSliderDragging && !mapOffsetYSliderDragging
        && !beamOpacitySliderDragging && !beamWidthSliderDragging
        && dist(mouseX, mouseY, oxKnobX, oxY - 2 + oxSliderH/2) < oxKnobSize) {
      mapOffsetXSliderDragging = true;
    }
    if (mapOffsetXSliderDragging) {
      mapOffsetX = map(constrain(mouseX, oxSliderX, oxSliderX + oxSliderW), oxSliderX, oxSliderX + oxSliderW, -100, 100);
      mapOffsetX = constrain(mapOffsetX, -100, 100);
      return;
    }
    
    // Offset Y slider
    float oySliderX = px + 170, oySliderW = 160, oySliderH = 4, oyKnobSize = 14;
    float oyKnobX = map(mapOffsetY, -100, 100, oySliderX, oySliderX + oySliderW);
    if (!mapAlphaSliderDragging && !mapZoomSliderDragging && !mapOffsetXSliderDragging && !mapOffsetYSliderDragging
        && !beamOpacitySliderDragging && !beamWidthSliderDragging
        && dist(mouseX, mouseY, oyKnobX, oyY - 2 + oySliderH/2) < oyKnobSize) {
      mapOffsetYSliderDragging = true;
    }
    if (mapOffsetYSliderDragging) {
      mapOffsetY = map(constrain(mouseX, oySliderX, oySliderX + oySliderW), oySliderX, oySliderX + oySliderW, -100, 100);
      mapOffsetY = constrain(mapOffsetY, -100, 100);
      return;
    }
    
    // Beam pattern opacity slider
    float sepY = oyY + 28;
    float chkY = sepY + 10;
    float rowH = 26;
    float bpY = chkY + rowH * 4 + 8;
    float bpSliderX = px + 165, bpSliderW = 150, bpSliderH = 4, bpKnobSize = 14;
    float bpKnobX = map(beamPatternOpacity, 0.0, 1.0, bpSliderX, bpSliderX + bpSliderW);
    if (!mapAlphaSliderDragging && !mapZoomSliderDragging && !mapOffsetXSliderDragging && !mapOffsetYSliderDragging
        && !beamOpacitySliderDragging && !beamWidthSliderDragging
        && dist(mouseX, mouseY, bpKnobX, bpY - 2 + bpSliderH/2) < bpKnobSize) {
      beamOpacitySliderDragging = true;
    }
    if (beamOpacitySliderDragging) {
      beamPatternOpacity = map(constrain(mouseX, bpSliderX, bpSliderX + bpSliderW), bpSliderX, bpSliderX + bpSliderW, 0.0, 1.0);
      beamPatternOpacity = constrain(beamPatternOpacity, 0.0, 1.0);
      return;
    }
    
    // Beam pattern beamwidth slider
    float bwY = bpY + 22;
    float bwSliderX = px + 165, bwSliderW = 150, bwSliderH = 4, bwKnobSize = 14;
    float bwKnobX = map(beamPatternBeamWidth, 10.0, 120.0, bwSliderX, bwSliderX + bwSliderW);
    if (!mapAlphaSliderDragging && !mapZoomSliderDragging && !mapOffsetXSliderDragging && !mapOffsetYSliderDragging
        && !beamOpacitySliderDragging && !beamWidthSliderDragging
        && dist(mouseX, mouseY, bwKnobX, bwY - 2 + bwSliderH/2) < bwKnobSize) {
      beamWidthSliderDragging = true;
    }
    if (beamWidthSliderDragging) {
      beamPatternBeamWidth = map(constrain(mouseX, bwSliderX, bwSliderX + bwSliderW), bwSliderX, bwSliderX + bwSliderW, 10.0, 120.0);
      beamPatternBeamWidth = constrain(beamPatternBeamWidth, 10.0, 120.0);
      return;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ROTATOR POWER CONTROL (ON/OFF)
// ═══════════════════════════════════════════════════════════════════════════

void checkRotatorPowerClick() {
  if (! systemOn) return;
  
  float px = 330, py = 55;
  float x = px + 20, y = py + 45;
  float w = 120, h = 30;
  
  if (mouseX > x && mouseX < x + w && mouseY > y && mouseY < y + h) {
    toggleRotatorPower();
  }
}

void toggleRotatorPower() {
  rotatorPowerOn = !rotatorPowerOn;
  
  if (! rotatorPowerOn) {
    // Spegni movimento quando si spegne il rotatore
    deactivateRotatorRelays();
  }
  
  addDebugLog("Rotator Power: " + (rotatorPowerOn ? "ON" : "OFF"));
  sendRotatorCommand("ROTATOR_PWR:" + (rotatorPowerOn ?  "1" : "0"));
  addNotification("Rotator " + (rotatorPowerOn ?  "ON" : "OFF"), rotatorPowerOn ? SUCCESS : WARNING);
}

// ═══════════════════════════════════════════════════════════════════════════
//  PULSANTI NA - CONTROLLO RELÈ ROTATORE
// ═══════════════════════════════════════════════════════════════════════════

void deactivateRotatorRelays() {
  if (cwButtonPressed) {
    cwButtonPressed = false;
    rotatorCW = false;
    addDebugLog("CW: Rilasciato → Relè A0 OFF");
    sendRotatorCommand("CW:0");
  }
  
  if (ccwButtonPressed) {
    ccwButtonPressed = false;
    rotatorCCW = false;
    addDebugLog("CCW: Rilasciato → Relè A1 OFF");
    sendRotatorCommand("CCW:0");
  }
}

void activateCWRelay() {
  if (!cwButtonPressed && systemOn && rotatorPowerOn) {
    if (ccwButtonPressed) {
      ccwButtonPressed = false;
      rotatorCCW = false;
      sendRotatorCommand("CCW:0");
    }
    
    // Auto-activate brake release when starting rotation
    if (!brakeReleased) {
      brakeReleased = true;
      sendRotatorCommand("BRAKE:1");
      addDebugLog("Brake: Auto-released for CW");
    }
    
    cwButtonPressed = true;
    rotatorCW = true;
    rotationStartTime = millis();
    addDebugLog("CW: Premuto → Relè A0 ON");
    sendRotatorCommand("CW:1");
  }
}

void activateCCWRelay() {
  if (!ccwButtonPressed && systemOn && rotatorPowerOn) {
    if (cwButtonPressed) {
      cwButtonPressed = false;
      rotatorCW = false;
      sendRotatorCommand("CW:0");
    }
    
    // Auto-activate brake release when starting rotation
    if (!brakeReleased) {
      brakeReleased = true;
      sendRotatorCommand("BRAKE:1");
      addDebugLog("Brake: Auto-released for CCW");
    }
    
    ccwButtonPressed = true;
    rotatorCCW = true;
    rotationStartTime = millis();
    addDebugLog("CCW: Premuto → Relè A1 ON");
    sendRotatorCommand("CCW:1");
  }
}

void checkRotatorButtonsPressed() {
  if (!systemOn || !rotatorPowerOn) return;
  
  float centerX = mapCenterX;
  float btnY = mapCenterY + 170;
  float btnH = 38, gap = 8;
  
  if (showBrakeControls) {
    float btnW = 60;
    float totalWidth = btnW * 4 + gap * 3;
    float startX = centerX - totalWidth / 2;
    
    // CCW
    if (mouseX > startX && mouseX < startX + btnW && mouseY > btnY && mouseY < btnY + btnH) {
      activateCCWRelay(); return;
    }
    // HALT
    float haltX = startX + btnW + gap;
    if (mouseX > haltX && mouseX < haltX + btnW && mouseY > btnY && mouseY < btnY + btnH) {
      emergencyHalt(); return;
    }
    // FRENO
    float brakeX = startX + (btnW + gap) * 2;
    if (mouseX > brakeX && mouseX < brakeX + btnW && mouseY > btnY && mouseY < btnY + btnH) {
      activateBrake(); return;
    }
    // CW
    float cwX = startX + (btnW + gap) * 3;
    if (mouseX > cwX && mouseX < cwX + btnW && mouseY > btnY && mouseY < btnY + btnH) {
      activateCWRelay(); return;
    }
    
  } else {
    // Layout 3 pulsanti senza freno
    float totalWidth = 60.0 * 4 + gap * 3;
    float btnW = (totalWidth - gap * 2) / 3;
    float startX = centerX - totalWidth / 2;
    
    // CCW
    if (mouseX > startX && mouseX < startX + btnW && mouseY > btnY && mouseY < btnY + btnH) {
      activateCCWRelay(); return;
    }
    // HALT
    float haltX = startX + btnW + gap;
    if (mouseX > haltX && mouseX < haltX + btnW && mouseY > btnY && mouseY < btnY + btnH) {
      emergencyHalt(); return;
    }
    // CW
    float cwX = startX + (btnW + gap) * 2;
    if (mouseX > cwX && mouseX < cwX + btnW && mouseY > btnY && mouseY < btnY + btnH) {
      activateCWRelay(); return;
    }
  }
}

void activateBrake() {
  if (!systemOn || !rotatorPowerOn) return;
  
  brakeReleased = !brakeReleased;
  brakeButtonPressed = brakeReleased;
  
  if (brakeReleased) {
    addDebugLog("Brake: RELEASED");
    sendRotatorCommand("BRAKE:1");
    addNotification("Brake Released", SUCCESS);
  } else {
    addDebugLog("Brake: ENGAGED delay " + brakeDelayMs + "ms");
    sendRotatorCommand("BRAKE:0:" + brakeDelayMs);
    addNotification("Brake Engaged", WARNING);
  }
}

void checkAzimuthDialClick() {
  if (!systemOn || !rotatorPowerOn) return;
  
  // Check if click is inside the azimuth dial circle
  float dx = mouseX - mapCenterX;
  float dy = mouseY - mapCenterY;
  float distance = sqrt(dx * dx + dy * dy);
  
  // Only respond to clicks within the outer ring (outside center circle)
  if (distance > 35 && distance < mapRadius) {
    // Calculate angle from click position
    float clickAngle = atan2(dy, dx);
    float degrees = degrees(clickAngle) + 90;
    if (degrees < 0) degrees += 360;
    if (degrees >= 360) degrees -= 360;
    
    // Set target azimuth
    targetAzimuth = degrees;
    goToActive = true;
    goToTarget = degrees;
    
    // Auto-activate brake release for Go To
    if (!brakeReleased) {
      brakeReleased = true;
      sendRotatorCommand("BRAKE:1");
      addDebugLog("Brake: Auto-released for GOTO");
    }
    
    // Send GOTO command
    sendRotatorCommand("GOTO:" + nf(targetAzimuth, 1, 1));
    addDebugLog("GOTO: Target set to " + nf(targetAzimuth, 1, 1) + "°");
    addNotification("Target: " + nf(targetAzimuth, 1, 1) + "°", SUCCESS);
  }
}

void emergencyHalt() {
  cwButtonPressed = false;
  ccwButtonPressed = false;
  rotatorCW = false;
  rotatorCCW = false;
  brakeButtonPressed = false;
  brakeReleased = false;
  
  // Always clear target on HALT so it disappears from the map
  targetAzimuth = -1;
  goToActive = false;
  goToTarget = -1;
  
  addDebugLog("!!! EMERGENCY HALT !!!");
  sendRotatorCommand("CW:0");
  sendRotatorCommand("CCW:0");
  sendRotatorCommand("BRAKE:0:0");
  sendRotatorCommand("HALT:1");
  sendRotatorCommand("GOTO:HALT");
  
  addNotification("EMERGENCY HALT!", ERROR);
}

// ═══════════════════════════════════════════════════════════════════════════
//  CONTROLLI ANTENNE
// ═══════════════════════════════════════════════════════════════════════════

void checkAntennaClick() {
  if (!systemOn) return;
  
  float px = 20, py = 55;
  float startX = px + 15, startY = py + 70;
  float btnW = 125, btnH = 52, gapX = 10, gapY = 8;
  
  for (int i = 0; i < 6; i++) {
    int col = i % 2, row = i / 2;
    float bx = startX + col * (btnW + gapX);
    float by = startY + row * (btnH + gapY);
    
    if (mouseX > bx && mouseX < bx + btnW && mouseY > by && mouseY < by + btnH) {
      selectAntenna(i);
      break;
    }
  }
}

void selectAntenna(int idx) {
  if (idx < 0 || idx >= 6) return;
  
  if (selectedAntenna == idx) {
    selectedAntenna = -1;
    for (int i = 0; i < 6; i++) antennaStates[i] = false;
    addDebugLog("Antenna " + antennaNames[idx] + " OFF");
  } else {
    for (int i = 0; i < 6; i++) antennaStates[i] = false;
    selectedAntenna = idx;
    antennaStates[idx] = true;
    addDebugLog("Antenna " + antennaNames[idx] + " ON");
  }
  
  sendAntennaCommand("ANT:" + idx + ":" + antennaPins[idx]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  CONTROLLI IMPOSTAZIONI
// ═══════════════════════════════════════════════════════════════════════════

void checkSettingsClick() {
  float px = 40, py = 60;
  
  // Tabs
  float tabY = py + 45, tabW = 120, tabH = 32, gap = 8;
  for (int i = 0; i < 5; i++) {
    float tx = px + 20 + i * (tabW + gap);
    if (mouseX > tx && mouseX < tx + tabW && mouseY > tabY && mouseY < tabY + tabH) {
      currentSettingsTab = i;
      editingField = -1;
      return;
    }
  }
  
  if (currentSettingsTab == 0) checkConnectionSettingsClick(px, py + 90);
  else if (currentSettingsTab == 1) checkAntennaSettingsClick(px, py + 90);
  else if (currentSettingsTab == 2) checkMapSettingsClick(px, py + 90);
  else if (currentSettingsTab == 3) checkLookSettingsClick(px, py + 90);
  else if (currentSettingsTab == 4) checkPreferencesSettingsClick(px, py + 90);
  
  // Salva/Annulla (only visible and active for Antenne tab)
  if (currentSettingsTab == 1) {
    float btnY = py + 350, centerX = px + 360, btnW = 100, btnH = 35;
    
    if (mouseX > centerX - btnW - 10 && mouseX < centerX - 10 && mouseY > btnY && mouseY < btnY + btnH) {
      saveSettings();
      return;
    }
    
    if (mouseX > centerX + 10 && mouseX < centerX + btnW + 10 && mouseY > btnY && mouseY < btnY + btnH) {
      cancelSettings();
      return;
    }
  }
}

void checkAntennaSettingsClick(float px, float py) {
  float fieldW = 140, fieldH = 26, rowH = 34;
  
  for (int i = 0; i < 6; i++) {
    float rowY = py + 25 + i * rowH;
    
    if (mouseX > px + 100 && mouseX < px + 100 + fieldW && mouseY > rowY && mouseY < rowY + fieldH) {
      editingField = i;
      inputBuffer = tempAntennaNames[i];
      return;
    }
    
    if (mouseX > px + 250 && mouseX < px + 300 && mouseY > rowY && mouseY < rowY + fieldH) {
      editingField = i + 10;
      inputBuffer = str(tempAntennaPins[i]);
      return;
    }
    
    if (mouseX > px + 320 && mouseX < px + 338 && mouseY > rowY + 5 && mouseY < rowY + 23) {
      tempAntennaDirective[i] = ! tempAntennaDirective[i];
      return;
    }
  }
  
  editingField = -1;
}

void checkConnectionSettingsClick(float px, float py) {
  float toggleW = 60, toggleH = 25, toggleGap = 10;
  
  // === ANTENNA SECTION ===
  float toggleY = py + 25;
  
  // ANT USB/WiFi toggle
  if (mouseX > px + 30 && mouseX < px + 30 + toggleW && mouseY > toggleY && mouseY < toggleY + toggleH) {
    antConnMode = 0;
    addDebugLog("ESP32 Antenna: modo USB");
    return;
  }
  
  if (mouseX > px + 30 + toggleW + toggleGap && mouseX < px + 30 + toggleW * 2 + toggleGap && mouseY > toggleY && mouseY < toggleY + toggleH) {
    antConnMode = 1;
    addDebugLog("ESP32 Antenna: modo WiFi");
    return;
  }
  
  // ANT Port selection (USB mode)
  if (antConnMode == 0 && availablePorts != null) {
    float configY = toggleY + 35;
    float portBtnW = 70, portBtnH = 22;
    for (int i = 0; i < min(availablePorts.length, 4); i++) {
      float pbx = px + 120 + i * (portBtnW + 5);
      if (mouseX > pbx && mouseX < pbx + portBtnW && mouseY > configY - 11 && mouseY < configY + 11) {
        antComPort = availablePorts[i];
        addDebugLog("ESP32 Antenna porta: " + antComPort);
        return;
      }
    }
  }
  
  // ANT WiFi IP/Port editing (WiFi mode)
  if (antConnMode == 1) {
    float configY = toggleY + 35;
    
    // IP field click (new position: px+56 to px+186)
    if (mouseX > px + 56 && mouseX < px + 186 && mouseY > configY && mouseY < configY + 26) {
      editingField = 20;
      inputBuffer = antWifiIP;
      return;
    }
    
    // Port field click (new position: px+238 to px+308)
    if (mouseX > px + 238 && mouseX < px + 308 && mouseY > configY && mouseY < configY + 26) {
      editingField = 21;
      inputBuffer = str(antWifiPort);
      return;
    }
  }
  
  // ANT Connect/Disconnect
  float configY = toggleY + 35;
  float antBtnY = configY + 30;
  if (mouseX > px + 30 && mouseX < px + 150 && mouseY > antBtnY && mouseY < antBtnY + 32) {
    if (antConnected) disconnectAntESP32();
    else connectAntESP32();
    return;
  }
  
  // === ROTATOR SECTION ===
  float rotY = antBtnY + 50;
  float rotToggleY = rotY + 25;
  
  // ROT USB/WiFi toggle
  if (mouseX > px + 30 && mouseX < px + 30 + toggleW && mouseY > rotToggleY && mouseY < rotToggleY + toggleH) {
    rotConnMode = 0;
    addDebugLog("ESP32 Rotatore: modo USB");
    return;
  }
  
  if (mouseX > px + 30 + toggleW + toggleGap && mouseX < px + 30 + toggleW * 2 + toggleGap && mouseY > rotToggleY && mouseY < rotToggleY + toggleH) {
    rotConnMode = 1;
    addDebugLog("ESP32 Rotatore: modo WiFi");
    return;
  }
  
  // ROT Port selection (USB mode)
  if (rotConnMode == 0 && availablePorts != null) {
    float rotConfigY = rotToggleY + 35;
    float portBtnW = 70, portBtnH = 22;
    for (int i = 0; i < min(availablePorts.length, 4); i++) {
      float pbx = px + 120 + i * (portBtnW + 5);
      if (mouseX > pbx && mouseX < pbx + portBtnW && mouseY > rotConfigY - 11 && mouseY < rotConfigY + 11) {
        rotComPort = availablePorts[i];
        addDebugLog("ESP32 Rotatore porta: " + rotComPort);
        return;
      }
    }
  }
  
  // ROT WiFi IP/Port editing (WiFi mode)
  if (rotConnMode == 1) {
    float rotConfigY = rotToggleY + 35;
    
    // IP field click (new position: px+56 to px+186)
    if (mouseX > px + 56 && mouseX < px + 186 && mouseY > rotConfigY && mouseY < rotConfigY + 26) {
      editingField = 22;
      inputBuffer = rotWifiIP;
      return;
    }
    
    // Port field click (new position: px+238 to px+308)
    if (mouseX > px + 238 && mouseX < px + 308 && mouseY > rotConfigY && mouseY < rotConfigY + 26) {
      editingField = 23;
      inputBuffer = str(rotWifiPort);
      return;
    }
  }
  
  // ROT Connect/Disconnect
  float rotConfigY = rotToggleY + 35;
  float rotBtnY = rotConfigY + 30;
  if (mouseX > px + 30 && mouseX < px + 150 && mouseY > rotBtnY && mouseY < rotBtnY + 32) {
    if (rotConnected) disconnectRotESP32();
    else connectRotESP32();
    return;
  }
  
  // Scan Ports (new y: rotBtnY + 50)
  float scanBtnY = rotBtnY + 50;
  if (mouseX > px + 30 && mouseX < px + 130 && mouseY > scanBtnY && mouseY < scanBtnY + 28) {
    scanSerialPorts();
    addNotification("Porte scansionate", INFO);
    return;
  }
}

void checkMapSettingsClick(float px, float py) {
  float size = 18;
  
  // Mostra immagine mappa checkbox
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > py && mouseY < py + size) {
    showMapImage = !showMapImage;
    settings.saveSettings();
    addDebugLog("Mappa quadrante: " + (showMapImage ? "ON" : "OFF"));
    return;
  }
  
  // Sfoglia button (PNG/JPG)
  float pathY = py + 28;
  if (mouseX > px + 360 && mouseX < px + 420 && mouseY > pathY - 4 && mouseY < pathY + 18) {
    selectInput("Seleziona immagine mappa (PNG/JPG)", "mapImageSelected");
    return;
  }
  
  // PDF info button
  if (mouseX > px + 428 && mouseX < px + 488 && mouseY > pathY - 4 && mouseY < pathY + 18) {
    addNotification("PDF: converti a PNG/JPG prima", WARNING);
    addDebugLog("Info PDF: Processing non supporta PDF nativamente.");
    addDebugLog("  Scarica la mappa da ns6t.net/azimuth, poi converti");
    addDebugLog("  a PNG/JPG con un visualizzatore PDF prima di importare.");
    return;
  }
  
  // Slider areas handled by mouseDragged
  
  float maY = py + 68;
  float zY = maY + 22;
  float oxY = zY + 22;
  float oyY = oxY + 22;
  
  // Reset offset button (same bounds as hover: px+360 to px+440, oxY-2 to oxY+40)
  if (mouseX > px + 360 && mouseX < px + 440 && mouseY > oxY - 2 && mouseY < oxY + 40) {
    mapOffsetX = 0;
    mapOffsetY = 0;
    rebuildMaskedMap();
    settings.saveSettings();
    addNotification("Offset resettato", INFO);
    return;
  }
  
  float sepY = oyY + 28;
  float chkY = sepY + 10;
  float rowH = 26;
  
  // Mostra controlli freno
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > chkY && mouseY < chkY + size) {
    showBrakeControls = !showBrakeControls;
    settings.saveSettings();
    addDebugLog("Controllo Freno: " + (showBrakeControls ? "ON" : "OFF"));
    addNotification("Freno " + (showBrakeControls ? "visibile" : "nascosto"), showBrakeControls ? SUCCESS : INFO);
    return;
  }
  
  // Mostra etichette gradi
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > chkY + rowH && mouseY < chkY + rowH + size) {
    showDegreeLabels = !showDegreeLabels;
    settings.saveSettings();
    return;
  }
  
  // Mostra cardinali
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > chkY + rowH * 2 && mouseY < chkY + rowH * 2 + size) {
    showCardinals = !showCardinals;
    settings.saveSettings();
    return;
  }
  
  // Mostra pattern antenna
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > chkY + rowH * 3 && mouseY < chkY + rowH * 3 + size) {
    showBeamPattern = !showBeamPattern;
    settings.saveSettings();
    return;
  }
}

void checkLookSettingsClick(float px, float py) {
  float size = 18;
  float themeBtnW = 130, themeBtnH = 34, themeBtnGap = 12;
  float themeBtnY = py + 22;
  
  for (int i = 0; i < 3; i++) {
    float tbx = px + 30 + i * (themeBtnW + themeBtnGap);
    if (mouseX > tbx && mouseX < tbx + themeBtnW && mouseY > themeBtnY && mouseY < themeBtnY + themeBtnH) {
      applyTheme(i);
      settings.saveSettings();
      addNotification("Tema applicato", SUCCESS);
      return;
    }
  }
  
  float chkY = py + 84;
  float rowH = 26;
  
  // Attiva animazioni
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > chkY && mouseY < chkY + size) {
    showAnimations = !showAnimations;
    settings.saveSettings();
    return;
  }
  
  // Mostra barra stato
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > chkY + rowH && mouseY < chkY + rowH + size) {
    showStatusBarFlag = !showStatusBarFlag;
    settings.saveSettings();
    return;
  }
}

void checkPreferencesSettingsClick(float px, float py) {
  float size = 18;
  float rowH = 22;
  float y = py;
  
  // disconnectRelaysOnExit
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > y && mouseY < y + size) {
    disconnectRelaysOnExit = !disconnectRelaysOnExit;
    settings.saveSettings();
    return;
  }
  // sendHaltOnExit
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > y + rowH && mouseY < y + rowH + size) {
    sendHaltOnExit = !sendHaltOnExit;
    settings.saveSettings();
    return;
  }
  // confirmOnExit
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > y + rowH * 2 && mouseY < y + rowH * 2 + size) {
    confirmOnExit = !confirmOnExit;
    settings.saveSettings();
    return;
  }
  // autoConnect
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > y + rowH * 3 && mouseY < y + rowH * 3 + size) {
    autoConnect = !autoConnect;
    settings.saveSettings();
    addNotification("Auto-connect " + (autoConnect ? "attivato" : "disattivato"), autoConnect ? SUCCESS : INFO);
    return;
  }
  // rememberLastAntenna
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > y + rowH * 4 && mouseY < y + rowH * 4 + size) {
    rememberLastAntenna = !rememberLastAntenna;
    settings.saveSettings();
    return;
  }
  // debugMode
  if (mouseX > px + 30 && mouseX < px + 30 + size && mouseY > y + rowH * 5 && mouseY < y + rowH * 5 + size) {
    debugMode = !debugMode;
    addDebugLog("Debug: " + (debugMode ? "ON" : "OFF"));
    settings.saveSettings();
    return;
  }
  
  // Slider area handled by mouseDragged
  float sepY = y + rowH * 6 + 6;
  float btnY = sepY + 20;
  
  // Salva Preferenze
  if (mouseX > px + 30 && mouseX < px + 160 && mouseY > btnY && mouseY < btnY + 32) {
    settings.saveSettings();
    addNotification("Preferenze salvate", SUCCESS);
    return;
  }
  
  // Reset Default
  if (mouseX > px + 175 && mouseX < px + 305 && mouseY > btnY && mouseY < btnY + 32) {
    resetToDefaults();
    addNotification("Reset completato", WARNING);
    return;
  }
}

void checkDebugClick() {
  float px = 40, py = 60, pw = 720, ph = 400;
  float btnX = px + pw - 90, btnY = py + ph - 40;
  
  if (mouseX > btnX && mouseX < btnX + 70 && mouseY > btnY && mouseY < btnY + 28) {
    debugLog.clear();
    addDebugLog("Log cancellato");
  }
}

void checkTopBarClick() {
  float switchX = width - 75, switchY = 12, switchW = 55, switchH = 22;
  
  if (mouseX > switchX && mouseX < switchX + switchW && mouseY > switchY && mouseY < switchY + switchH) {
    systemOn = !systemOn;
    addDebugLog("Sistema: " + (systemOn ? "ON" : "OFF"));
    
    if (! systemOn) {
      emergencyHalt();
      rotatorPowerOn = false;
      selectedAntenna = -1;
      brakeButtonPressed = false;
      brakeReleased = false;
      for (int i = 0; i < 6; i++) antennaStates[i] = false;
    }
    
    sendAntennaCommand("PWR:" + (systemOn ? "1" : "0"));
  }
}

void checkNavigationClick() {
  float barW = 320, barH = 40;
  float startX = (width - barW) / 2, startY = height - 48;
  float itemW = barW / 3 - 8;
  
  for (int i = 0; i < 3; i++) {
    float ix = startX + i * (itemW + 8);
    
    if (mouseX > ix && mouseX < ix + itemW && mouseY > startY && mouseY < startY + barH) {
      if (currentScreen != i) {
        targetScreen = i;
        transitioning = true;
        screenTransition = 0;
        editingField = -1;
      }
      return;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  KEYBOARD
// ═══════════════════════════════════════════════════════════════════════════

void keyPressed() {
  if (editingField >= 0) {
    if (key == ENTER || key == RETURN) {
      editingField = -1;
    } else if (key == BACKSPACE) {
      if (inputBuffer.length() > 0) {
        inputBuffer = inputBuffer.substring(0, inputBuffer.length() - 1);
        updateFieldFromBuffer();
      }
    } else if (key == ESC) {
      editingField = -1;
      key = 0;
    } else if (key >= 32 && key <= 126) {
      if (editingField < 6 && inputBuffer.length() < 20) {
        inputBuffer += key;
        tempAntennaNames[editingField] = inputBuffer;
      } else if (editingField >= 10 && editingField < 16 && key >= '0' && key <= '9' && inputBuffer.length() < 2) {
        inputBuffer += key;
        tempAntennaPins[editingField - 10] = int(inputBuffer);
      } else if (editingField == 20 && inputBuffer.length() < 15) {
        // antWifiIP
        inputBuffer += key;
        antWifiIP = inputBuffer;
      } else if (editingField == 21 && key >= '0' && key <= '9' && inputBuffer.length() < 5) {
        // antWifiPort
        inputBuffer += key;
        antWifiPort = int(inputBuffer);
      } else if (editingField == 22 && inputBuffer.length() < 15) {
        // rotWifiIP
        inputBuffer += key;
        rotWifiIP = inputBuffer;
      } else if (editingField == 23 && key >= '0' && key <= '9' && inputBuffer.length() < 5) {
        // rotWifiPort
        inputBuffer += key;
        rotWifiPort = int(inputBuffer);
      }
    }
    return;
  }
  
  if (key == 'h' || key == 'H') { emergencyHalt(); }
  if (key == 'r' || key == 'R') { scanSerialPorts(); addNotification("Porte scansionate", INFO); }
  if (key == 'd' || key == 'D') { debugMode = !debugMode; }
  if (key == 'p' || key == 'P') { if (systemOn) toggleRotatorPower(); }
  if (key == 'b' || key == 'B') { if (systemOn && rotatorPowerOn) activateBrake(); }
  if (systemOn && key >= '1' && key <= '6') { selectAntenna(key - '1'); }
  if (key == ESC) { if (currentScreen != 0) { targetScreen = 0; transitioning = true; screenTransition = 0; } key = 0; }
}

void updateFieldFromBuffer() {
  if (editingField >= 0 && editingField < 6) {
    tempAntennaNames[editingField] = inputBuffer;
  } else if (editingField >= 10 && editingField < 16 && inputBuffer.length() > 0) {
    tempAntennaPins[editingField - 10] = int(inputBuffer);
  } else if (editingField == 20) {
    antWifiIP = inputBuffer;
  } else if (editingField == 21 && inputBuffer.length() > 0) {
    antWifiPort = int(inputBuffer);
  } else if (editingField == 22) {
    rotWifiIP = inputBuffer;
  } else if (editingField == 23 && inputBuffer.length() > 0) {
    rotWifiPort = int(inputBuffer);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SETTINGS
// ═══════════════════════════════════════════════════════════════════════════

void saveSettings() {
  arrayCopy(tempAntennaNames, antennaNames);
  arrayCopy(tempAntennaPins, antennaPins);
  arrayCopy(tempAntennaDirective, antennaDirective);
  settings.saveSettings();
  addNotification("Impostazioni salvate", SUCCESS);
  targetScreen = 0; transitioning = true; screenTransition = 0;
}

void cancelSettings() {
  arrayCopy(antennaNames, tempAntennaNames);
  arrayCopy(antennaPins, tempAntennaPins);
  arrayCopy(antennaDirective, tempAntennaDirective);
  editingField = -1;
  targetScreen = 0; transitioning = true; screenTransition = 0;
}

void resetToDefaults() {
  for (int i = 0; i < 6; i++) {
    tempAntennaNames[i] = defaultAntennaNames[i];
    tempAntennaPins[i] = i + 4;
    tempAntennaDirective[i] = defaultAntennaDirective[i];
  }
  addDebugLog("Reset ai valori predefiniti");
}

// ═══════════════════════════════════════════════════════════════════════════
//  ESP32 COMMUNICATION
// ═══════════════════════════════════════════════════════════════════════════

// ESP32 Antenna Switch Functions
void connectAntESP32() {
  if (antConnected) return;
  
  try {
    if (antConnMode == 0) {
      // USB Mode
      addDebugLog("Connessione ESP32 Antenna via USB: " + antComPort + "...");
      
      boolean found = false;
      for (String p : Serial.list()) { if (p.equals(antComPort)) { found = true; break; } }
      
      if (!found) {
        addNotification("Porta " + antComPort + " non trovata", ERROR);
        return;
      }
      
      if (antSerial != null) { try { antSerial.stop(); } catch (Exception e) {} }
      antSerial = new Serial(this, antComPort, antBaudRate);
      antSerial.bufferUntil('\n');
      antConnected = true;
      addNotification("ESP32 Antenna connesso (USB)", SUCCESS);
      addDebugLog("ESP32 Antenna connesso via USB!");
      
    } else {
      // WiFi Mode
      addDebugLog("Connessione ESP32 Antenna via WiFi: " + antWifiIP + ":" + antWifiPort + "...");
      
      if (antClient != null) { try { antClient.stop(); } catch (Exception e) {} }
      antClient = new Client(this, antWifiIP, antWifiPort);
      
      if (antClient.active()) {
        antConnected = true;
        addNotification("ESP32 Antenna connesso (WiFi)", SUCCESS);
        addDebugLog("ESP32 Antenna connesso via WiFi!");
      } else {
        addNotification("Impossibile connettere a " + antWifiIP, ERROR);
        antClient = null;
      }
    }
    
    if (antConnected) {
      delay(100);
      sendAntennaCommand("PWR:" + (systemOn ? "1" : "0"));
    }
    
  } catch (Exception e) {
    addNotification("Errore connessione ESP32 Antenna", ERROR);
    addDebugLog("ERRORE: " + e.getMessage());
    antConnected = false;
    antSerial = null;
    antClient = null;
  }
}

void disconnectAntESP32() {
  addDebugLog("Disconnessione ESP32 Antenna...");
  
  try {
    if (antConnected) {
      sendAntennaCommand("PWR:0");
      delay(100);
    }
    
    if (antSerial != null) { antSerial.stop(); antSerial = null; }
    if (antClient != null) { antClient.stop(); antClient = null; }
    
    antConnected = false;
    selectedAntenna = -1;
    for (int i = 0; i < 6; i++) antennaStates[i] = false;
    
    addNotification("ESP32 Antenna disconnesso", WARNING);
    addDebugLog("ESP32 Antenna disconnesso");
    
  } catch (Exception e) {
    addDebugLog("ERRORE: " + e.getMessage());
    antSerial = null;
    antClient = null;
    antConnected = false;
  }
}

void sendAntennaCommand(String cmd) {
  if (!antConnected) return;
  
  try {
    if (antConnMode == 0 && antSerial != null) {
      antSerial.write(cmd + "\n");
      addDebugLog("TX ANT: " + cmd);
    } else if (antConnMode == 1 && antClient != null) {
      antClient.write(cmd + "\n");
      addDebugLog("TX ANT: " + cmd);
    }
  } catch (Exception e) {
    addDebugLog("ERRORE TX ANT: " + e.getMessage());
    antConnected = false;
  }
}

// ESP32 Rotator Functions
void connectRotESP32() {
  if (rotConnected) return;
  
  try {
    if (rotConnMode == 0) {
      // USB Mode
      addDebugLog("Connessione ESP32 Rotatore via USB: " + rotComPort + "...");
      
      boolean found = false;
      for (String p : Serial.list()) { if (p.equals(rotComPort)) { found = true; break; } }
      
      if (!found) {
        addNotification("Porta " + rotComPort + " non trovata", ERROR);
        return;
      }
      
      if (rotSerial != null) { try { rotSerial.stop(); } catch (Exception e) {} }
      rotSerial = new Serial(this, rotComPort, rotBaudRate);
      rotSerial.bufferUntil('\n');
      rotConnected = true;
      addNotification("ESP32 Rotatore connesso (USB)", SUCCESS);
      addDebugLog("ESP32 Rotatore connesso via USB!");
      
    } else {
      // WiFi HTTP Mode — test con GET /status
      addDebugLog("Test HTTP: http://" + rotWifiIP + ":" + rotWifiPort + "/status...");
      try {
        String url = "http://" + rotWifiIP + ":" + rotWifiPort + "/status";
        JSONObject statusJson = loadJSONObject(url);
        if (statusJson != null) {
          rotConnected = true;
          addNotification("ESP32 Rotatore connesso (HTTP)", SUCCESS);
          addDebugLog("ESP32 Rotatore connesso via HTTP!");
          parseRotatorStatusFromJson(statusJson);
        } else {
          addNotification("Impossibile connettere a " + rotWifiIP, ERROR);
          addDebugLog("Connessione HTTP fallita: risposta null");
        }
      } catch (Exception he) {
        addNotification("Impossibile connettere a " + rotWifiIP, ERROR);
        addDebugLog("ERRORE HTTP: " + he.getMessage());
      }
    }
    
    if (rotConnected && rotConnMode == 0) {
      delay(100);
      sendRotatorCommand("ROTATOR_PWR:" + (rotatorPowerOn ? "1" : "0"));
    }
    
  } catch (Exception e) {
    addNotification("Errore connessione ESP32 Rotatore", ERROR);
    addDebugLog("ERRORE: " + e.getMessage());
    rotConnected = false;
    rotSerial = null;
    rotClient = null;
  }
}

void disconnectRotESP32() {
  addDebugLog("Disconnessione ESP32 Rotatore...");
  
  try {
    if (rotConnected) {
      sendRotatorCommand("CW:0");
      sendRotatorCommand("CCW:0");
      sendRotatorCommand("BRAKE:0");
      sendRotatorCommand("ROTATOR_PWR:0");
      delay(100);
    }
    
    if (rotSerial != null) { rotSerial.stop(); rotSerial = null; }
    if (rotClient != null) { rotClient.stop(); rotClient = null; }
    
    rotConnected = false;
    rotatorCW = false;
    rotatorCCW = false;
    cwButtonPressed = false;
    ccwButtonPressed = false;
    brakeReleased = false;
    rotatorPowerOn = false;
    
    addNotification("ESP32 Rotatore disconnesso", WARNING);
    addDebugLog("ESP32 Rotatore disconnesso");
    
  } catch (Exception e) {
    addDebugLog("ERRORE: " + e.getMessage());
    rotSerial = null;
    rotClient = null;
    rotConnected = false;
  }
}

void sendRotatorCommand(String cmd) {
  if (!rotConnected) return;
  
  try {
    if (rotConnMode == 0 && rotSerial != null) {
      rotSerial.write(cmd + "\n");
      addDebugLog("TX ROT: " + cmd);
    } else if (rotConnMode == 1) {
      // WiFi HTTP: accoda e invia in thread separato
      synchronized(commandQueue) {
        commandQueue.add(cmd);
      }
      thread("sendHttpCommandThread");
    }
  } catch (Exception e) {
    addDebugLog("ERRORE TX ROT: " + e.getMessage());
    if (rotConnMode == 0) rotConnected = false;
  }
}

void sendHttpCommandThread() {
  String cmd = null;
  synchronized(commandQueue) {
    if (commandQueue.size() > 0) {
      cmd = commandQueue.remove(0);
    }
  }
  if (cmd == null) return;

  try {
    String encodedCmd = java.net.URLEncoder.encode(cmd, "UTF-8");
    String url = "http://" + rotWifiIP + ":" + rotWifiPort + "/command?cmd=" + encodedCmd;
    String[] response = loadStrings(url);
    if (response != null && response.length > 0) {
      httpCommandCount++;
      addDebugLog("TX ROT HTTP OK: " + cmd);
    } else {
      addDebugLog("TX ROT HTTP: nessuna risposta per " + cmd);
    }
  } catch (Exception e) {
    httpErrorCount++;
    addDebugLog("ERRORE TX ROT HTTP: " + e.getMessage());
    httpPollFailCount++;
    if (httpPollFailCount >= 10) {
      rotConnected = false;
      addNotification("Connessione rotore persa", ERROR);
    }
  }
}

// Process data from ESP32s
void processAntennaData(String data) {
  if (data.length() == 0) return;
  addDebugLog("RX ANT: " + data);
  
  if (data.startsWith("ANT:")) {
    try {
      int idx = Integer.parseInt(data.substring(4));
      if (idx >= -1 && idx < 6) {
        selectedAntenna = idx;
        for (int i = 0; i < 6; i++) antennaStates[i] = (i == idx);
      }
    } catch (Exception e) {}
  }
  else if (data.startsWith("STATUS:")) {
    // Handle status updates from antenna ESP32
  }
}

void processRotatorData(String data) {
  if (data.length() == 0) return;
  addDebugLog("RX ROT: " + data);
  
  if (data.startsWith("AZI:")) {
    try { 
      float rawAzi = Float.parseFloat(data.substring(4));
      // Apply EMA smoothing locally too
      currentAzimuth = smoothingFactor * rawAzi + (1.0 - smoothingFactor) * currentAzimuth;
      
      // Check if Go To target is reached
      if (goToActive && targetAzimuth >= 0) {
        float diff = abs(currentAzimuth - targetAzimuth);
        if (diff > 180) diff = 360 - diff;
        
        if (diff < 2.0) {
          goToActive = false;
          targetAzimuth = -1;
          goToTarget = -1;
          addDebugLog("GOTO: Target raggiunto!");
          addNotification("Target raggiunto!", SUCCESS);
        }
      }
    } catch (Exception e) {
      addDebugLog("ERRORE parsing AZI: " + data + " - " + e.getMessage());
    }
  }
  else if (data.startsWith("SMOOTH:")) {
    try { smoothingFactor = constrain(Float.parseFloat(data.substring(7)), 0.01, 1.0); } catch (Exception e) {}
  }
  else if (data.startsWith("RELAYCOMP:")) {
    try { relayCompensation = Float.parseFloat(data.substring(10)); } catch (Exception e) {}
  }
  else if (data.startsWith("ROTATOR:")) {
    String status = data.substring(8);
    if (status.equals("CW")) { rotatorCW = true; rotatorCCW = false; }
    else if (status.equals("CCW")) { rotatorCW = false; rotatorCCW = true; }
    else { rotatorCW = false; rotatorCCW = false; cwButtonPressed = false; ccwButtonPressed = false; }
  }
  else if (data.startsWith("ROTATOR_PWR:")) {
    rotatorPowerOn = data.substring(12).equals("ON");
  }
  else if (data.startsWith("GOTO:DONE")) {
    goToActive = false;
    goToTarget = -1;
    addNotification("GOTO completato!", SUCCESS);
  }
  else if (data.startsWith("STATUS:") && (data.contains("stopped") || data.contains("halt") || data.contains("timeout"))) {
    rotatorCW = false;
    rotatorCCW = false;
    cwButtonPressed = false;
    ccwButtonPressed = false;
    if (goToActive) {
      goToActive = false;
      goToTarget = -1;
    }
  }
  else if (data.startsWith("STATUS:")) {
    // Handle other status updates from rotator ESP32
  }
}

void serialEvent(Serial p) {
  try {
    String data = p.readStringUntil('\n');
    if (data == null || data.length() == 0) return;
    data = data.trim();
    
    if (p == antSerial) {
      processAntennaData(data);
    } else if (p == rotSerial) {
      processRotatorData(data);
    }
  } catch (Exception e) {
    addDebugLog("ERRORE serialEvent: " + e.getMessage());
  }
}

// HTTP polling thread for WiFi rotator mode
void pollRotatorStatusThread() {
  try {
    String url = "http://" + rotWifiIP + ":" + rotWifiPort + "/status";
    JSONObject json = loadJSONObject(url);
    if (json != null) {
      parseRotatorStatusFromJson(json);
      httpPollFailCount = 0;
    } else {
      httpPollFailCount++;
      if (httpPollFailCount >= 5) {
        rotConnected = false;
        httpPollFailCount = 0;
      }
    }
  } catch (Exception e) {
    httpPollFailCount++;
    if (httpPollFailCount >= 5) {
      rotConnected = false;
      httpPollFailCount = 0;
    }
  }
}

void parseRotatorStatusFromJson(JSONObject d) {
  try {
    float azi = d.getFloat("displayAzi", currentAzimuth);
    currentAzimuth = smoothingFactor * azi + (1.0 - smoothingFactor) * currentAzimuth;
    
    if (d.hasKey("rawAzi")) rawAzimuth = d.getFloat("rawAzi");
    
    rotatorCW  = d.getBoolean("cw");
    rotatorCCW = d.getBoolean("ccw");
    rotatorPowerOn = d.getBoolean("power");
    brakeReleased  = d.getBoolean("brake");
    goToActive     = d.getBoolean("goTo");
    overlapActive  = d.getBoolean("overlap");
    if (goToActive) goToTarget = d.getFloat("target", goToTarget);
    
    // Sincronizza stato pulsanti CW/CCW con stato reale dei relè
    cwButtonPressed  = rotatorCW;
    ccwButtonPressed = rotatorCCW;
    
    if (d.hasKey("smooth"))     smoothingFactor   = constrain(d.getFloat("smooth"),    0.01, 1.0);
    if (d.hasKey("relayComp"))  relayCompensation = d.getFloat("relayComp");
    if (d.hasKey("brakeDelay")) brakeDelayMs       = constrain(d.getInt("brakeDelay"), brakeDelayMin, brakeDelayMax);
    
    // Check GOTO completion
    if (goToActive && targetAzimuth >= 0) {
      float diff = abs(currentAzimuth - targetAzimuth);
      if (diff > 180) diff = 360 - diff;
      if (diff < 2.0) {
        goToActive = false;
        targetAzimuth = -1;
        goToTarget = -1;
        addDebugLog("GOTO: Target raggiunto!");
        addNotification("Target raggiunto!", SUCCESS);
      }
    }
  } catch (Exception e) {
    addDebugLog("Errore parsing HTTP status: " + e.getMessage());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAPPA IMMAGINE NEL QUADRANTE
// ═══════════════════════════════════════════════════════════════════════════

void loadMapImage(String path) {
  // PDF is not natively supported by Processing - inform user
  if (path.toLowerCase().endsWith(".pdf")) {
    addNotification("PDF non supportato: usa PNG/JPG", WARNING);
    addDebugLog("NOTA: Processing non supporta PDF nativamente.");
    addDebugLog("  Scarica la mappa da ns6t.net/azimuth/azimuth.html,");
    addDebugLog("  poi converti il PDF in PNG/JPG con un tool esterno");
    addDebugLog("  (es. Adobe Reader, Preview, ImageMagick) prima di importare.");
    return;
  }
  
  try {
    PImage img = loadImage(path);
    if (img == null || img.width <= 0 || img.height <= 0) {
      addDebugLog("Errore caricamento mappa: " + path);
      addNotification("Errore caricamento mappa", ERROR);
      return;
    }
    
    // Store original source image (unmasked) for zoom/offset rebuilding
    sourceMapImage = img;
    mapImagePath = path;
    
    // Build the masked (clipped) image with current zoom/offset
    rebuildMaskedMap();
    
    settings.saveSettings();
    addDebugLog("Mappa caricata: " + path);
    addNotification("Mappa caricata", SUCCESS);
  } catch (Exception e) {
    addDebugLog("Errore mappa: " + e.getMessage());
    addNotification("Errore caricamento mappa", ERROR);
  }
}

void rebuildMaskedMap() {
  if (sourceMapImage == null) return;
  
  int size = int(mapRadius * 2);
  
  // Draw source image with zoom and offset into an off-screen buffer
  PGraphics g = createGraphics(size, size);
  g.beginDraw();
  g.background(0, 0);  // transparent background
  g.imageMode(CENTER);
  // Keep aspect ratio: scale proportionally to fill the circle
  float aspect = (float)sourceMapImage.width / (float)sourceMapImage.height;
  float drawW, drawH;
  if (aspect >= 1.0) {
    drawW = size * mapZoom;
    drawH = size * mapZoom / aspect;
  } else {
    drawH = size * mapZoom;
    drawW = size * mapZoom * aspect;
  }
  g.image(sourceMapImage, size / 2.0 + mapOffsetX, size / 2.0 + mapOffsetY, drawW, drawH);
  g.endDraw();
  
  // Apply circular mask so the image is clipped inside the compass circle
  PImage masked = g.get();
  PGraphics maskG = createGraphics(size, size);
  maskG.beginDraw();
  maskG.background(0);
  maskG.fill(255);
  maskG.noStroke();
  maskG.ellipse(size / 2.0, size / 2.0, size, size);
  maskG.endDraw();
  masked.mask(maskG);
  
  maskedMapImage = masked;
}

void mapImageSelected(File selection) {
  if (selection != null) {
    loadMapImage(selection.getAbsolutePath());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EXIT
// ═══════════════════════════════════════════════════════════════════════════

void exit() {
  addDebugLog("Chiusura...");
  
  try {
    if (disconnectRelaysOnExit) {
      // Send ALL OFF commands only when the toggle is enabled
      if (antConnected) {
        sendAntennaCommand("ALLOFF");
        addDebugLog("TX ANT: ALLOFF (disconnectRelaysOnExit=true)");
        delay(100);
      }
      if (rotConnected) {
        sendRotatorCommand("CW:0");
        sendRotatorCommand("CCW:0");
        sendRotatorCommand("ROTATOR_PWR:0");
        delay(100);
      }
    } else {
      // Do NOT send OFF commands - leave relays in current state
      addDebugLog("Relè lasciati attivi (disconnectRelaysOnExit=false)");
    }
    
    if (sendHaltOnExit && rotConnected) {
      sendRotatorCommand("HALT:1");
      addDebugLog("TX ROT: HALT:1");
      delay(100);
    }
    
    if (rememberLastAntenna) {
      lastSelectedAntenna = selectedAntenna;
    }
    
    settings.saveSettings();
    
    // Close serial/network connections without sending additional OFF commands
    try {
      if (antSerial != null) { antSerial.stop(); antSerial = null; }
      if (antClient != null) { antClient.stop(); antClient = null; }
      antConnected = false;
    } catch (Exception e) {}
    try {
      if (rotSerial != null) { rotSerial.stop(); rotSerial = null; }
      if (rotClient != null) { rotClient.stop(); rotClient = null; }
      rotConnected = false;
    } catch (Exception e) {}
    
    delay(150);
  } catch (Exception e) {}
  
  super.exit();
}
