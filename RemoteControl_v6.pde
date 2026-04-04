// ============================================================
//  RemoteControl_v6.pde
//  Processing 4 — ESP32 Antenna-Switch + Rotator Remote Control
//  All float literals carry 'f' suffix; all alpha params cast to (int)
// ============================================================

import processing.serial.*;
import processing.net.*;
import processing.data.JSONObject;
import processing.data.JSONArray;
import java.io.*;
import java.util.ArrayList;

// ─── 1. CONSTANTS ───────────────────────────────────────────
final int NTFY_OK  = 0;
final int NTFY_ERR = 1;
final int NTFY_WRN = 2;
final int NTFY_INF = 3;

final int SCR_CTRL = 0;
final int SCR_SET  = 1;
final int SCR_DBG  = 2;

final int EXIT_ALL_OFF  = 0;
final int EXIT_SAVE_POS = 1;
final int EXIT_FIXED    = 2;

// ─── 2. THEME ───────────────────────────────────────────────
class Theme {
  color bg       = #1A1A2E;
  color panel    = #16213E;
  color card     = #0F3460;
  color accent   = #00FF88;
  color accent2  = #00BFFF;
  color warn     = #FF9900;
  color err      = #FF4444;
  color ok       = #00CC66;
  color txt      = #E0E0E0;
  color txtDim   = #888888;
  color brdr     = #2A3A5A;
  color btnAct   = #00FF88;
  color btnInact = #1E3050;
  color topBar   = #0A0A1A;
  color navBg    = #0D1B2E;
  color sliderTk = #2A4A6A;
  color sliderFl = #00FF88;
  color gridCol  = #1A3050;
  color needleC  = #FFD700;
  color beamC    = #00FF8840;
  color targetC  = #FF6600;
}
Theme T = new Theme();

// ─── 3. NOTIFICATION SYSTEM ─────────────────────────────────
class Notif {
  String msg;
  int type;
  int born;
  float life = 5000f;
  float alpha = 0f;
  Notif(String m, int t) { msg = m; type = t; born = millis(); }
  float progress() { return constrain((millis()-born)/life, 0f, 1f); }
  boolean dead()   { return millis()-born > life+400; }
  color col() {
    if(type==NTFY_OK)  return T.ok;
    if(type==NTFY_ERR) return T.err;
    if(type==NTFY_WRN) return T.warn;
    return T.accent2;
  }
}
ArrayList<Notif> notifs = new ArrayList<Notif>();

void N(String m, int t) { notifs.add(new Notif(m, t)); dlog("[NOTIF] " + m); }

void drawNotifs() {
  for(int i = notifs.size()-1; i >= 0; i--) {
    Notif n = notifs.get(i);
    if(n.dead()) { notifs.remove(i); continue; }
    float age = millis() - n.born;
    if(age < 300f) n.alpha = lerp(n.alpha, 255f, 0.25f);
    else if(age > n.life) n.alpha = lerp(n.alpha, 0f, 0.15f);
    else n.alpha = lerp(n.alpha, 255f, 0.15f);

    float nx = width - 320f;
    float ny = height - 60f - i*70f;
    noStroke();
    fill(n.col(), (int)(n.alpha * 0.15f));
    rect(nx, ny, 300f, 54f, 8f);
    stroke(n.col(), (int)(n.alpha));
    strokeWeight(1.5f);
    noFill();
    rect(nx, ny, 300f, 54f, 8f);
    noStroke();
    fill(n.col(), (int)(n.alpha));
    rect(nx, ny+50f, 300f*(1f-n.progress()), 4f, 0f, 0f, 4f, 4f);
    fill(T.txt, (int)(n.alpha));
    textAlign(LEFT, CENTER);
    textSize(13f);
    text(n.msg, nx+12f, ny+22f);
    strokeWeight(1f);
  }
}

// ─── 4. SETTINGS MANAGER ────────────────────────────────────

class SM {
  JSONObject j;
  String path;
  SM(String p) {
    path = p;
    j = new JSONObject();
    load();
  }
  void load() {
    try {
      File f = new File(path);
      if(f.exists()) j = loadJSONObject(path);
      else defaults();
    } catch(Exception e) { defaults(); }
  }
  void save() {
    try { saveJSONObject(j, path); } catch(Exception e) { dlog("Save cfg err: "+e.getMessage()); }
  }
  void defaults() {
    j = new JSONObject();
    j.setString("ant0","DxCommander");  j.setString("ant1","3El 10-15-20");
    j.setString("ant2","Delta Loop 11m"); j.setString("ant3","9el V/UHF");
    j.setString("ant4","Dipolo 80");    j.setString("ant5","Dipolo 40");
    j.setInt("antDir0",0); j.setInt("antDir1",135); j.setInt("antDir2",270);
    j.setInt("antDir3",45); j.setInt("antDir4",0); j.setInt("antDir5",0);
    j.setInt("antMode",0); j.setString("antPort","COM4"); j.setInt("antBaud",9600);
    j.setString("antIP","192.168.1.100"); j.setInt("antWPort",8080);
    j.setInt("rotMode",0); j.setString("rotPort","COM5"); j.setInt("rotBaud",9600);
    j.setString("rotIP","192.168.1.101"); j.setInt("rotWPort",8081);
    j.setBoolean("autoConn",false);
    j.setInt("brakeMs",500); j.setBoolean("hasBrake",true);
    j.setFloat("beamW",60f); j.setFloat("mapOpacity",0.7f);
    j.setFloat("mapRotOffset",0f);
    j.setBoolean("showGrid",true); j.setBoolean("showCardinals",true);
    j.setBoolean("showBeam",true);
    j.setString("mapPath","");
    j.setInt("exitMode",0); j.setFloat("fixedAz",0f);
    j.setInt("theme",0);
  }
  String  gs(String k, String d)  { try { return j.getString(k); } catch(Exception e) { return d; } }
  int     gi(String k, int d)     { try { return j.getInt(k);    } catch(Exception e) { return d; } }
  float   gf(String k, float d)   { try { return j.getFloat(k);  } catch(Exception e) { return d; } }
  boolean gb(String k, boolean d) { try { return j.getBoolean(k);} catch(Exception e) { return d; } }
  void ss(String k, String v)  { j.setString(k,v);  }
  void si(String k, int v)     { j.setInt(k,v);     }
  void sf(String k, float v)   { j.setFloat(k,v);   }
  void sb(String k, boolean v) { j.setBoolean(k,v); }
}
SM cfg;

// ─── 5. GLOBAL VARIABLES ─────────────────────────────────────

// Antenna names/pins/states/dirs
String[] antNames  = new String[6];
int[]    antPins   = {1,2,3,4,5,6};
boolean[] antStates= new boolean[6];
int[]    antDir    = new int[6];

// ANT connection
Serial antSerial;
Client antClient;
boolean antConn = false;
int     antMode = 0;   // 0=USB, 1=WiFi
String  antPort = "COM4";
int     antBaud = 9600;
String  antIP   = "192.168.1.100";
int     antWPort = 8080;
String  antBuf  = "";
int     antLastPoll = 0;

// ROT connection
Serial rotSerial;
Client rotClient;
boolean rotConn = false;
int     rotMode = 0;   // 0=USB, 1=WiFi
String  rotPort = "COM5";
int     rotBaud = 9600;
String  rotIP   = "192.168.1.101";
int     rotWPort = 8081;
String  rotBuf  = "";
int     rotLastPoll = 0;

// Rotator state
boolean rotPwr   = false;
boolean rotCW    = false;
boolean rotCCW   = false;
boolean brakeRel = false;
int     brakeMs  = 500;
boolean hasBrake = true;
float   curAz    = 180f;
float   dispAz   = 180f;
float   targetAz = -1f;
boolean gotoActive = false;

// Map
PImage  mapImg      = null;
String  mapPath     = "";
float   mapOpacity  = 0.7f;
float   beamW       = 60f;
boolean showGrid    = true;
boolean showCardinals = true;
boolean showBeam    = true;
float   mapRotOffset = 0f;
int     selAnt      = -1;

// Exit
int   exitMode = 0;
float fixedAz  = 0f;

// UI state
int   curScr    = SCR_CTRL;
int   setTab    = 0;       // 0=Ant,1=Conn,2=Sys,3=App
boolean editF   = false;
String  inBuf   = "";
String  editKey = "";
float   setScrollY = 0f;
float   setScrollTarget = 0f;
boolean autoConn = false;

// Animation
float navAnim  = 0f;
int   lastScr  = SCR_CTRL;
float scrAnim  = 0f;

// Drag state for sliders
boolean brakeDrag = false;
boolean beamDrag  = false;
boolean mapOpDrag = false;
float   dragStartX = 0f;
float   dragStartV = 0f;

