/**
 * Smart Traffic Simulation — Browser Frontend
 *
 * Replicates the JavaFX MapCanvasRenderer in HTML5 Canvas.
 * Connects to the deployed Java backend via:
 *   - WebSocket  /ws/live     → 200 ms live snapshots
 *   - REST POST  /api/spawn   → spawn vehicle
 *   - REST POST  /api/control → pause / resume / reset / speed
 *   - REST POST  /api/congestion → road condition changes
 *   - REST GET   /api/map     → initial city map layout
 *
 * Backend URL is configured via:
 *   1. window.BACKEND_URL  (set by config.js on the server, if present)
 *   2. <meta name="backend-url"> tag
 *   3. Hard-coded default (the deployed Render backend)
 *
 * Never uses localhost in the deployed build.
 */

'use strict';

// ─── Backend URL resolution ────────────────────────────────────────────────
const BACKEND_URL = (() => {
  // Priority 1: injected at build / deploy time via config.js
  if (typeof window.BACKEND_URL === 'string' && window.BACKEND_URL.trim()) {
    return window.BACKEND_URL.trim().replace(/\/$/, '');
  }
  // Priority 2: <meta name="backend-url" content="..."> in index.html
  const meta = document.querySelector('meta[name="backend-url"]');
  if (meta && meta.content && meta.content.trim() && meta.content !== '__BACKEND_URL__') {
    return meta.content.trim().replace(/\/$/, '');
  }
  // Priority 3: deployed default
  return 'https://smart-traffic-management-system-xtar.onrender.com';
})();

const API_BASE = BACKEND_URL + '/api';
const WS_URL   = BACKEND_URL.replace(/^https/, 'wss').replace(/^http/, 'ws') + '/ws/live';

console.log('[Sim] Backend:', BACKEND_URL);
console.log('[Sim] WebSocket:', WS_URL);

// ─── Canvas renderer constants (mirrors JavaFX MapCanvasRenderer) ─────────
const C = {
  ROAD_WIDTH:    42,
  LANE_WIDTH:    21,
  JUNCTION_SIZE: 54,
  BASE_W:        1040,
  BASE_H:        840,

  // Color palette
  BG:              '#090d16',
  GRID:            'rgba(23,32,51,0.4)',
  ROAD_ASPHALT:    '#2c384a',
  ROAD_BORDER:     '#5a6b82',
  ROAD_DIAGONAL:   '#36475d',
  ROAD_CONGESTED:  '#b45309',
  ROAD_CLOSED:     '#7f1d1d',
  LANE_DIVIDER:    '#f59e0b',
  STOP_LINE:       '#f8fafc',
  ARROW:           'rgba(203,213,225,0.75)',
  JUNCTION_BOX:    '#1e293b',
  JUNCTION_BORDER: '#78889e',

  // Vehicle type specs (length, width, color) — mirrors Java VehicleType enum
  VEHICLE_TYPES: {
    CAR:       { len: 28, w: 13, color: '#38bdf8', emoji: '🚗' },
    BUS:       { len: 44, w: 17, color: '#f59e0b', emoji: '🚌' },
    TRUCK:     { len: 44, w: 17, color: '#f59e0b', emoji: '🚛' },
    AMBULANCE: { len: 34, w: 15, color: '#ef4444', emoji: '🚑' },
  },

  // Landmark badge colors — mirrors Java LandmarkType
  LANDMARK_COLORS: {
    HOSPITAL:       '#ef4444',
    RAILWAY_STATION:'#06b6d4',
    CITY_CENTER:    '#8b5cf6',
    SHOPPING_MALL:  '#f59e0b',
    UNIVERSITY:     '#10b981',
    TECH_PARK:      '#6366f1',
  },
};

// ─── Application state ────────────────────────────────────────────────────
const state = {
  map:            null,          // { intersections: [...], roads: [...] }
  vehicles:       [],            // latest vehicle list from WS
  signals:        {},            // intersectionId → { roadId → "GREEN"|"RED"|"YELLOW" }
  roads:          [],            // road condition overrides from WS
  simTime:        0,
  paused:         false,
  selectedId:     null,          // selected vehicle id
  ws:             null,
  wsConnected:    false,
  wsAttempts:     0,
  reconnectTimer: null,
};

