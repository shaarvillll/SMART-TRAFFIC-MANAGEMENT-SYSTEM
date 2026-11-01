package com.traffic.desktop;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import com.traffic.core.model.RoadCondition;
import com.traffic.core.model.SignalColor;
import com.traffic.core.vehicle.Vehicle;
import com.traffic.core.vehicle.VehicleStatus;
import com.traffic.core.vehicle.VehicleType;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.WebSocket;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/**
 * HTTP + WebSocket client that connects the JavaFX desktop simulator to the
 * deployed backend at https://smart-traffic-management-system-xtar.onrender.com
 *
 * Usage:
 *   BackendClient client = new BackendClient(backendHttpUrl);
 *   client.connect();               // async – non-blocking
 *   client.setOnLiveUpdate(snap -> { ... });   // receive 200ms snapshots
 *   client.spawnVehicle(type, from, to);       // POST /api/spawn
 *   client.sendControl("pause");               // POST /api/control
 */
public class BackendClient {

    /** Default production backend URL. Override via system property or constructor arg. */
    public static final String DEFAULT_BACKEND_URL =
            System.getProperty("BACKEND_URL",
                    "https://smart-traffic-management-system-xtar.onrender.com");

    // ───── Connection status enum ─────────────────────────────────────────────
    public enum Status { CONNECTING, CONNECTED, DISCONNECTED, ERROR }

    // ───── Snapshot from WS push ─────────────────────────────────────────────
    public record LiveSnapshot(
            double simulationTime,
            boolean paused,
            List<RemoteVehicle> vehicles,
            Map<String, Map<String, String>> signals,   // intersectionId → {roadId → "GREEN"|"RED"|"YELLOW"}
            List<RemoteRoad> roads
    ) {}

    /** Lightweight vehicle data received from the backend. */
    public static class RemoteVehicle {
        public String id, type, status, sourceId, destinationId;
        public double x, y, headingAngle, speed, progressPercent;
        public List<String> routePath = List.of();
    }

    /** Lightweight road data received from the backend. */
    public static class RemoteRoad {
        public String id, condition;
    }