// Serial port list
String[] availPorts = new String[0];

// Debug log
ArrayList<String> logLines = new ArrayList<String>();
int  logScroll = 0;

// Layout constants (computed in draw)
float ctrlSplit = 0f;  // x split between antenna panel and rotator panel
float mapCX = 0f, mapCY = 0f, mapR = 0f;

// ─── 6. SETUP ────────────────────────────────────────────────
void setup() {
  size(1024, 700);
  surface.setResizable(true);
  surface.setTitle("RemoteControl v6 — ESP32 Antenna+Rotor");
  smooth(4);
  frameRate(60);

  cfg = new SM(sketchPath("config.json"));
  loadFromCfg();

  availPorts = Serial.list();
  dlog("Processing " + System.getProperty("java.version") + " — " + availPorts.length + " serial ports found");

  if(autoConn) thread("autoConnThread");
}

void loadFromCfg() {
  for(int i=0;i<6;i++) antNames[i] = cfg.gs("ant"+i,"Antenna "+(i+1));
  for(int i=0;i<6;i++) antDir[i]   = cfg.gi("antDir"+i,0);
  antMode  = cfg.gi("antMode",0); antPort = cfg.gs("antPort","COM4");
  antBaud  = cfg.gi("antBaud",9600); antIP = cfg.gs("antIP","192.168.1.100");
  antWPort = cfg.gi("antWPort",8080);
  rotMode  = cfg.gi("rotMode",0); rotPort = cfg.gs("rotPort","COM5");
  rotBaud  = cfg.gi("rotBaud",9600); rotIP = cfg.gs("rotIP","192.168.1.101");
  rotWPort = cfg.gi("rotWPort",8081);
  autoConn = cfg.gb("autoConn",false);
  brakeMs  = cfg.gi("brakeMs",500); hasBrake = cfg.gb("hasBrake",true);
  beamW    = cfg.gf("beamW",60f); mapOpacity = cfg.gf("mapOpacity",0.7f);
  mapRotOffset = cfg.gf("mapRotOffset",0f);
  showGrid     = cfg.gb("showGrid",true); showCardinals = cfg.gb("showCardinals",true);
  showBeam     = cfg.gb("showBeam",true);
  mapPath      = cfg.gs("mapPath","");
  exitMode     = cfg.gi("exitMode",0); fixedAz = cfg.gf("fixedAz",0f);
  if(mapPath.length() > 0) {
    try { mapImg = loadImage(mapPath); } catch(Exception e) { mapImg = null; }
  }
}

void saveToCfg() {
  for(int i=0;i<6;i++) cfg.ss("ant"+i, antNames[i]);
  for(int i=0;i<6;i++) cfg.si("antDir"+i, antDir[i]);
  cfg.si("antMode",antMode); cfg.ss("antPort",antPort);
  cfg.si("antBaud",antBaud); cfg.ss("antIP",antIP); cfg.si("antWPort",antWPort);
  cfg.si("rotMode",rotMode); cfg.ss("rotPort",rotPort);
  cfg.si("rotBaud",rotBaud); cfg.ss("rotIP",rotIP); cfg.si("rotWPort",rotWPort);
  cfg.sb("autoConn",autoConn);
  cfg.si("brakeMs",brakeMs); cfg.sb("hasBrake",hasBrake);
  cfg.sf("beamW",beamW); cfg.sf("mapOpacity",mapOpacity);
  cfg.sf("mapRotOffset",mapRotOffset);
  cfg.sb("showGrid",showGrid); cfg.sb("showCardinals",showCardinals);
  cfg.sb("showBeam",showBeam);
  cfg.ss("mapPath",mapPath);
  cfg.si("exitMode",exitMode); cfg.sf("fixedAz",fixedAz);
}

// ─── 7. DRAW ─────────────────────────────────────────────────
void draw() {
  background(T.bg);

  // Layout
  float topH = 44f;
  float navH = 48f;
  float botH = 0f;
  ctrlSplit = width * 0.42f;

  // Poll ESP32 every 500ms
  if(millis() - antLastPoll > 500) { antLastPoll = millis(); pollAnt(); }
  if(millis() - rotLastPoll > 500) { rotLastPoll = millis(); pollRot(); }
  processSerial();

  // Animate azimuth display
  dispAz = lerp(dispAz, curAz, 0.05f);

  // Map circle layout (right panel of control screen)
  float rightX = ctrlSplit;
  float rightW = width - ctrlSplit;
  float availH = height - topH - navH - 200f; // 200 for buttons+slider
  mapR  = min(rightW * 0.42f, availH * 0.48f);
  mapCX = rightX + rightW/2f;
  mapCY = topH + availH/2f + 10f;

  drawTopBar(topH);

  // Screen content
  if(curScr == SCR_CTRL) drawControl(topH, navH);
  else if(curScr == SCR_SET) drawSettings(topH, navH);
  else drawDebug(topH, navH);

  drawNavBar(height - navH, navH);
  drawNotifs();

  // Animated screen cursor restore
  textAlign(LEFT, BASELINE);
}

// ─── 8. DRAW CONTROL ─────────────────────────────────────────
void drawControl(float topH, float navH) {
  float contentH = height - topH - navH;

  // ── Left panel: Antenna switch ──────────────────────────────
  float lx = 0f, ly = topH, lw = ctrlSplit, lh = contentH;

  fill(T.panel);
  noStroke();
  rect(lx, ly, lw, lh);

  // Panel title
  fill(T.accent);
  textSize(11f);
  textAlign(LEFT, TOP);
  text("ANTENNA SWITCH", lx+14f, ly+10f);

  // Connection status strip
  drawConnStatus(lx+14f, ly+28f, lw-28f, 18f, "ANT", antConn);

  // 6 antenna buttons
  float btnW = (lw - 28f) / 2f - 6f;
  float btnH = 52f;
  float bx0  = lx + 14f;
  float bx1  = bx0 + btnW + 12f;
  float by0  = ly + 56f;
  float gap  = 10f;
  for(int i=0; i<6; i++) {
    float bx = (i%2==0) ? bx0 : bx1;
    float by = by0 + (i/2)*(btnH+gap);
    drawAntBtn(i, bx, by, btnW, btnH);
  }

  // ── Right panel: Rotator ────────────────────────────────────
  float rx = ctrlSplit, ry = topH, rw = width - ctrlSplit, rh = contentH;

  fill(T.panel);
  noStroke();
  rect(rx, ry, rw, rh);

  // Panel title + ROT status
  fill(T.accent2);
  textSize(11f);
  textAlign(LEFT, TOP);
  text("ROTATORE", rx+14f, ry+10f);
  drawConnStatus(rx+14f, ry+28f, rw-28f, 18f, "ROT", rotConn);

  // Azimuth heading display
  fill(T.txt);
  textSize(28f);
  textAlign(CENTER, TOP);
  text(nf(dispAz,1,1)+"°", mapCX, ry+50f);

  // Target indicator
  if(gotoActive && targetAz >= 0f) {
    fill(T.targetC);
    textSize(11f);
    textAlign(CENTER, TOP);
    text("→ GOTO "+nf(targetAz,1,1)+"°", mapCX, ry+82f);
  }

  // Power & ROT status
  drawRotPwrBtn(rx+14f, ry+50f, 60f, 30f);

  // Azimuth map
  drawAzMap();

  // Rotation buttons
  float btnAreaY = mapCY + mapR + 18f;
  drawRotBtns(rx, rw, btnAreaY);

  // Brake slider
  float sliderY = btnAreaY + 60f;
  drawBrakeSlider(rx + 14f, sliderY, rw - 28f, 44f);
}

void drawAntBtn(int idx, float x, float y, float w, float h) {
  boolean sel  = (selAnt == idx);
  boolean act  = antStates[idx];
  color   bgC  = sel ? T.accent : (act ? T.card : T.btnInact);
  color   txtC = sel ? T.bg : (act ? T.accent : T.txt);

  // Shadow
  noStroke();
  fill(0, 60);
  rect(x+2f, y+2f, w, h, 10f);

  // Body
  fill(bgC);
  if(sel) { stroke(T.accent); strokeWeight(2f); }
  else    { stroke(T.brdr);   strokeWeight(1f); }
  rect(x, y, w, h, 10f);
  noStroke();

  // Active LED
  if(act) {
    fill(T.ok);
    ellipse(x+12f, y+h/2f, 8f, 8f);
  }

  // Antenna number badge
  fill(sel ? T.bg : T.txtDim);
  textSize(9f);
  textAlign(LEFT, TOP);
  text((idx+1)+"", x+6f, y+5f);

  // Name
  fill(txtC);
  textSize(12f);
  textAlign(CENTER, CENTER);
  text(antNames[idx], x+w/2f+8f, y+h/2f - 6f);

  // Direction badge
  if(antDir[idx] > 0) {
    fill(sel ? T.bg : T.accent2);
    textSize(9f);
    textAlign(CENTER, CENTER);
    text(antDir[idx]+"°", x+w/2f+8f, y+h/2f + 9f);
  }
  strokeWeight(1f);
}