// ─── DOM refs ─────────────────────────────────────────────────────────────
const canvas      = document.getElementById('simCanvas');
const ctx         = canvas.getContext('2d');
const wrap        = document.getElementById('canvasWrap');
const overlay     = document.getElementById('coldStartOverlay');
const coldAttempt = document.getElementById('coldAttempt');
const statusPill  = document.getElementById('statusPill');
const statusText  = document.getElementById('statusText');
const simClock    = document.getElementById('simClock');
const fleetList   = document.getElementById('fleetList');
const spawnMsg    = document.getElementById('spawnMsg');
const routePreview= document.getElementById('routePreview');
const btnPause    = document.getElementById('btnPause');
const btnReset    = document.getElementById('btnReset');
const btnSpawn    = document.getElementById('btnSpawn');
const vehType     = document.getElementById('vehType');
const vehFrom     = document.getElementById('vehFrom');
const vehTo       = document.getElementById('vehTo');

// ─── Canvas resize ────────────────────────────────────────────────────────
function resizeCanvas() {
  canvas.width  = wrap.clientWidth  * devicePixelRatio;
  canvas.height = wrap.clientHeight * devicePixelRatio;
  canvas.style.width  = wrap.clientWidth  + 'px';
  canvas.style.height = wrap.clientHeight + 'px';
  ctx.scale(devicePixelRatio, devicePixelRatio);
  redraw();
}
window.addEventListener('resize', resizeCanvas);

// ─── Coordinate transform helpers ─────────────────────────────────────────
function getTransform(cw, ch) {
  const scale   = Math.min(cw / C.BASE_W, ch / C.BASE_H);
  const offsetX = (cw - C.BASE_W * scale) / 2;
  const offsetY = (ch - C.BASE_H * scale) / 2;
  return { scale, offsetX, offsetY };
}

// ─── RENDERING ENGINE ─────────────────────────────────────────────────────
function redraw() {
  const cw = wrap.clientWidth;
  const ch = wrap.clientHeight;
  if (cw <= 0 || ch <= 0) return;

  ctx.clearRect(0, 0, cw, ch);

  // Background
  ctx.fillStyle = C.BG;
  ctx.fillRect(0, 0, cw, ch);

  // Grid
  drawGrid(ctx, cw, ch);

  if (!state.map) return;

  const { scale, offsetX, offsetY } = getTransform(cw, ch);

  ctx.save();
  ctx.translate(offsetX, offsetY);
  ctx.scale(scale, scale);

  // Build a fast road condition lookup from latest WS push
  const roadCondMap = {};
  for (const r of state.roads) roadCondMap[r.id] = r.condition;

  // Roads
  for (const road of state.map.roads) {
    const cond = roadCondMap[road.id] || road.condition || 'NORMAL';
    drawRoad(ctx, road, state.map, cond);
  }

  // Route highlight for selected vehicle
  const sel = state.vehicles.find(v => v.id === state.selectedId);
  if (sel && sel.routePath && sel.routePath.length >= 2) {
    drawRouteHighlight(ctx, sel.routePath, state.map);
  }

  // Intersections (with live signals)
  for (const inter of state.map.intersections) {
    const liveSigs = state.signals[inter.id] || {};
    drawIntersection(ctx, inter, state.map, liveSigs);
  }

  // Vehicles
  for (const v of state.vehicles) {
    if (v.status === 'COMPLETED') continue;
    drawVehicle(ctx, v, v.id === state.selectedId);
  }

  // Landmark badges (on top)
  for (const inter of state.map.intersections) {
    if (inter.landmark) drawLandmarkBadge(ctx, inter);
  }

  ctx.restore();
}

// Grid
function drawGrid(ctx, w, h) {
  ctx.strokeStyle = C.GRID;
  ctx.lineWidth = 1;
  const step = 40;
  for (let x = 0; x < w; x += step) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); }
  for (let y = 0; y < h; y += step) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
}