    // ───── Internals ──────────────────────────────────────────────────────────
    private final String httpBaseUrl;
    private final String wsLiveUrl;
    private final HttpClient http;
    private final ObjectMapper mapper = new ObjectMapper();
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
        Thread t = new Thread(r, "backend-ws-reconnect");
        t.setDaemon(true);
        return t;
    });

    private volatile Status status = Status.DISCONNECTED;
    private WebSocket webSocket;
    private final StringBuilder wsBuffer = new StringBuilder();
    private final AtomicBoolean reconnecting = new AtomicBoolean(false);

    // Callbacks set by TrafficDesktopApp
    private Consumer<LiveSnapshot> onLiveUpdate;
    private Consumer<Status> onStatusChange;

    // ───── Constructor ────────────────────────────────────────────────────────
    public BackendClient(String backendUrl) {
        String trimmed = backendUrl.trim();
        if (trimmed.endsWith("/")) trimmed = trimmed.substring(0, trimmed.length() - 1);

        this.httpBaseUrl = trimmed + "/api";
        boolean secure = trimmed.startsWith("https://");
        String wsBase = (secure ? "wss://" : "ws://") + trimmed.replaceFirst("^https?://", "");
        this.wsLiveUrl = wsBase + "/ws/live";

        this.http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    // ───── Public API ─────────────────────────────────────────────────────────
    public void setOnLiveUpdate(Consumer<LiveSnapshot> cb)  { this.onLiveUpdate  = cb; }
    public void setOnStatusChange(Consumer<Status> cb)      { this.onStatusChange = cb; }
    public Status getStatus() { return status; }

    /** Probe the /api/status endpoint and start the WebSocket connection. */
    public CompletableFuture<Boolean> connect() {
        setStatus(Status.CONNECTING);
        return probeStatus()
                .thenCompose(ok -> {
                    if (ok) {
                        openWebSocket();
                        return CompletableFuture.completedFuture(true);
                    } else {
                        setStatus(Status.ERROR);
                        return CompletableFuture.completedFuture(false);
                    }
                });
    }

    /** Probe just the /api/status endpoint. */
    public CompletableFuture<Boolean> probeStatus() {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(httpBaseUrl + "/status"))
                .timeout(Duration.ofSeconds(8))
                .GET().build();
        return http.sendAsync(req, HttpResponse.BodyHandlers.ofString())
                .thenApply(r -> r.statusCode() == 200)
                .exceptionally(e -> false);
    }

    /** Fetch the full city map. Returns null on error. */
    public Map<String, Object> fetchMap() {
        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(httpBaseUrl + "/map"))
                    .timeout(Duration.ofSeconds(8))
                    .GET().build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() == 200) {
                return mapper.readValue(res.body(), new TypeReference<Map<String, Object>>() {});
            }
        } catch (Exception e) {
            System.err.println("[BackendClient] fetchMap error: " + e.getMessage());
        }
        return null;
    }

    /** POST /api/spawn — spawn a vehicle on the backend. Returns the vehicle JSON or null. */
    public Map<String, Object> spawnVehicle(String type, String from, String to) {
        try {
            Map<String, String> body = Map.of("type", type, "from", from, "to", to);
            String json = mapper.writeValueAsString(body);
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(httpBaseUrl + "/spawn"))
                    .timeout(Duration.ofSeconds(8))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json))
                    .build();
            HttpResponse<String> res = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (res.statusCode() == 201) {
                return mapper.readValue(res.body(), new TypeReference<Map<String, Object>>() {});
            } else {
                System.err.println("[BackendClient] spawn failed (" + res.statusCode() + "): " + res.body());
            }
        } catch (Exception e) {
            System.err.println("[BackendClient] spawnVehicle error: " + e.getMessage());
        }
        return null;
    }

    /** POST /api/control — send control action: pause | resume | reset | speed. */
    public void sendControl(String action) {
        sendControl(action, null);
    }

    public void sendControl(String action, Double speedValue) {
        try {
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("action", action);
            if (speedValue != null) body.put("value", speedValue);
            String json = mapper.writeValueAsString(body);
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(httpBaseUrl + "/control"))
                    .timeout(Duration.ofSeconds(5))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json))
                    .build();
            http.sendAsync(req, HttpResponse.BodyHandlers.ofString()); // fire-and-forget
        } catch (Exception e) {
            System.err.println("[BackendClient] sendControl error: " + e.getMessage());
        }
    }

    /** POST /api/congestion */
    public void sendCongestion(String action) {
        try {
            String json = mapper.writeValueAsString(Map.of("action", action));
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(httpBaseUrl + "/congestion"))
                    .timeout(Duration.ofSeconds(5))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json))
                    .build();
            http.sendAsync(req, HttpResponse.BodyHandlers.ofString());
        } catch (Exception e) {
            System.err.println("[BackendClient] sendCongestion error: " + e.getMessage());
        }
    }

    public void disconnect() {
        if (webSocket != null && !webSocket.isInputClosed()) {
            webSocket.sendClose(WebSocket.NORMAL_CLOSURE, "desktop closed");
        }
        scheduler.shutdownNow();
    }

    // ───── WebSocket ──────────────────────────────────────────────────────────
    private void openWebSocket() {
        if (webSocket != null && !webSocket.isInputClosed()) return;
        System.out.println("[BackendClient] Connecting WS → " + wsLiveUrl);
        http.newWebSocketBuilder()
                .connectTimeout(Duration.ofSeconds(12))
                .buildAsync(URI.create(wsLiveUrl), new WsListener())
                .thenAccept(ws -> {
                    this.webSocket = ws;
                    setStatus(Status.CONNECTED);
                    reconnecting.set(false);
                    System.out.println("[BackendClient] WebSocket connected.");
                })
                .exceptionally(e -> {
                    System.err.println("[BackendClient] WebSocket connect error: " + e.getMessage());
                    setStatus(Status.DISCONNECTED);
                    scheduleReconnect();
                    return null;
                });
    }

    private void scheduleReconnect() {
        if (reconnecting.compareAndSet(false, true)) {
            scheduler.schedule(() -> {
                reconnecting.set(false);
                openWebSocket();
            }, 5, TimeUnit.SECONDS);
        }
    }

    private void setStatus(Status s) {
        this.status = s;
        if (onStatusChange != null) onStatusChange.accept(s);
    }

    // ───── WS message parsing ─────────────────────────────────────────────────
    @SuppressWarnings("unchecked")
    private void handleWsMessage(String text) {
        try {
            Map<String, Object> raw = mapper.readValue(text, new TypeReference<Map<String, Object>>() {});

            double t = raw.containsKey("t") ? ((Number) raw.get("t")).doubleValue() : 0.0;
            boolean paused = Boolean.TRUE.equals(raw.get("paused"));

            // Vehicles
            List<RemoteVehicle> vehicles = new ArrayList<>();
            List<?> rawVehicles = (List<?>) raw.getOrDefault("vehicles", List.of());
            for (Object rv : rawVehicles) {
                Map<String, Object> vm = (Map<String, Object>) rv;
                RemoteVehicle v = new RemoteVehicle();
                v.id             = (String) vm.get("id");
                v.type           = (String) vm.getOrDefault("type", "CAR");
                v.status         = (String) vm.getOrDefault("status", "MOVING");
                v.sourceId       = (String) vm.getOrDefault("sourceId", "");
                v.destinationId  = (String) vm.getOrDefault("destinationId", "");
                v.x              = ((Number) vm.getOrDefault("x", 0)).doubleValue();
                v.y              = ((Number) vm.getOrDefault("y", 0)).doubleValue();
                v.headingAngle   = ((Number) vm.getOrDefault("headingAngle", 0)).doubleValue();
                v.speed          = ((Number) vm.getOrDefault("speed", 0)).doubleValue();
                v.progressPercent = ((Number) vm.getOrDefault("progressPercent", 0)).doubleValue();
                List<?> rp = (List<?>) vm.getOrDefault("routePath", List.of());
                v.routePath = rp.stream().map(Object::toString).toList();
                vehicles.add(v);
            }

            // Signals  { "J2": { "R1": "GREEN", "R3": "RED" } }
            Map<String, Map<String, String>> signals = new LinkedHashMap<>();
            Map<String, Object> rawSigs = (Map<String, Object>) raw.getOrDefault("signals", Map.of());
            for (Map.Entry<String, Object> e : rawSigs.entrySet()) {
                Map<String, Object> roadMap = (Map<String, Object>) e.getValue();
                Map<String, String> parsed = new LinkedHashMap<>();
                for (Map.Entry<String, Object> re : roadMap.entrySet()) {
                    parsed.put(re.getKey(), re.getValue().toString());
                }
                signals.put(e.getKey(), parsed);
            }

            // Roads
            List<RemoteRoad> roads = new ArrayList<>();
            List<?> rawRoads = (List<?>) raw.getOrDefault("roads", List.of());
            for (Object rr : rawRoads) {
                Map<String, Object> rm = (Map<String, Object>) rr;
                RemoteRoad road = new RemoteRoad();
                road.id        = (String) rm.get("id");
                road.condition = (String) rm.getOrDefault("condition", "NORMAL");
                roads.add(road);
            }

            LiveSnapshot snap = new LiveSnapshot(t, paused, vehicles, signals, roads);
            if (onLiveUpdate != null) onLiveUpdate.accept(snap);

        } catch (Exception e) {
            System.err.println("[BackendClient] parse error: " + e.getMessage());
        }
    }

    // ───── WebSocket.Listener ─────────────────────────────────────────────────
    private class WsListener implements WebSocket.Listener {
        @Override
        public void onOpen(WebSocket webSocket) {
            webSocket.request(1);
        }

        @Override
        public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            wsBuffer.append(data);
            if (last) {
                String msg = wsBuffer.toString();
                wsBuffer.setLength(0);
                handleWsMessage(msg);
            }
            webSocket.request(1);
            return null;
        }

        @Override
        public CompletionStage<?> onClose(WebSocket webSocket, int statusCode, String reason) {
            System.out.println("[BackendClient] WS closed: " + statusCode + " " + reason);
            setStatus(Status.DISCONNECTED);
            scheduleReconnect();
            return null;
        }

        @Override
        public void onError(WebSocket webSocket, Throwable error) {
            System.err.println("[BackendClient] WS error: " + error.getMessage());
            setStatus(Status.DISCONNECTED);
            scheduleReconnect();
        }
    }

    // ───── Helpers ────────────────────────────────────────────────────────────

    /**
     * Applies signal states from a live snapshot to the local CityMap's TrafficSignal objects.
     * This updates the signals that MapCanvasRenderer reads for rendering.
     */
    public void applySignals(CityMap cityMap, Map<String, Map<String, String>> signals) {
        if (signals == null || signals.isEmpty()) return;
        for (Map.Entry<String, Map<String, String>> entry : signals.entrySet()) {
            String intersectionId = entry.getKey();
            Intersection node = cityMap.getIntersection(intersectionId);
            if (node == null) continue;
            Map<String, String> roadColors = entry.getValue();
            for (Map.Entry<String, String> re : roadColors.entrySet()) {
                String roadId = re.getKey();
                String colorName = re.getValue();
                SignalColor color;
                try {
                    color = SignalColor.valueOf(colorName);
                } catch (IllegalArgumentException ex) {
                    color = SignalColor.RED;
                }
                node.getApproachSignal(roadId).setState(color);
            }
        }
    }

    /**
     * Applies road conditions from a live snapshot to the local CityMap.
     */
    public void applyRoadConditions(CityMap cityMap, List<RemoteRoad> roads) {
        if (roads == null) return;
        for (RemoteRoad rr : roads) {
            Road road = cityMap.getRoad(rr.id);
            if (road != null) {
                try {
                    road.setCondition(RoadCondition.valueOf(rr.condition.toUpperCase()));
                } catch (Exception ignored) {}
            }
        }
    }

    /**
     * Converts a list of RemoteVehicle snapshots into lightweight GhostVehicle objects
     * that the MapCanvasRenderer can draw without needing the full Route graph.
     */
    public List<GhostVehicle> toGhostVehicles(CityMap cityMap, List<RemoteVehicle> remotes) {
        List<GhostVehicle> out = new ArrayList<>();
        for (RemoteVehicle rv : remotes) {
            if ("COMPLETED".equalsIgnoreCase(rv.status)) continue;
            VehicleType vt;
            try { vt = VehicleType.valueOf(rv.type.toUpperCase()); }
            catch (Exception e) { vt = VehicleType.CAR; }

            VehicleStatus vs;
            try { vs = VehicleStatus.valueOf(rv.status.toUpperCase()); }
            catch (Exception e) { vs = VehicleStatus.MOVING; }

            Intersection src  = cityMap.getIntersection(rv.sourceId);
            Intersection dest = cityMap.getIntersection(rv.destinationId);

            out.add(new GhostVehicle(rv.id, vt, vs, rv.x, rv.y, rv.headingAngle,
                    rv.progressPercent, rv.routePath, src, dest));
        }
        return out;
    }
}