void drawConnStatus(float x, float y, float w, float h, String label, boolean conn) {
  color c = conn ? T.ok : T.err;
  noStroke();
  fill(c, 30);
  rect(x, y, w, h, 4f);
  fill(c);
  ellipse(x+10f, y+h/2f, 7f, 7f);
  textSize(10f);
  textAlign(LEFT, CENTER);
  text(label + (conn ? "  CONNESSO" : "  DISCONNESSO"), x+20f, y+h/2f);
  textAlign(LEFT, BASELINE);
}

void drawRotPwrBtn(float x, float y, float w, float h) {
  color c = rotPwr ? T.ok : T.err;
  fill(c, 40);
  stroke(c);
  strokeWeight(1.5f);
  rect(x, y, w, h, 6f);
  noStroke();
  fill(c);
  textSize(10f);
  textAlign(CENTER, CENTER);
  text(rotPwr ? "PWR ON" : "PWR OFF", x+w/2f, y+h/2f);
  strokeWeight(1f);
}

// ─── 9. DRAW AZIMUTH MAP ─────────────────────────────────────
void drawAzMap() {
  pushMatrix();
  translate(mapCX, mapCY);

  // Clip circle background
  noStroke();
  fill(T.bg);
  ellipse(0f, 0f, mapR*2f, mapR*2f);

  // Optional background map image
  if(mapImg != null) {
    tint(255, (int)(mapOpacity * 255f));
    imageMode(CENTER);
    image(mapImg, 0f, 0f, mapR*2f, mapR*2f);
    noTint();
  }

  // Grid circles
  if(showGrid) {
    noFill();
    stroke(T.gridCol);
    strokeWeight(0.8f);
    for(int ring=1; ring<=4; ring++) {
      float rr = mapR * ring / 4f;
      ellipse(0f, 0f, rr*2f, rr*2f);
    }
  }

  // Degree ticks + labels
  for(int deg=0; deg<360; deg+=5) {
    float rad = radians(deg - 90f + mapRotOffset);
    float len = (deg%30==0) ? mapR*0.08f : mapR*0.04f;
    float r1  = mapR - len;
    float r2  = mapR;
    stroke(T.txt, (int)(deg%30==0 ? 180 : 80));
    strokeWeight(deg%30==0 ? 1.2f : 0.6f);
    line(cos(rad)*r1, sin(rad)*r1, cos(rad)*r2, sin(rad)*r2);
    if(deg%30==0) {
      fill(T.txtDim);
      noStroke();
      textSize(9f);
      textAlign(CENTER, CENTER);
      float lr = mapR + 12f;
      text(deg+"°", cos(rad)*lr, sin(rad)*lr);
    }
  }

  // Cardinal labels
  if(showCardinals) {
    String[] cards = {"N","NE","E","SE","S","SO","O","NO"};
    int[]    degs  = {0,45,90,135,180,225,270,315};
    for(int i=0; i<8; i++) {
      float rad = radians(degs[i] - 90f + mapRotOffset);
      float lr  = mapR - 20f;
      fill(i==0 ? T.err : T.txt);
      textSize(i==0 ? 12f : 10f);
      textAlign(CENTER, CENTER);
      text(cards[i], cos(rad)*lr, sin(rad)*lr);
    }
  }

  // Directional beam (arc)
  if(showBeam && selAnt>=0 && selAnt<6 && antDir[selAnt]>0) {
    float bRad = radians(antDir[selAnt] - 90f + mapRotOffset);
    float hw   = radians(beamW/2f);
    fill(T.beamC);
    noStroke();
    arc(0f, 0f, (mapR-2f)*2f, (mapR-2f)*2f, bRad-hw, bRad+hw, PIE);
  }

  // Target GOTO dashed line
  if(gotoActive && targetAz >= 0f) {
    float tRad = radians(targetAz - 90f + mapRotOffset);
    stroke(T.targetC, 200);
    strokeWeight(1.5f);
    drawDashedLine(0f, 0f, cos(tRad)*(mapR-4f), sin(tRad)*(mapR-4f), 8f, 4f);
    // Arrow tip
    fill(T.targetC);
    noStroke();
    float ax = cos(tRad)*(mapR-4f);
    float ay = sin(tRad)*(mapR-4f);
    triangle(ax-5f*cos(tRad+HALF_PI), ay-5f*sin(tRad+HALF_PI),
             ax-5f*cos(tRad-HALF_PI), ay-5f*sin(tRad-HALF_PI),
             ax+10f*cos(tRad), ay+10f*sin(tRad));
  }

  // Azimuth needle
  float needRad = radians(dispAz - 90f + mapRotOffset);
  // Shadow
  stroke(0, 100);
  strokeWeight(4f);
  line(0f, 0f, cos(needRad)*(mapR*0.8f)+2f, sin(needRad)*(mapR*0.8f)+2f);
  // Needle body
  stroke(T.needleC);
  strokeWeight(2.5f);
  line(0f, 0f, cos(needRad)*(mapR*0.8f), sin(needRad)*(mapR*0.8f));
  // Triangle tip
  float tx1 = cos(needRad)*(mapR*0.8f);
  float ty1 = sin(needRad)*(mapR*0.8f);
  noStroke();
  fill(T.needleC);
  triangle(tx1-5f*cos(needRad+HALF_PI), ty1-5f*sin(needRad+HALF_PI),
           tx1-5f*cos(needRad-HALF_PI), ty1-5f*sin(needRad-HALF_PI),
           tx1+12f*cos(needRad), ty1+12f*sin(needRad));
  // Center dot
  fill(T.needleC);
  ellipse(0f, 0f, 10f, 10f);
  fill(T.bg);
  ellipse(0f, 0f, 5f, 5f);

  // Azimuth text on map
  fill(T.txt, 200);
  textSize(13f);
  textAlign(CENTER, CENTER);
  text(nf(dispAz,1,1)+"°", 0f, mapR*0.55f);

  // Clip circle border
  noFill();
  stroke(T.brdr);
  strokeWeight(2f);
  ellipse(0f, 0f, mapR*2f, mapR*2f);

  strokeWeight(1f);
  popMatrix();
}

void drawDashedLine(float x1, float y1, float x2, float y2, float dash, float gap) {
  float dx = x2-x1, dy = y2-y1;
  float len = sqrt(dx*dx + dy*dy);
  float nx = dx/len, ny = dy/len;
  float pos = 0f;
  while(pos < len) {
    float end = min(pos+dash, len);
    line(x1+nx*pos, y1+ny*pos, x1+nx*end, y1+ny*end);
    pos += dash+gap;
  }
}

// ─── 10. DRAW ROT BUTTONS ────────────────────────────────────
void drawRotBtns(float px, float pw, float btnY) {
  int   nBt  = hasBrake ? 4 : 3;
  float btnW = min(78f, (pw - 28f) / nBt - 8f);
  float btnH = 46f;
  float gap  = 8f;
  float totW = nBt*btnW + (nBt-1)*gap;
  float sX   = mapCX - totW/2f;

  String[] labels = hasBrake ? new String[]{"◄◄ CCW","HALT","BRAKE","CW ►►"}
                              : new String[]{"◄◄ CCW","HALT","CW ►►"};
  color[]  cols   = hasBrake ? new color[]{T.accent2, T.warn, T.err, T.accent}
                              : new color[]{T.accent2, T.warn, T.accent};
  boolean[] active = hasBrake ? new boolean[]{rotCCW, false, brakeRel, rotCW}
                               : new boolean[]{rotCCW, false, rotCW};

  for(int i=0; i<nBt; i++) {
    float bx = sX + i*(btnW+gap);
    boolean act = active[i];
    color c = cols[i];

    // Button body
    noStroke();
    fill(act ? c : T.btnInact);
    stroke(c);
    strokeWeight(act ? 2f : 1f);
    rect(bx, btnY, btnW, btnH, 8f);

    // Label
    fill(act ? T.bg : c);
    textSize(11f);
    textAlign(CENTER, CENTER);
    text(labels[i], bx+btnW/2f, btnY+btnH/2f);
  }
  noStroke();
  strokeWeight(1f);
}