// Road
function drawRoad(ctx, road, map, condition) {
  const a = intersectionById(map, road.fromId);
  const b = intersectionById(map, road.toId);
  if (!a || !b) return;

  const x1 = a.x, y1 = a.y, x2 = b.x, y2 = b.y;
  const dx = x2 - x1, dy = y2 - y1;
  const dist = Math.hypot(dx, dy);
  if (dist === 0) return;

  const nx = -dy / dist, ny = dx / dist;
  const hw = C.ROAD_WIDTH / 2;

  let asphalt = (road.type === 'DIAGONAL') ? C.ROAD_DIAGONAL : C.ROAD_ASPHALT;
  if (condition === 'CONGESTED') asphalt = C.ROAD_CONGESTED;
  else if (condition === 'CLOSED') asphalt = C.ROAD_CLOSED;

  // Road surface
  ctx.fillStyle = asphalt;
  ctx.beginPath();
  ctx.moveTo(x1 + nx * hw, y1 + ny * hw);
  ctx.lineTo(x2 + nx * hw, y2 + ny * hw);
  ctx.lineTo(x2 - nx * hw, y2 - ny * hw);
  ctx.lineTo(x1 - nx * hw, y1 - ny * hw);
  ctx.closePath();
  ctx.fill();

  // Curb borders
  ctx.strokeStyle = C.ROAD_BORDER;
  ctx.lineWidth = 1.5;
  ctx.setLineDash([]);
  ctx.beginPath(); ctx.moveTo(x1 + nx * hw, y1 + ny * hw); ctx.lineTo(x2 + nx * hw, y2 + ny * hw); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(x1 - nx * hw, y1 - ny * hw); ctx.lineTo(x2 - nx * hw, y2 - ny * hw); ctx.stroke();

  // Center dashed yellow divider
  ctx.strokeStyle = C.LANE_DIVIDER;
  ctx.lineWidth = 1.8;
  ctx.setLineDash([9, 7]);
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  ctx.setLineDash([]);

  // Direction arrows
  drawLaneArrow(ctx, x1, y1, x2, y2, nx, ny, 0.40, +1);
  drawLaneArrow(ctx, x2, y2, x1, y1, nx, ny, 0.40, -1);
}

function drawLaneArrow(ctx, x1, y1, x2, y2, nx, ny, frac, side) {
  const px = x1 + (x2 - x1) * frac + nx * (C.LANE_WIDTH / 2) * side;
  const py = y1 + (y2 - y1) * frac + ny * (C.LANE_WIDTH / 2) * side;
  const angle = Math.atan2(y2 - y1, x2 - x1);

  ctx.save();
  ctx.translate(px, py);
  ctx.rotate(angle);
  ctx.strokeStyle = C.ARROW;
  ctx.lineWidth = 2;
  ctx.setLineDash([]);
  ctx.beginPath(); ctx.moveTo(-5, -4); ctx.lineTo(4, 0); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(-5,  4); ctx.lineTo(4, 0); ctx.stroke();
  ctx.restore();
}