// ─── 11. DRAW BRAKE SLIDER ───────────────────────────────────
void drawBrakeSlider(float x, float y, float w, float h) {
  float trackY = y + h/2f - 3f;
  float trackH = 6f;
  float knobR  = 10f;

  // Label
  fill(T.txtDim);
  textSize(10f);
  textAlign(LEFT, CENTER);
  text("BRAKE DELAY", x, y+trackH/2f-8f);
  textAlign(RIGHT, CENTER);
  text(brakeMs + " ms", x+w, y+trackH/2f-8f);

  // Track background
  noStroke();
  fill(T.sliderTk);
  rect(x, trackY, w, trackH, 3f);

  // Track fill
  float frac = brakeMs / 1000f;
  fill(T.sliderFl);
  rect(x, trackY, w * frac, trackH, 3f);

  // Tick marks every 100ms
  for(int t=0; t<=10; t++) {
    float tx = x + w * (t/10f);
    float tickH = (t%5==0) ? 10f : 6f;
    stroke(T.txt, t%5==0 ? 180 : 80);
    strokeWeight(1f);
    line(tx, trackY-tickH/2f, tx, trackY+trackH+tickH/2f);
    if(t==0 || t==5 || t==10) {
      noStroke();
      fill(T.txtDim);
      textSize(8f);
      textAlign(CENTER, TOP);
      String lbl = t==0 ? "0" : (t==5 ? "500ms" : "1s");
      text(lbl, tx, trackY+trackH+4f);
    }
  }

  // Knob
  float kx = x + w * frac;
  noStroke();
  fill(0, 80);
  ellipse(kx+1f, trackY+trackH/2f+1f, knobR*2f, knobR*2f);
  fill(brakeDrag ? T.accent : T.sliderFl);
  ellipse(kx, trackY+trackH/2f, knobR*2f, knobR*2f);
  fill(T.bg);
  ellipse(kx, trackY+trackH/2f, knobR*0.8f, knobR*0.8f);

  // Tooltip
  if(brakeDrag) {
    fill(T.card);
    stroke(T.accent);
    strokeWeight(1f);
    rect(kx-22f, trackY-28f, 44f, 18f, 4f);
    noStroke();
    fill(T.accent);
    textSize(9f);
    textAlign(CENTER, CENTER);
    text(brakeMs+"ms", kx, trackY-19f);
  }
  strokeWeight(1f);
  textAlign(LEFT, BASELINE);
}

// ─── 12. DRAW SETTINGS ───────────────────────────────────────
void drawSettings(float topH, float navH) {
  float x = 0f, y = topH, w = width, h = height-topH-navH;

  fill(T.bg);
  noStroke();
  rect(x, y, w, h);

  // Tab bar
  String[] tabs = {"Antenne","Connessione","Sistema","Aspetto"};
  float tabW = w / tabs.length;
  for(int i=0; i<tabs.length; i++) {
    boolean sel = (setTab==i);
    fill(sel ? T.card : T.panel);
    noStroke();
    rect(x+i*tabW, y, tabW, 36f);
    fill(sel ? T.accent : T.txtDim);
    textSize(12f);
    textAlign(CENTER, CENTER);
    text(tabs[i], x+i*tabW+tabW/2f, y+18f);
    if(sel) {
      fill(T.accent);
      rect(x+i*tabW, y+33f, tabW, 3f);
    }
  }
  // Divider
  stroke(T.brdr);
  strokeWeight(1f);
  line(x, y+36f, x+w, y+36f);
  noStroke();

  float contentY = y+40f;
  float contentH = h-40f;

  // Scrollable content area (clip simulation)
  float sy = contentY + setScrollY;

  if(setTab==0) drawSetAnt(x, sy, w, contentH);
  else if(setTab==1) drawSetConn(x, sy, w, contentH);
  else if(setTab==2) drawSetSys(x, sy, w, contentH);
  else drawSetApp(x, sy, w, contentH);
}

void drawSetAnt(float x, float y, float w, float h) {
  float ox = x+20f;
  float oy = y;
  for(int i=0;i<6;i++) {
    float row = oy + i*72f;
    fill(T.card);
    noStroke();
    rect(ox, row, w-40f, 62f, 8f);

    fill(T.accent2);
    textSize(10f);
    textAlign(LEFT, TOP);
    text("ANT " +(i+1), ox+10f, row+8f);

    // Name field
    boolean ef = editF && editKey.equals("antName"+i);
    drawTextField("Nome:", ox+10f, row+24f, 160f, 26f, antNames[i], ef);

    // Dir field
    boolean ef2 = editF && editKey.equals("antDir"+i);
    drawTextField("Dir:", ox+185f, row+24f, 80f, 26f, antDir[i]+"°", ef2);

    // Active LED
    fill(antStates[i] ? T.ok : T.txtDim);
    ellipse(ox+290f, row+34f, 10f, 10f);
    fill(T.txtDim);
    textSize(9f);
    textAlign(LEFT, CENTER);
    text(antStates[i] ? "ATTIVA" : "OFF", ox+298f, row+34f);
  }
}

void drawSetConn(float x, float y, float w, float h) {
  float ox = x+20f, oy = y;
  // ── ANT block ─────────────────────────────────────────────
  drawConnBlock("ESP32 ANTENNA SWITCH", ox, oy, w-40f, 180f,
                antMode, antPort, antBaud, antIP, antWPort, antConn,
                "antMode","antPort","antIP","antWPort");
  // ── ROT block ─────────────────────────────────────────────
  drawConnBlock("ESP32 ROTATORE", ox, oy+200f, w-40f, 180f,
                rotMode, rotPort, rotBaud, rotIP, rotWPort, rotConn,
                "rotMode","rotPort","rotIP","rotWPort");
}

void drawConnBlock(String title, float x, float y, float w, float h,
                   int mode, String port, int baud, String ip, int wport, boolean conn,
                   String kMode, String kPort, String kIP, String kWPort) {
  fill(T.card);
  stroke(T.brdr);
  strokeWeight(1f);
  rect(x, y, w, h, 10f);
  noStroke();

  fill(T.accent2);
  textSize(11f);
  textAlign(LEFT, TOP);
  text(title, x+12f, y+10f);

  // Mode toggle
  String[] modes = {"USB","WiFi"};
  for(int i=0; i<2; i++) {
    boolean sel = (mode==i);
    fill(sel ? T.accent : T.btnInact);
    stroke(sel ? T.accent : T.brdr);
    strokeWeight(1f);
    rect(x+12f+i*64f, y+30f, 56f, 22f, 6f);
    noStroke();
    fill(sel ? T.bg : T.txt);
    textSize(10f);
    textAlign(CENTER, CENTER);
    text(modes[i], x+12f+i*64f+28f, y+41f);
  }

  // Connection status dot
  color sc = conn ? T.ok : T.err;
  fill(sc);
  ellipse(x+w-24f, y+41f, 10f, 10f);
  fill(sc);
  textSize(9f);
  textAlign(RIGHT, CENTER);
  text(conn ? "CONNESSO" : "NON CONN.", x+w-32f, y+41f);

  if(mode==0) {
    // USB: port list
    fill(T.txtDim);
    textSize(10f);
    textAlign(LEFT, TOP);
    text("Porta:", x+12f, y+60f);
    float px = x+12f;
    for(int i=0; i<min(availPorts.length,4); i++) {
      boolean sel = availPorts[i].equals(port);
      fill(sel ? T.accent : T.panel);
      stroke(sel ? T.accent : T.brdr);
      strokeWeight(1f);
      rect(px, y+74f, 100f, 20f, 4f);
      noStroke();
      fill(sel ? T.bg : T.txt);
      textSize(9f);
      textAlign(CENTER, CENTER);
      text(availPorts[i], px+50f, y+84f);
      px += 108f;
    }
    if(availPorts.length==0) {
      fill(T.err);
      textSize(9f);
      textAlign(LEFT, TOP);
      text("Nessuna porta trovata", x+12f, y+76f);
    }
    // Baud
    fill(T.txtDim);
    textSize(10f);
    textAlign(LEFT, TOP);
    text("Baud: "+baud, x+12f, y+100f);
  } else {
    // WiFi
    fill(T.txtDim);
    textSize(10f);
    textAlign(LEFT, TOP);
    text("Indirizzo IP:", x+12f, y+60f);
    boolean efIP = editF && editKey.equals(kIP);
    drawTextField("", x+100f, y+56f, 160f, 22f, ip, efIP);
    text("Porta HTTP:", x+12f, y+90f);
    boolean efP = editF && editKey.equals(kWPort);
    drawTextField("", x+100f, y+86f, 80f, 22f, ""+wport, efP);
  }

  // Connect / Disconnect buttons
  boolean isAnt = kMode.startsWith("ant");
  float btY = y+h-34f;
  drawSmallBtn(conn ? "DISCONNETTI" : "CONNETTI",
               x+12f, btY, 110f, 24f,
               conn ? T.err : T.ok,
               isAnt ? "connAnt" : "connRot");
  drawSmallBtn("SCAN PORTE", x+132f, btY, 100f, 24f, T.accent2, "scanPorts");
  strokeWeight(1f);
}

void drawSmallBtn(String label, float x, float y, float w, float h, color c, String id) {
  fill(c, 40);
  stroke(c);
  strokeWeight(1f);
  rect(x, y, w, h, 5f);
  noStroke();
  fill(c);
  textSize(10f);
  textAlign(CENTER, CENTER);
  text(label, x+w/2f, y+h/2f);
  strokeWeight(1f);
}

void drawSetSys(float x, float y, float w, float h) {
  float ox = x+20f;
  float oy = y;
  float secW = w-40f;
  float cy; // content start Y for each section

  // ── Map section ─────────────────────────────────────────
  cy = drawSectionHeader("MAPPA AZIMUTALE", ox, oy, secW, 120f);
  String mapLabel = (mapImg!=null) ? "✓ " + mapPath.substring(max(0,mapPath.lastIndexOf('/')+1))
                                   : "Nessuna mappa caricata";
  fill(T.txtDim); textSize(10f); textAlign(LEFT, TOP);
  text(mapLabel, ox+12f, cy+8f);
  drawSmallBtn("CARICA MAPPA", ox+12f, cy+24f, 120f, 24f, T.accent2, "loadMap");
  if(mapImg!=null) drawSmallBtn("RIMUOVI", ox+140f, cy+24f, 80f, 24f, T.err, "removeMap");
  fill(T.txtDim); textSize(10f); textAlign(LEFT, TOP);
  text("Opacita' mappa: "+(int)(mapOpacity*100f)+"%", ox+12f, cy+56f);
  drawInlineSlider(ox+140f, cy+52f, secW-160f, 20f, mapOpacity, 0f, 1f, "mapOpacity");
  drawCheckbox("Mostra griglia",   ox+12f,  cy+82f,  showGrid,     "showGrid");
  drawCheckbox("Mostra cardinali", ox+150f, cy+82f,  showCardinals,"showCardinals");
  drawCheckbox("Mostra fascio",    ox+12f,  cy+102f, showBeam,     "showBeam");
  oy += 120f + 28f;

  // ── Beam width ─────────────────────────────────────────
  oy += 8f;
  cy = drawSectionHeader("ANTENNA DIRETTIVA", ox, oy, secW, 42f);
  fill(T.txtDim); textSize(10f); textAlign(LEFT, TOP);
  text("Apertura fascio: "+(int)beamW+"°", ox+12f, cy+8f);
  drawInlineSlider(ox+150f, cy+4f, secW-170f, 20f, (beamW-5f)/175f, 0f, 1f, "beamW");
  oy += 42f + 28f;

  // ── Brake release ───────────────────────────────────────
  oy += 8f;
  cy = drawSectionHeader("BRAKE RELEASE", ox, oy, secW, 52f);
  drawCheckbox("Il rotore ha il tasto Brake Release", ox+12f, cy+8f, hasBrake, "hasBrake");
  fill(T.txtDim); textSize(9f); textAlign(LEFT, TOP);
  text("Se non spuntato, il pulsante BRAKE viene nascosto ma i tasti restano centrati.",
       ox+12f, cy+28f);
  oy += 52f + 28f;

  // ── Smoothing & Relay — WEB ONLY ────────────────────────
  oy += 8f;
  cy = drawSectionHeader("SMOOTHING & RELAY", ox, oy, secW, 52f);
  fill(T.warn, 40);
  noStroke();
  rect(ox+8f, cy+6f, secW-16f, 36f, 6f);
  stroke(T.warn); strokeWeight(1f); noFill();
  rect(ox+8f, cy+6f, secW-16f, 36f, 6f);
  noStroke();
  fill(T.warn); textSize(10f); textAlign(LEFT, CENTER);
  text("⚠  Regola SOLO via interfaccia web ESP32 — non in Processing (evita conflitti).",
       ox+16f, cy+24f);
  oy += 52f + 28f;

  // ── Exit behaviour ──────────────────────────────────────
  oy += 8f;
  cy = drawSectionHeader("CHIUSURA APP", ox, oy, secW, 90f);
  String[] radios = {"Spegni tutti i rele'","Salva ultima posizione","Punta direzione fissa"};
  for(int i=0; i<3; i++) {
    boolean rsel = (exitMode==i);
    fill(rsel ? T.accent : T.txtDim);
    ellipse(ox+20f, cy+12f+i*26f, 10f, 10f);
    if(rsel) { fill(T.bg); ellipse(ox+20f, cy+12f+i*26f, 5f, 5f); }
    fill(T.txt); textSize(11f); textAlign(LEFT, CENTER);
    text(radios[i], ox+32f, cy+12f+i*26f);
    if(i==2 && exitMode==2) {
      boolean ef3 = editF && editKey.equals("fixedAz");
      drawTextField("Az:", ox+220f, cy+2f+i*26f, 80f, 22f, nf(fixedAz,1,1), ef3);
    }
  }
  oy += 90f + 28f;

  // ── Auto-connect ────────────────────────────────────────
  oy += 8f;
  cy = drawSectionHeader("CONNESSIONE AUTOMATICA", ox, oy, secW, 52f);
  drawCheckbox("Connetti automaticamente all'avvio", ox+12f, cy+8f, autoConn, "autoConn");
  fill(T.txtDim); textSize(9f); textAlign(LEFT, TOP);
  text("Non blocca l'app se la porta non e' disponibile (thread separato con try/catch).",
       ox+12f, cy+28f);
}

// Draws section background + title line and returns the Y where content begins
float drawSectionHeader(String title, float x, float y, float w, float innerH) {
  fill(T.panel);
  noStroke();
  rect(x, y, w, innerH+28f, 8f);
  fill(T.accent);
  textSize(10f);
  textAlign(LEFT, TOP);
  text(title, x+10f, y+8f);
  stroke(T.brdr);
  strokeWeight(0.5f);
  line(x+4f, y+22f, x+w-4f, y+22f);
  noStroke();
  strokeWeight(1f);
  return y + 22f;
}

void drawInlineSlider(float x, float y, float w, float h, float val, float mn, float mx, String key) {
  float fy = y + h/2f - 3f;
  noStroke();
  fill(T.sliderTk);
  rect(x, fy, w, 6f, 3f);
  float frac = constrain((val-mn)/(mx-mn), 0f, 1f);
  fill(T.sliderFl);
  rect(x, fy, w*frac, 6f, 3f);
  float kx = x + w*frac;
  fill(T.sliderFl);
  ellipse(kx, fy+3f, 14f, 14f);
  fill(T.bg);
  ellipse(kx, fy+3f, 6f, 6f);
}

void drawCheckbox(String label, float x, float y, boolean val, String key) {
  fill(val ? T.accent : T.btnInact);
  stroke(val ? T.accent : T.brdr);
  strokeWeight(1.5f);
  rect(x, y, 14f, 14f, 3f);
  noStroke();
  if(val) { fill(T.bg); textSize(10f); textAlign(CENTER, CENTER); text("✓", x+7f, y+7f); }
  fill(T.txt);
  textSize(11f);
  textAlign(LEFT, CENTER);
  text(label, x+20f, y+7f);
  strokeWeight(1f);
}

void drawTextField(String label, float x, float y, float w, float h, String val, boolean active) {
  if(label.length()>0) {
    fill(T.txtDim); textSize(9f); textAlign(LEFT, CENTER);
    text(label, x, y+h/2f);
    x += textWidth(label)+4f;
    w -= textWidth(label)+4f;
  }
  fill(active ? T.card : T.panel);
  stroke(active ? T.accent : T.brdr);
  strokeWeight(active ? 2f : 1f);
  rect(x, y, w, h, 4f);
  noStroke();
  fill(T.txt);
  textSize(10f);
  textAlign(LEFT, CENTER);
  String disp = active ? (val+(millis()/500%2==0?"|":"")) : val;
  text(disp, x+6f, y+h/2f);
  strokeWeight(1f);
}

void drawSetApp(float x, float y, float w, float h) {
  float ox = x+20f, oy = y;
  fill(T.txtDim);
  textSize(12f);
  textAlign(LEFT, TOP);
  text("Offset rotazione mappa:", ox, oy+10f);
  drawInlineSlider(ox+180f, oy+6f, w-220f, 24f,
                   (mapRotOffset+180f)/360f, 0f, 1f, "mapRotOffset");
  fill(T.txtDim); textSize(10f); textAlign(LEFT,TOP);
  text(nf(mapRotOffset,1,1)+"°", ox+180f + (w-220f)*((mapRotOffset+180f)/360f) + 4f, oy+10f);
}