// Intersection
function drawIntersection(ctx, inter, map, liveSigs) {
  const { x, y } = inter;
  const half = C.JUNCTION_SIZE / 2;

  // Junction box
  roundRect(ctx, x - half, y - half, C.JUNCTION_SIZE, C.JUNCTION_SIZE, 12, C.JUNCTION_BOX, C.JUNCTION_BORDER, 2);

  // Approach signals
  const connectedRoads = getConnectedRoads(map, inter.id);
  if (connectedRoads.length > 2) {
    for (const road of connectedRoads) {
      const other = intersectionById(map, road.fromId === inter.id ? road.toId : road.fromId);
      if (!other) continue;
      drawApproachSignal(ctx, inter, other, road, liveSigs, map);
    }
  }

  // Central ID badge
  ctx.fillStyle = 'rgba(10,15,29,0.9)';
  ctx.beginPath(); ctx.arc(x, y, 14, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = '#38bdf8'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.arc(x, y, 14, 0, Math.PI * 2); ctx.stroke();

  ctx.fillStyle = '#f8fafc';
  ctx.font = 'bold 11px "Segoe UI", sans-serif';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(inter.id, x, y);
}

function drawApproachSignal(ctx, inter, other, road, liveSigs, map) {
  const cx = inter.x, cy = inter.y;
  const dx = other.x - cx, dy = other.y - cy;
  const dist = Math.hypot(dx, dy);
  if (dist === 0) return;

  const ux = dx / dist, uy = dy / dist;
  const curbX = uy, curbY = -ux;

  const headDist   = C.JUNCTION_SIZE / 2 + 12;
  const lateralOff = C.ROAD_WIDTH / 2 + 7;
  const headX = cx + ux * headDist + curbX * lateralOff;
  const headY = cy + uy * headDist + curbY * lateralOff;
  const roadAngle = Math.atan2(dy, dx);

  // Determine signal color from live signals
  let color = liveSigs[road.id] || inter.signals?.[road.id] || 'RED';

  // Stop line
  drawStopLine(ctx, cx, cy, ux, uy, curbX, curbY);

  // 3-aspect head
  drawThreeAspectHead(ctx, headX, headY, roadAngle, color);
}

function drawStopLine(ctx, cx, cy, ux, uy, curbX, curbY) {
  const d = C.JUNCTION_SIZE / 2 + 2;
  const sx = cx + ux * d, sy = cy + uy * d;
  ctx.strokeStyle = C.STOP_LINE; ctx.lineWidth = 3; ctx.setLineDash([]);
  ctx.beginPath();
  ctx.moveTo(sx + curbX * 1.5,                sy + curbY * 1.5);
  ctx.lineTo(sx + curbX * (C.ROAD_WIDTH / 2), sy + curbY * (C.ROAD_WIDTH / 2));
  ctx.stroke();
}

function drawThreeAspectHead(ctx, x, y, angle, activeColor) {
  const hw = 10, hh = 26, r = 2.8;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle + Math.PI / 2);

  // Housing
  roundRect(ctx, -hw/2, -hh/2, hw, hh, 5, '#090d16', '#475569', 1);

  const yRed = -7.5, yYellow = 0, yGreen = 7.5;

  // Red lamp
  if (activeColor === 'RED') {
    ctx.fillStyle = 'rgba(239,68,68,0.35)';
    circle(ctx, 0, yRed, r + 2.5); ctx.fill();
    ctx.fillStyle = '#ff2222';
    circle(ctx, 0, yRed, r); ctx.fill();
  } else {
    ctx.fillStyle = '#450a0a';
    circle(ctx, 0, yRed, r); ctx.fill();
  }

  // Yellow lamp
  if (activeColor === 'YELLOW') {
    ctx.fillStyle = 'rgba(245,158,11,0.35)';
    circle(ctx, 0, yYellow, r + 2.5); ctx.fill();
    ctx.fillStyle = '#ffcc00';
    circle(ctx, 0, yYellow, r); ctx.fill();
  } else {
    ctx.fillStyle = '#451a03';
    circle(ctx, 0, yYellow, r); ctx.fill();
  }

  // Green lamp
  if (activeColor === 'GREEN') {
    ctx.fillStyle = 'rgba(16,185,129,0.35)';
    circle(ctx, 0, yGreen, r + 2.5); ctx.fill();
    ctx.fillStyle = '#10e784';
    circle(ctx, 0, yGreen, r); ctx.fill();
  } else {
    ctx.fillStyle = '#064e3b';
    circle(ctx, 0, yGreen, r); ctx.fill();
  }

  ctx.restore();
}

// Route highlight
function drawRouteHighlight(ctx, routePath, map) {
  if (!routePath || routePath.length < 2) return;

  // Glow underlay
  ctx.strokeStyle = 'rgba(14,165,233,0.35)';
  ctx.lineWidth = 16;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.setLineDash([]);
  for (let i = 0; i < routePath.length - 1; i++) {
    const a = intersectionById(map, routePath[i]);
    const b = intersectionById(map, routePath[i + 1]);
    if (!a || !b) continue;
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
  }

  // Dashed neon line
  ctx.strokeStyle = 'rgba(56,189,248,0.95)';
  ctx.lineWidth = 3.5;
  ctx.setLineDash([10, 6]);
  for (let i = 0; i < routePath.length - 1; i++) {
    const a = intersectionById(map, routePath[i]);
    const b = intersectionById(map, routePath[i + 1]);
    if (!a || !b) continue;
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
  }
  ctx.setLineDash([]);

  // Origin / destination markers
  const start = intersectionById(map, routePath[0]);
  const end   = intersectionById(map, routePath[routePath.length - 1]);
  if (start) { ctx.fillStyle = '#10b981'; circle(ctx, start.x, start.y, 8); ctx.fill(); strokeCircle(ctx, start.x, start.y, 8, '#fff', 2); }
  if (end)   { ctx.fillStyle = '#f43f5e'; circle(ctx, end.x,   end.y,   8); ctx.fill(); strokeCircle(ctx, end.x,   end.y,   8, '#fff', 2); }
}

// Vehicle
function drawVehicle(ctx, v, isSelected) {
  const { x, y, headingAngle = 0, type, id } = v;
  const spec = C.VEHICLE_TYPES[type] || C.VEHICLE_TYPES.CAR;
  const { len, w, color } = spec;

  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(headingAngle);

  if (isSelected) {
    ctx.strokeStyle = 'rgba(56,189,248,0.9)'; ctx.lineWidth = 2.5;
    roundRectPath(ctx, -len/2 - 4, -w/2 - 4, len + 8, w + 8, 5);
    ctx.stroke();
  }

  // Shadow
  ctx.fillStyle = 'rgba(0,0,0,0.5)';
  roundRectPath(ctx, -len/2 + 1, -w/2 + 1.5, len, w, 3.5); ctx.fill();

  // Body
  ctx.fillStyle = color;
  roundRectPath(ctx, -len/2, -w/2, len, w, 3.5); ctx.fill();

  // Chassis stroke
  ctx.strokeStyle = 'rgba(2,6,23,0.9)'; ctx.lineWidth = 1;
  roundRectPath(ctx, -len/2, -w/2, len, w, 3.5); ctx.stroke();

  // Windshield
  ctx.fillStyle = 'rgba(2,6,23,0.8)';
  roundRectPath(ctx, 0, -(w * 0.72)/2, len * 0.30, w * 0.72, 2); ctx.fill();

  // Headlights
  ctx.fillStyle = '#fef08a';
  ctx.beginPath(); ctx.ellipse(len/2 - 2.5, -w/2 + 2.1, 1.1, 1.1, 0, 0, Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(len/2 - 2.5,  w/2 - 2.2, 1.1, 1.1, 0, 0, Math.PI*2); ctx.fill();

  // Taillights
  ctx.fillStyle = '#ef4444';
  ctx.beginPath(); ctx.ellipse(-len/2, -w/2 + 2, 1, 1, 0, 0, Math.PI*2); ctx.fill();
  ctx.beginPath(); ctx.ellipse(-len/2,  w/2 - 2, 1, 1, 0, 0, Math.PI*2); ctx.fill();

  ctx.restore();

  // ID label
  ctx.fillStyle = 'rgba(11,19,41,0.88)';
  roundRectPath(ctx, x - 13, y - w/2 - 15, 26, 11, 3); ctx.fill();
  ctx.strokeStyle = color; ctx.lineWidth = 0.8;
  roundRectPath(ctx, x - 13, y - w/2 - 15, 26, 11, 3); ctx.stroke();
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 8px "Segoe UI", sans-serif';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(id, x, y - w/2 - 9.5);
}

// Landmark badge
function drawLandmarkBadge(ctx, inter) {
  const lm = inter.landmark;
  if (!lm) return;

  const { x, y } = inter;
  const pw = 148, ph = 26;

  let pillX, pillY;
  switch (inter.id) {
    case 'J1':  pillX = x - 10;       pillY = y - 56; break;
    case 'J3':  pillX = x - pw + 10;  pillY = y - 56; break;
    case 'J6':  pillX = x + 35;       pillY = y - 48; break;
    case 'J8':  pillX = x - 30;       pillY = y + 42; break;
    case 'J10': pillX = x - pw + 25;  pillY = y + 42; break;
    default:    pillX = x - pw / 2;   pillY = y - 56; break;
  }

  const badgeColor = C.LANDMARK_COLORS[lm.type] || '#64748b';

  roundRectPath(ctx, pillX, pillY, pw, ph, 13);
  ctx.fillStyle = 'rgba(15,23,42,0.95)'; ctx.fill();
  ctx.strokeStyle = badgeColor; ctx.lineWidth = 1.8; ctx.stroke();

  // Icon dot
  ctx.fillStyle = badgeColor;
  ctx.beginPath(); ctx.arc(pillX + 14.5, pillY + 13, 6.5, 0, Math.PI * 2); ctx.fill();

  // Icon code
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 9px "Segoe UI", sans-serif';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(lm.iconCode, pillX + 14.5, pillY + 13);

  // Name label
  ctx.fillStyle = '#f1f5f9';
  ctx.font = '600 10.5px "Segoe UI", sans-serif';
  ctx.textAlign = 'left';
  ctx.fillText(lm.name, pillX + 27, pillY + 13);

  // Connector stem
  ctx.strokeStyle = badgeColor; ctx.lineWidth = 1.5;
  ctx.beginPath();
  if (pillY < y) { ctx.moveTo(pillX + pw/2, pillY + ph); ctx.lineTo(x, y - 28); }
  else           { ctx.moveTo(pillX + pw/2, pillY);       ctx.lineTo(x, y + 28); }
  ctx.stroke();
}

// ─── Canvas drawing helpers ────────────────────────────────────────────────
function roundRectPath(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

function roundRect(ctx, x, y, w, h, r, fill, stroke, lineWidth) {
  roundRectPath(ctx, x, y, w, h, r);
  if (fill)   { ctx.fillStyle = fill;     ctx.fill(); }
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lineWidth || 1; ctx.stroke(); }
}

function circle(ctx, x, y, r) {
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2);
}