// ─── 13. DRAW DEBUG ──────────────────────────────────────────
void drawDebug(float topH, float navH) {
  float x=0f, y=topH, w=width, h=height-topH-navH;
  fill(T.bg);
  noStroke();
  rect(x, y, w, h);

  fill(T.accent);
  textSize(11f);
  textAlign(LEFT, TOP);
  text("DEBUG CONSOLE", x+14f, y+8f);

  // Buttons
  drawSmallBtn("CLEAR", x+w-220f, y+4f, 60f, 22f, T.err, "clearLog");
  drawSmallBtn("SCAN PORTE", x+w-152f, y+4f, 90f, 22f, T.accent2, "scanPorts");
  drawSmallBtn("EXPORT", x+w-54f, y+4f, 50f, 22f, T.warn, "exportLog");

  // Log lines
  float lineH = 16f;
  int maxLines = (int)((h-40f)/lineH);
  int start = max(0, logLines.size() - maxLines - logScroll);
  int end   = min(logLines.size(), start + maxLines);
  for(int i=start; i<end; i++) {
    String line = logLines.get(i);
    color lc = T.txt;
    if(line.contains("[ERR]")) lc = T.err;
    else if(line.contains("[WRN]")) lc = T.warn;
    else if(line.contains("[OK]"))  lc = T.ok;
    else if(line.contains("[NOTIF]")) lc = T.accent2;
    fill(lc);
    textSize(10f);
    textAlign(LEFT, TOP);
    text(line, x+10f, y+34f+(i-start)*lineH);
  }
  // Scrollbar
  if(logLines.size() > maxLines) {
    float sbH = h-40f;
    float thH = sbH * maxLines / logLines.size();
    float thY = y+34f + (sbH-thH) * (float)logScroll / max(1, logLines.size()-maxLines);
    fill(T.brdr);
    rect(x+w-8f, y+34f, 6f, sbH, 3f);
    fill(T.accent);
    rect(x+w-8f, thY, 6f, thH, 3f);
  }
}

// ─── 14. DRAW TOP BAR + NAV BAR ──────────────────────────────
void drawTopBar(float topH) {
  fill(T.topBar);
  noStroke();
  rect(0f, 0f, width, topH);
  stroke(T.brdr);
  strokeWeight(1f);
  line(0f, topH, width, topH);
  noStroke();

  // Logo / Title
  fill(T.accent);
  textSize(14f);
  textAlign(LEFT, CENTER);
  text("RemoteControl v6", 14f, topH/2f);

  // Connection badges
  drawTopBadge("ANT", antConn, antMode, antMode==0?antPort:antIP, width/2f - 110f, topH);
  drawTopBadge("ROT", rotConn, rotMode, rotMode==0?rotPort:rotIP, width/2f + 10f,  topH);

  // Clock
  fill(T.txtDim);
  textSize(10f);
  textAlign(RIGHT, CENTER);
  text(nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2), width-14f, topH/2f);
  strokeWeight(1f);
}

void drawTopBadge(String label, boolean conn, int mode, String addr, float x, float topH) {
  color c = conn ? T.ok : T.err;
  fill(c, 30);
  noStroke();
  rect(x, 6f, 210f, topH-12f, 5f);
  fill(c);
  ellipse(x+12f, topH/2f, 8f, 8f);
  textSize(9f);
  textAlign(LEFT, CENTER);
  fill(c);
  text(label, x+22f, topH/2f - 4f);
  fill(T.txtDim);
  String mLabel = mode==0 ? "USB: " : "WiFi: ";
  text(mLabel + addr, x+22f, topH/2f + 6f);
}

void drawNavBar(float y, float navH) {
  fill(T.navBg);
  noStroke();
  rect(0f, y, width, navH);
  stroke(T.brdr);
  strokeWeight(1f);
  line(0f, y, width, y);
  noStroke();

  String[] labels = {"CONTROLLO","IMPOSTAZIONI","DEBUG"};
  String[] icons  = {"◉","⚙","⬛"};
  float btnW = width / labels.length;
  for(int i=0; i<labels.length; i++) {
    boolean sel = (curScr==i);
    if(sel) {
      fill(T.accent, 30);
      rect(i*btnW, y, btnW, navH);
      fill(T.accent);
      rect(i*btnW, y, btnW, 3f);
    }
    fill(sel ? T.accent : T.txtDim);
    textSize(11f);
    textAlign(CENTER, CENTER);
    text(icons[i]+"  "+labels[i], i*btnW+btnW/2f, y+navH/2f);
  }
  strokeWeight(1f);
}

// ─── 15. MOUSE / KEYBOARD ────────────────────────────────────
void mousePressed() {
  // Nav bar click
  float navY = height - 48f;
  if(mouseY > navY) {
    int idx = (int)(mouseX / (width/3f));
    if(idx >= 0 && idx < 3) { curScr = idx; setScrollY=0f; }
    return;
  }

  if(curScr == SCR_CTRL) handleCtrlClick();
  else if(curScr == SCR_SET) handleSetClick();
  else handleDbgClick();
}

void handleCtrlClick() {
  float topH = 44f;
  float navH = 48f;

  // Antenna buttons
  float lw = ctrlSplit;
  float btnW = (lw-28f)/2f - 6f;
  float btnH = 52f;
  float bx0 = 14f, bx1 = bx0+btnW+12f;
  float by0 = topH+56f, gap=10f;
  for(int i=0;i<6;i++) {
    float bx = (i%2==0)?bx0:bx1;
    float by = by0+(i/2)*(btnH+gap);
    if(over(bx,by,btnW,btnH)) {
      selAnt = (selAnt==i) ? -1 : i;
      if(selAnt==i) { toggleAnt(i); }
      return;
    }
  }

  // ROT power button
  float rx = ctrlSplit, ry = topH;
  float rw = width-ctrlSplit;
  if(over(rx+14f, ry+50f, 60f, 30f)) {
    rotPwr = !rotPwr;
    sendRot("PWR:"+(rotPwr?1:0));
    return;
  }

  // ROT buttons
  float btnAreaY = mapCY + mapR + 18f;
  int nBt = hasBrake ? 4 : 3;
  float rbtnW = min(78f, (rw-28f)/nBt-8f);
  float totW = nBt*rbtnW+(nBt-1)*8f;
  float sX = mapCX - totW/2f;
  for(int i=0;i<nBt;i++) {
    float bx = sX+i*(rbtnW+8f);
    if(over(bx, btnAreaY, rbtnW, 46f)) {
      handleRotBtn(i, nBt);
      return;
    }
  }

  // Brake slider drag start
  float sliderY = btnAreaY + 60f;
  float sly = sliderY + 22f - 3f;
  float slx = ctrlSplit+14f, slw = rw-28f;
  float kx = slx + slw*(brakeMs/1000f);
  if(dist(mouseX, mouseY, kx, sly+3f) < 14f) {
    brakeDrag = true;
    dragStartX = mouseX;
    dragStartV = brakeMs;
  }

  // GOTO on map click
  if(dist(mouseX, mouseY, mapCX, mapCY) < mapR) {
    float dx = mouseX - mapCX;
    float dy = mouseY - mapCY;
    float ang = degrees(atan2(dy, dx)) + 90f - mapRotOffset;
    ang = (ang % 360f + 360f) % 360f;
    targetAz = ang;
    gotoActive = true;
    sendRot("GOTO:"+nf(targetAz,1,1));
    N("GOTO "+nf(targetAz,1,1)+"°", NTFY_INF);
  }
}

void handleRotBtn(int idx, int nBt) {
  if(nBt==4) {
    // 0=CCW 1=HALT 2=BRAKE 3=CW
    if(idx==0) { rotCCW=!rotCCW; rotCW=false; sendRot("CCW:"+(rotCCW?1:0)); if(rotCCW) sendRot("CW:0"); }
    else if(idx==1) { rotCW=false; rotCCW=false; gotoActive=false; sendRot("CW:0"); sendRot("CCW:0"); N("HALT",NTFY_WRN); }
    else if(idx==2) { brakeRel=!brakeRel; sendRot("BRAKE:"+(brakeRel?1:0)+":"+brakeMs); }
    else if(idx==3) { rotCW=!rotCW; rotCCW=false; sendRot("CW:"+(rotCW?1:0)); if(rotCW) sendRot("CCW:0"); }
  } else {
    // 0=CCW 1=HALT 2=CW
    if(idx==0) { rotCCW=!rotCCW; rotCW=false; sendRot("CCW:"+(rotCCW?1:0)); if(rotCCW) sendRot("CW:0"); }
    else if(idx==1) { rotCW=false; rotCCW=false; gotoActive=false; sendRot("CW:0"); sendRot("CCW:0"); N("HALT",NTFY_WRN); }
    else if(idx==2) { rotCW=!rotCW; rotCCW=false; sendRot("CW:"+(rotCW?1:0)); if(rotCW) sendRot("CCW:0"); }
  }
}