function strokeCircle(ctx, x, y, r, color, lw) {
  ctx.strokeStyle = color; ctx.lineWidth = lw;
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke();
}

// ─── Map data helpers ──────────────────────────────────────────────────────
function intersectionById(map, id) {
  return map.intersections.find(i => i.id === id);
}

function getConnectedRoads(map, interId) {
  return map.roads.filter(r => r.fromId === interId || r.toId === interId);
}

// ─── WebSocket connection ─────────────────────────────────────────────────
function connectWS() {
  if (state.ws) {
    try { state.ws.close(); } catch (e) {}
    state.ws = null;
  }

  setStatus('connecting', 'Connecting…');
  state.ws = new WebSocket(WS_URL);

  state.ws.addEventListener('open', () => {
    console.log('[WS] Connected');
    state.wsConnected = true;
    state.wsAttempts  = 0;
    setStatus('connected', 'Live');
    overlay.classList.add('hidden');
    if (state.reconnectTimer) { clearTimeout(state.reconnectTimer); state.reconnectTimer = null; }
  });

  state.ws.addEventListener('message', e => {
    try {
      const snap = JSON.parse(e.data);
      state.simTime = snap.t || 0;
      state.paused  = snap.paused || false;
      state.vehicles = snap.vehicles || [];
      state.signals  = snap.signals  || {};
      state.roads    = snap.roads    || [];

      simClock.textContent = '⏱ ' + formatTime(state.simTime);
      btnPause.textContent = state.paused ? '▶ Resume' : '⏸ Pause';

      updateStats();
      updateFleetUI();
      redraw();
    } catch (err) {
      console.error('[WS] Parse error:', err);
    }
  });

  state.ws.addEventListener('close', () => {
    console.log('[WS] Disconnected — will reconnect');
    state.wsConnected = false;
    setStatus('error', 'Reconnecting…');
    scheduleReconnect();
  });

  state.ws.addEventListener('error', () => {
    state.wsConnected = false;
    setStatus('error', 'Connection error');
    scheduleReconnect();
  });
}

function scheduleReconnect() {
  if (state.reconnectTimer) return;
  const delay = Math.min(2000 * (1 + state.wsAttempts * 0.5), 10000);
  state.wsAttempts++;
  state.reconnectTimer = setTimeout(() => {
    state.reconnectTimer = null;
    connectWS();
  }, delay);
}

// ─── REST API calls ────────────────────────────────────────────────────────
async function fetchMap() {
  try {
    const res = await fetch(API_BASE + '/map');
    if (!res.ok) throw new Error('Status ' + res.status);
    state.map = await res.json();
    populateIntersectionSelects();
    redraw();
    return true;
  } catch (e) {
    console.error('[API] Map fetch failed:', e);
    return false;
  }
}

async function probeBackend() {
  overlay.classList.remove('hidden');
  const MAX = 15;
  for (let attempt = 1; attempt <= MAX; attempt++) {
    coldAttempt.textContent = `Attempt ${attempt} / ${MAX}`;
    try {
      const res = await fetch(API_BASE + '/status', { signal: AbortSignal.timeout(5000) });
      if (res.ok) {
        console.log('[App] Backend reachable');
        overlay.classList.add('hidden');
        return true;
      }
    } catch (e) {
      console.log(`[App] Probe attempt ${attempt} failed:`, e.message);
    }
    await sleep(2000);
  }
  coldAttempt.textContent = 'Backend unreachable — check Render dashboard.';
  return false;
}

async function spawnVehicle() {
  const type = vehType.value;
  const from = vehFrom.value;
  const to   = vehTo.value;
  if (!from || !to || from === to) {
    showSpawnMsg('Choose different source and destination.', true);
    return;
  }

  btnSpawn.disabled = true;
  showSpawnMsg('Spawning…', false);

  try {
    const res = await fetch(API_BASE + '/spawn', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ type, from, to }),
    });
    const data = await res.json();
    if (res.ok) {
      showSpawnMsg(`✓ ${data.id} spawned (${data.routePath?.join(' → ')})`, false);
    } else {
      showSpawnMsg(data.error || 'Spawn failed.', true);
    }
  } catch (e) {
    showSpawnMsg('Network error: ' + e.message, true);
  } finally {
    btnSpawn.disabled = false;
  }
}

async function sendControl(action, extra = {}) {
  try {
    await fetch(API_BASE + '/control', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action, ...extra }),
    });
  } catch (e) { console.error('[API] control error:', e); }
}

async function sendCongestion(body) {
  try {
    await fetch(API_BASE + '/congestion', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch (e) { console.error('[API] congestion error:', e); }
}

async function previewRoute() {
  const from = vehFrom.value;
  const to   = vehTo.value;
  if (!from || !to || from === to) { routePreview.classList.add('hidden'); return; }
  try {
    const res = await fetch(API_BASE + '/route', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ from, to }),
    });
    if (res.ok) {
      const d = await res.json();
      if (d.found) {
        routePreview.classList.remove('hidden');
        routePreview.textContent = `Route: ${d.path.join(' → ')} (${d.totalDistance.toFixed(0)} m)`;
      }
    }
  } catch (e) {}
}

// ─── UI helpers ────────────────────────────────────────────────────────────
function setStatus(cls, text) {
  statusPill.className = 'status-pill ' + cls;
  statusText.textContent = text;
}

function formatTime(s) {
  const m = Math.floor(s / 60), sec = Math.floor(s % 60);
  return `${String(m).padStart(2,'0')}:${String(sec).padStart(2,'0')}`;
}