void handleSetClick() {
  float topH = 44f;
  float sy = topH;
  // Tab clicks
  float tabW = width / 4f;
  if(mouseY > sy && mouseY < sy+36f) {
    setTab = (int)(mouseX / tabW);
    setScrollY = 0f;
    return;
  }
  // Content clicks
  if(setTab==1) handleSetConnClick();
  else if(setTab==2) handleSetSysClick();
}

void handleSetConnClick() {
  // Check mode toggles / buttons (simplified hit testing)
  float ox = 20f;
  float[] offsets = {0f, 200f};
  boolean[] modes = {antMode==0, rotMode==0};
  for(int b=0; b<2; b++) {
    float oy = 44f + 40f + setScrollY + offsets[b];
    // USB/WiFi buttons
    for(int i=0;i<2;i++) {
      if(over(ox+12f+i*64f, oy+30f, 56f, 22f)) {
        if(b==0) antMode=i; else rotMode=i;
        return;
      }
    }
    // Connect button
    float btY = oy+180f-34f;
    if(over(ox+12f, btY, 110f, 24f)) {
      if(b==0) { if(antConn) disconn("ANT"); else thread("connAntThread"); }
      else     { if(rotConn) disconn("ROT"); else thread("connRotThread"); }
      return;
    }
    // Scan ports button
    if(over(ox+132f, btY, 100f, 24f)) {
      availPorts = Serial.list();
      N("Trovate "+availPorts.length+" porte", NTFY_INF);
      return;
    }
  }
}

void handleSetSysClick() {
  float ox = 20f;
  // y is the content start: topH(44) + tabBar(40) + setScrollY
  float y0 = 44f + 40f + setScrollY;

  // Section 1: MAPPA AZIMUTALE — cy = y0 + 22
  float mapCy = y0 + 22f;
  if(over(ox+12f, mapCy+24f, 120f, 24f)) {
    selectInput("Seleziona mappa azimutale (PNG/JPG):", "onMapFile"); return;
  }
  if(mapImg!=null && over(ox+140f, mapCy+24f, 80f, 24f)) {
    mapImg = null; mapPath = ""; N("Mappa rimossa", NTFY_WRN); return;
  }
  // showGrid checkbox at mapCy+82 (left col)
  if(over(ox+12f,  mapCy+82f, 14f, 14f)) { showGrid = !showGrid; return; }
  // showCardinals at same Y, right col (ox+150)
  if(over(ox+150f, mapCy+82f, 14f, 14f)) { showCardinals = !showCardinals; return; }
  // showBeam at mapCy+102
  if(over(ox+12f,  mapCy+102f, 14f, 14f)) { showBeam = !showBeam; return; }

  // Section 3: BRAKE RELEASE — starts at y0+234, cy = y0+256
  float brakeCy = y0 + 256f;
  if(over(ox+12f, brakeCy+8f, 14f, 14f)) { hasBrake = !hasBrake; return; }

  // Section 5: CHIUSURA APP — starts at y0+410, cy = y0+432
  float exitCy = y0 + 432f;
  for(int i=0; i<3; i++) {
    if(over(ox+12f, exitCy+i*26f+7f, 200f, 16f)) { exitMode = i; return; }
  }
  if(exitMode==2) {
    boolean ef3 = over(ox+220f, exitCy+2f+2*26f, 80f, 22f);
    if(ef3 && !editF) { editF=true; editKey="fixedAz"; inBuf=nf(fixedAz,1,1); return; }
  }

  // Section 6: CONNESSIONE AUTOMATICA — starts at y0+536, cy = y0+558
  float autoCy = y0 + 558f;
  if(over(ox+12f, autoCy+8f, 14f, 14f)) { autoConn = !autoConn; return; }
}

void handleDbgClick() {
  float topH = 44f;
  float w = width;
  float navH = 48f;
  float h = height-topH-navH;
  if(over(w-220f, topH+4f, 60f, 22f)) { logLines.clear(); N("Log pulito",NTFY_INF); }
  else if(over(w-152f, topH+4f, 90f, 22f)) { availPorts=Serial.list(); N("Ports: "+availPorts.length,NTFY_INF); }
  else if(over(w-54f, topH+4f, 50f, 22f)) exportLog();
}

void mouseDragged() {
  if(brakeDrag) {
    float rw = width - ctrlSplit;
    float slw = rw - 28f;
    float delta = mouseX - dragStartX;
    float newV = dragStartV + delta/slw * 1000f;
    brakeMs = (int)(constrain(round(newV/50f)*50f, 0f, 1000f));
  }
}

void mouseReleased() {
  if(brakeDrag) { brakeDrag=false; sendRot("BRAKEMS:"+brakeMs); }
}

void mouseWheel(MouseEvent e) {
  if(curScr==SCR_SET) {
    setScrollTarget += e.getCount()*20f;
    setScrollY = lerp(setScrollY, setScrollTarget, 0.3f);
  } else if(curScr==SCR_DBG) {
    logScroll = constrain(logScroll - e.getCount(), 0, max(0,logLines.size()-20));
  }
}

void keyPressed() {
  if(editF) {
    if(keyCode==BACKSPACE && inBuf.length()>0) inBuf=inBuf.substring(0,inBuf.length()-1);
    else if(keyCode==ENTER) { try { commitEdit(); } catch(Exception e) { dlog("[ERR] commitEdit: "+e.getMessage()); } finally { editF=false; } }
    else if(keyCode==ESCAPE) { editF=false; }
    else if(key>=32 && key!=CODED) inBuf+=key;
  } else {
    // Keyboard shortcuts
    if(key=='1') { toggleAnt(0); }
    else if(key=='2') { toggleAnt(1); }
    else if(key=='3') { toggleAnt(2); }
    else if(key=='4') { toggleAnt(3); }
    else if(key=='5') { toggleAnt(4); }
    else if(key=='6') { toggleAnt(5); }
    else if(key==' ') { rotCW=false; rotCCW=false; gotoActive=false; sendRot("CW:0"); sendRot("CCW:0"); }
  }
}

void commitEdit() {
  if(editKey.startsWith("antName")) {
    int i = Integer.parseInt(editKey.replace("antName",""));
    antNames[i] = inBuf;
  } else if(editKey.startsWith("antDir")) {
    int i = Integer.parseInt(editKey.replace("antDir",""));
    try { antDir[i] = Integer.parseInt(inBuf.replace("°","")); } catch(Exception e) {}
  } else if(editKey.equals("antIP"))   antIP   = inBuf;
  else if(editKey.equals("antWPort"))  { try { antWPort=Integer.parseInt(inBuf); } catch(Exception e) {} }
  else if(editKey.equals("rotIP"))     rotIP   = inBuf;
  else if(editKey.equals("rotWPort"))  { try { rotWPort=Integer.parseInt(inBuf); } catch(Exception e) {} }
  else if(editKey.equals("fixedAz"))   { try { fixedAz=Float.parseFloat(inBuf); } catch(Exception e) {} }
  saveToCfg(); cfg.save();
}

boolean over(float x, float y, float w, float h) {
  return mouseX>=x && mouseX<=x+w && mouseY>=y && mouseY<=y+h;
}

// ─── 16. ESP32 COMMUNICATION ─────────────────────────────────

// Auto-connect thread (non-blocking at startup)
void autoConnThread() {
  try { safeConn("ANT"); } catch(Exception e) { dlog("AutoConn ANT skip: "+e.getMessage()); }
  try { safeConn("ROT"); } catch(Exception e) { dlog("AutoConn ROT skip: "+e.getMessage()); }
}

void connAntThread() {
  try { safeConn("ANT"); } catch(Exception e) { dlog("Conn ANT err: "+e.getMessage()); }
}
void connRotThread() {
  try { safeConn("ROT"); } catch(Exception e) { dlog("Conn ROT err: "+e.getMessage()); }
}

void safeConn(String which) {
  boolean isAnt = which.equals("ANT");
  try {
    if(isAnt) {
      if(antMode==0) {
        if(antSerial!=null) try { antSerial.stop(); } catch(Exception e2) {}
        antSerial = new Serial(RemoteControl_v6.this, antPort, antBaud);
        antSerial.bufferUntil('\n');
        antConn = true;
        N("ANT USB " + antPort + " connesso", NTFY_OK);
      } else {
        if(antClient!=null) try { antClient.stop(); } catch(Exception e2) {}
        antClient = new Client(RemoteControl_v6.this, antIP, antWPort);
        antConn = antClient.active();
        N(antConn ? "ANT WiFi "+antIP+" connesso" : "ANT WiFi fallito", antConn?NTFY_OK:NTFY_ERR);
      }
    } else {
      if(rotMode==0) {
        if(rotSerial!=null) try { rotSerial.stop(); } catch(Exception e2) {}
        rotSerial = new Serial(RemoteControl_v6.this, rotPort, rotBaud);
        rotSerial.bufferUntil('\n');
        rotConn = true;
        N("ROT USB " + rotPort + " connesso", NTFY_OK);
      } else {
        if(rotClient!=null) try { rotClient.stop(); } catch(Exception e2) {}
        rotClient = new Client(RemoteControl_v6.this, rotIP, rotWPort);
        rotConn = rotClient.active();
        N(rotConn ? "ROT WiFi "+rotIP+" connesso" : "ROT WiFi fallito", rotConn?NTFY_OK:NTFY_ERR);
      }
    }
  } catch(Exception e) {
    if(isAnt) antConn=false; else rotConn=false;
    dlog("[ERR] safeConn "+which+": "+e.getMessage());
    N("Connessione "+which+" fallita: "+e.getMessage(), NTFY_ERR);
  }
}

void disconn(String which) {
  if(which.equals("ANT")) {
    try { if(antSerial!=null) antSerial.stop(); } catch(Exception e) {}
    try { if(antClient!=null) antClient.stop(); } catch(Exception e) {}
    antSerial=null; antClient=null; antConn=false;
    N("ANT disconnesso", NTFY_WRN);
  } else {
    try { if(rotSerial!=null) rotSerial.stop(); } catch(Exception e) {}
    try { if(rotClient!=null) rotClient.stop(); } catch(Exception e) {}
    rotSerial=null; rotClient=null; rotConn=false;
    N("ROT disconnesso", NTFY_WRN);
  }
}

void toggleAnt(int idx) {
  if(!antConn) { N("ANT non connesso", NTFY_ERR); return; }
  antStates[idx] = !antStates[idx];
  // Deactivate all others if switching on
  if(antStates[idx]) {
    for(int i=0;i<6;i++) if(i!=idx) antStates[i]=false;
    selAnt = idx;
  }
  sendAnt("ANT:"+(idx+1)+":"+(antStates[idx]?1:0));
}

void sendAnt(String cmd) {
  if(!antConn) return;
  String full = cmd+"\n";
  try {
    if(antMode==0 && antSerial!=null) antSerial.write(full);
    else if(antMode==1 && antClient!=null && antClient.active())
      antClient.write("GET /cmd?v="+cmd+" HTTP/1.0\r\nHost:"+antIP+"\r\n\r\n");
  } catch(Exception e) { dlog("[ERR] sendAnt: "+e.getMessage()); antConn=false; }
}

void sendRot(String cmd) {
  if(!rotConn) return;
  String full = cmd+"\n";
  try {
    if(rotMode==0 && rotSerial!=null) rotSerial.write(full);
    else if(rotMode==1 && rotClient!=null && rotClient.active())
      rotClient.write("GET /cmd?v="+cmd+" HTTP/1.0\r\nHost:"+rotIP+"\r\n\r\n");
  } catch(Exception e) { dlog("[ERR] sendRot: "+e.getMessage()); rotConn=false; }
}

void pollAnt() {
  if(!antConn || antMode!=1 || antClient==null) return;
  try { antClient.write("GET /status HTTP/1.0\r\nHost:"+antIP+"\r\n\r\n"); }
  catch(Exception e) { antConn=false; }
}

void pollRot() {
  if(!rotConn || rotMode!=1 || rotClient==null) return;
  try { rotClient.write("GET /status HTTP/1.0\r\nHost:"+rotIP+"\r\n\r\n"); }
  catch(Exception e) { rotConn=false; }
}

void processSerial() {
  // ANT serial
  if(antMode==0 && antSerial!=null) {
    try {
      while(antSerial.available()>0) {
        String l = antSerial.readStringUntil('\n');
        if(l!=null) procAnt(l.trim());
      }
    } catch(Exception e) { antConn=false; }
  }
  // ANT WiFi
  if(antMode==1 && antClient!=null && antClient.available()>0) {
    try {
      String l = antClient.readString();
      if(l!=null) procAnt(l.trim());
    } catch(Exception e) { antConn=false; }
  }
  // ROT serial
  if(rotMode==0 && rotSerial!=null) {
    try {
      while(rotSerial.available()>0) {
        String l = rotSerial.readStringUntil('\n');
        if(l!=null) procRot(l.trim());
      }
    } catch(Exception e) { rotConn=false; }
  }
  // ROT WiFi
  if(rotMode==1 && rotClient!=null && rotClient.available()>0) {
    try {
      String l = rotClient.readString();
      if(l!=null) procRot(l.trim());
    } catch(Exception e) { rotConn=false; }
  }
}

void procAnt(String s) {
  if(s.length()==0) return;
  dlog("ANT< "+s);
  // Expected: "ANT:1:1" or "STATUS:1:0:1:0:0:0"
  if(s.startsWith("ANT:")) {
    String[] p = s.split(":");
    if(p.length>=3) {
      int idx = Integer.parseInt(p[1])-1;
      if(idx>=0&&idx<6) antStates[idx] = p[2].equals("1");
    }
  } else if(s.startsWith("STATUS:")) {
    String[] p = s.split(":");
    for(int i=0;i<min(6,p.length-1);i++) antStates[i]=p[i+1].equals("1");
  }
}

void procRot(String s) {
  if(s.length()==0) return;
  dlog("ROT< "+s);
  // Expected: "AZ:180.5" or "ROT:CW:1" etc.
  if(s.startsWith("AZ:")) {
    try { curAz = Float.parseFloat(s.substring(3)); } catch(Exception e) {}
    if(gotoActive && abs(curAz-targetAz)<2f) {
      gotoActive=false; N("GOTO raggiunto "+nf(curAz,1,1)+"°", NTFY_OK);
    }
  } else if(s.startsWith("ROT:")) {
    String[] p = s.split(":");
    if(p.length>=3) {
      if(p[1].equals("CW"))    rotCW    = p[2].equals("1");
      if(p[1].equals("CCW"))   rotCCW   = p[2].equals("1");
      if(p[1].equals("BRAKE")) brakeRel = p[2].equals("1");
      if(p[1].equals("PWR"))   rotPwr   = p[2].equals("1");
    }
  }
}

void serialEvent(Serial s) {
  // Handled in processSerial()
}

// ─── DEBUG LOG ───────────────────────────────────────────────
void dlog(String msg) {
  String ts = nf(hour(),2)+":"+nf(minute(),2)+":"+nf(second(),2);
  logLines.add("["+ts+"] "+msg);
  if(logLines.size()>500) logLines.remove(0);
  println(msg);
}

void exportLog() {
  try {
    PrintWriter pw = createWriter(sketchPath("debug_log.txt"));
    for(String l : logLines) pw.println(l);
    pw.flush(); pw.close();
    N("Log esportato in debug_log.txt", NTFY_OK);
  } catch(Exception e) { N("Export fallito: "+e.getMessage(), NTFY_ERR); }
}

// ─── MAP CALLBACK ────────────────────────────────────────────
void onMapFile(File f) {
  if(f==null) return;
  try {
    mapPath = f.getAbsolutePath();
    mapImg  = loadImage(mapPath);
    cfg.ss("mapPath", mapPath);
    cfg.save();
    N("Mappa caricata: "+f.getName(), NTFY_OK);
  } catch(Exception e) {
    N("Errore caricamento mappa: "+e.getMessage(), NTFY_ERR);
  }
}

// ─── 17. EXIT HANDLER ────────────────────────────────────────
void exit() {
  dlog("Uscita con exitMode="+exitMode);
  if(exitMode==EXIT_ALL_OFF) {
    for(int i=0; i<6; i++) sendAnt("ANT:"+(i+1)+":0");
    sendRot("CW:0"); sendRot("CCW:0"); sendRot("BRAKE:0:0");
  } else if(exitMode==EXIT_FIXED) {
    sendRot("GOTO:"+nf(fixedAz,1,1));
  }
  // EXIT_SAVE_POS: do nothing, position is saved in config
  try { Thread.sleep(300); } catch(Exception e) {}
  saveToCfg();
  cfg.save();
  try { if(antSerial!=null) antSerial.stop(); } catch(Exception e) {}
  try { if(rotSerial!=null) rotSerial.stop(); } catch(Exception e) {}
  try { if(antClient!=null) antClient.stop(); } catch(Exception e) {}
  try { if(rotClient!=null) rotClient.stop(); } catch(Exception e) {}
  super.exit();
}