function showSpawnMsg(msg, isErr) {
  spawnMsg.textContent = msg;
  spawnMsg.className = 'spawn-msg' + (isErr ? ' err' : '');
  setTimeout(() => { spawnMsg.textContent = ''; }, 6000);
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// Populate intersection dropdowns from map data
function populateIntersectionSelects() {
  if (!state.map) return;
  const opts = state.map.intersections
    .map(i => `<option value="${i.id}">${i.id} — ${i.name}</option>`)
    .join('');
  vehFrom.innerHTML = opts;
  vehTo.innerHTML   = opts;
  // Default to different selections
  if (state.map.intersections.length > 1) {
    vehFrom.selectedIndex = 0;
    vehTo.selectedIndex   = state.map.intersections.length - 1;
  }
  previewRoute();
}

// Update live stats
function updateStats() {
  const total   = state.vehicles.length;
  const moving  = state.vehicles.filter(v => v.status === 'MOVING').length;
  const stopped = state.vehicles.filter(v => v.status === 'STOPPED_AT_SIGNAL' || v.status === 'WAITING').length;
  const done    = state.vehicles.filter(v => v.status === 'COMPLETED').length;
  document.getElementById('statTotal').textContent   = total;
  document.getElementById('statMoving').textContent  = moving;
  document.getElementById('statStopped').textContent = stopped;
  document.getElementById('statDone').textContent    = done;
}

// Update fleet panel
function updateFleetUI() {
  const active = state.vehicles.filter(v => v.status !== 'COMPLETED');
  if (active.length === 0) {
    fleetList.innerHTML = '<div class="fleet-empty">No active vehicles. Spawn one above.</div>';
    return;
  }

  const html = active.map(v => {
    const spec = C.VEHICLE_TYPES[v.type] || C.VEHICLE_TYPES.CAR;
    const isSelected = v.id === state.selectedId;
    const progress = (v.progressPercent || 0).toFixed(0);
    const statusColor = v.status === 'MOVING' ? '#10b981' : v.status === 'STOPPED_AT_SIGNAL' ? '#ef4444' : '#f59e0b';
    const statusLabel = { MOVING: 'Moving', STOPPED_AT_SIGNAL: 'At Signal', WAITING: 'Waiting' }[v.status] || v.status;
    const route = v.routePath?.length >= 2 ? `${v.routePath[0]} → ${v.routePath[v.routePath.length - 1]}` : '—';
    return `
      <div class="fleet-card ${isSelected ? 'selected' : ''}" data-id="${v.id}">
        <div class="fleet-card-top">
          <span style="color:${spec.color}">${spec.emoji} <span class="fleet-id">${v.id}</span></span>
          <span class="fleet-badge" style="color:${statusColor};border-color:${statusColor}">${statusLabel}</span>
        </div>
        <div class="fleet-route">${route} · ${progress}%</div>
        <div class="fleet-progress"><div class="fleet-progress-bar" style="width:${progress}%;background:${spec.color}"></div></div>
      </div>`;
  }).join('');

  fleetList.innerHTML = html;

  // Attach click handlers
  fleetList.querySelectorAll('.fleet-card').forEach(card => {
    card.addEventListener('click', () => {
      state.selectedId = card.dataset.id === state.selectedId ? null : card.dataset.id;
      updateFleetUI();
      redraw();
    });
  });
}

// ─── Event listeners ───────────────────────────────────────────────────────
btnPause.addEventListener('click', () => {
  sendControl(state.paused ? 'resume' : 'pause');
});

btnReset.addEventListener('click', () => {
  if (confirm('Reset the simulation? All vehicles will be cleared.')) {
    sendControl('reset');
  }
});

btnSpawn.addEventListener('click', spawnVehicle);

vehFrom.addEventListener('change', previewRoute);
vehTo.addEventListener('change', previewRoute);

// Congestion buttons
document.querySelectorAll('.cong-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const action = btn.dataset.action;
    let body;
    if (action === 'rush_hour' || action === 'clear_all') {
      body = { action };
    } else if (action.startsWith('close_')) {
      body = { roadId: action.substring(6).toUpperCase(), condition: 'CLOSED' };
    } else if (action.startsWith('congest_')) {
      body = { roadId: action.substring(8).toUpperCase(), condition: 'CONGESTED' };
    } else if (action.startsWith('normal_')) {
      body = { roadId: action.substring(7).toUpperCase(), condition: 'NORMAL' };
    }
    if (body) sendCongestion(body);
  });
});

// Speed buttons
document.querySelectorAll('.speed-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const speed = parseFloat(btn.dataset.speed);
    sendControl('speed', { value: speed });
    document.querySelectorAll('.speed-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
  });
});

// ─── Boot sequence ────────────────────────────────────────────────────────
(async () => {
  resizeCanvas();

  // Probe backend until alive (handles Render cold start)
  const alive = await probeBackend();
  if (!alive) return;

  // Fetch static map data
  await fetchMap();

  // Connect WebSocket for live updates
  connectWS();
})();
