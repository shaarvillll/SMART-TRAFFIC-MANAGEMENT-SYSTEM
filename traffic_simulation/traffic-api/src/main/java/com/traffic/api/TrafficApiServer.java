package com.traffic.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import com.traffic.core.model.RoadCondition;
import com.traffic.core.routing.Route;
import com.traffic.core.signal.SignalPlan;
import com.traffic.core.vehicle.Vehicle;
import com.traffic.core.vehicle.VehicleType;
import io.javalin.Javalin;
import io.javalin.websocket.WsContext;

import java.util.*;
import java.util.concurrent.*;

/**
 * Javalin REST + WebSocket API Server (port 7070).
 * GET  /api/status    - server health
 * GET  /api/map       - full city map
 * GET  /api/signals   - live signal states
 * GET  /api/vehicles  - live vehicle list
 * POST /api/route     - Dijkstra route
 * POST /api/spawn     - spawn vehicle
 * POST /api/control   - pause/resume/reset/speed
 * WS   /ws/live       - push updates every 200ms
 */
public class TrafficApiServer {

    private static final int PORT =
            Integer.parseInt(System.getenv().getOrDefault("PORT", "7070"));
    private static final int WS_PUSH_MS = 200;

    private static final Set<WsContext> wsClients = ConcurrentHashMap.newKeySet();
    private static final ObjectMapper jackson = new ObjectMapper();
    private static final ScheduledExecutorService wsPusher =
            Executors.newSingleThreadScheduledExecutor(r -> {
                Thread t = new Thread(r, "ws-pusher");
                t.setDaemon(true);
                return t;
            });

    public static void main(String[] args) {
        SimulationEngine engine = SimulationEngine.getInstance();
        engine.start();

        Javalin app = Javalin.create(cfg ->
            cfg.bundledPlugins.enableCors(cors -> cors.addRule(it -> it.anyHost()))
        );

        // Status
        app.get("/api/status", ctx -> ctx.json(Map.of(
                "running", true,
                "paused", engine.isPaused(),
                "timeScale", engine.getTimeScale(),
                "simulationTime", Math.round(engine.getSignalController().getSimulationTime() * 10.0) / 10.0,
                "vehicleCount", engine.getVehicleManager().getVehicles().size()
        )));

        // Map
        app.get("/api/map", ctx -> {
            CityMap map = engine.getCityMap();
            ctx.json(JsonMapper.mapSnapshot(map.getIntersections().values(), map.getRoads()));
        });

        // Signals
        app.get("/api/signals", ctx -> {
            Map<String, Object> result = new LinkedHashMap<>();
            result.put("simulationTime", Math.round(engine.getSignalController().getSimulationTime() * 10.0) / 10.0);
            List<Map<String, Object>> plans = new ArrayList<>();
            for (Map.Entry<String, SignalPlan> e : engine.getSignalController().getPlans().entrySet()) {
                plans.add(JsonMapper.signalStateToJson(e.getKey(), e.getValue()));
            }
            result.put("plans", plans);
            ctx.json(result);
        });

        // Vehicles
        app.get("/api/vehicles", ctx -> {
            List<Map<String, Object>> list = new ArrayList<>();
            for (Vehicle v : engine.getVehicleManager().getVehicles()) {
                list.add(JsonMapper.vehicleToJson(v));
            }
            ctx.json(list);
        });

        // Route
        app.post("/api/route", ctx -> {
            Map<?, ?> body = ctx.bodyAsClass(Map.class);
            String from = (String) body.get("from");
            String to   = (String) body.get("to");
            if (from == null || to == null) {
                ctx.status(400).json(Map.of("error", "from and to are required"));
                return;
            }
            Route route = engine.getRouteFinder().findShortestRoute(engine.getCityMap(), from, to);
            ctx.json(JsonMapper.routeToJson(route));
        });

        // Spawn
        app.post("/api/spawn", ctx -> {
            Map<?, ?> body = ctx.bodyAsClass(Map.class);
            Object typeVal = body.get("type");
            String typeStr = (typeVal != null) ? typeVal.toString() : "CAR";
            String from    = (String) body.get("from");
            String to      = (String) body.get("to");
            if (from == null || to == null) {
                ctx.status(400).json(Map.of("error", "from and to are required"));
                return;
            }
            VehicleType type;
            try {
                type = VehicleType.valueOf(typeStr.toUpperCase());
            } catch (IllegalArgumentException e) {
                ctx.status(400).json(Map.of("error", "Invalid type. Use CAR, BUS, or TRUCK"));
                return;
            }
            CityMap map = engine.getCityMap();
            Intersection src  = map.getIntersection(from);
            Intersection dest = map.getIntersection(to);
            if (src == null || dest == null) {
                ctx.status(404).json(Map.of("error", "Unknown intersection id"));
                return;
            }
            Route route = engine.getRouteFinder().findShortestRoute(map, from, to);
            if (route == null || !route.isValid() || route.isEmpty()) {
                ctx.status(422).json(Map.of("error", "No route found between " + from + " and " + to));
                return;
            }
            try {
                Vehicle v = engine.getVehicleManager().spawnVehicle(type, src, dest, route);
                ctx.status(201).json(JsonMapper.vehicleToJson(v));
            } catch (IllegalArgumentException e) {
                ctx.status(422).json(Map.of("error", e.getMessage()));
            }
        });

        // Control
        app.post("/api/control", ctx -> {
            Map<?, ?> body = ctx.bodyAsClass(Map.class);
            Object actVal = body.get("action");
            String action = (actVal != null) ? actVal.toString() : "";
            switch (action.toLowerCase()) {
                case "pause"  -> engine.setPaused(true);
                case "resume" -> engine.setPaused(false);
                case "reset"  -> engine.reset();
                case "speed"  -> {
                    Object val = body.get("value");
                    if (val instanceof Number) engine.setTimeScale(((Number) val).doubleValue());
                }
                default -> { ctx.status(400).json(Map.of("error", "Unknown action")); return; }
            }
            ctx.json(Map.of("ok", true, "action", action,
                    "paused", engine.isPaused(), "timeScale", engine.getTimeScale()));
        });

        // Congestion control endpoint
        app.post("/api/congestion", ctx -> {
            Map<?, ?> body = ctx.bodyAsClass(Map.class);
            String action = (String) body.get("action");
            CityMap map = engine.getCityMap();

            if ("rush_hour".equalsIgnoreCase(action)) {
                Road r8 = map.getRoad("R8");
                if (r8 != null) r8.setCondition(com.traffic.core.model.RoadCondition.CONGESTED);
                Road r5 = map.getRoad("R5");
                if (r5 != null) r5.setCondition(com.traffic.core.model.RoadCondition.CONGESTED);
                Road r16 = map.getRoad("R16");
                if (r16 != null) r16.setCondition(com.traffic.core.model.RoadCondition.CONGESTED);
                ctx.json(Map.of("ok", true, "scenario", "RUSH_HOUR", "congestedRoads", List.of("R8", "R5", "R16")));
                return;
            } else if ("clear_all".equalsIgnoreCase(action)) {
                for (Road r : map.getRoads()) {
                    r.setCondition(com.traffic.core.model.RoadCondition.NORMAL);
                }
                ctx.json(Map.of("ok", true, "scenario", "ALL_CLEAR"));
                return;
            } else if (body.containsKey("roadId")) {
                String roadId = (String) body.get("roadId");
                String condStr = (String) body.get("condition");
                Road r = map.getRoad(roadId);
                if (r == null) {
                    ctx.status(404).json(Map.of("error", "Road not found: " + roadId));
                    return;
                }
                try {
                    com.traffic.core.model.RoadCondition cond = com.traffic.core.model.RoadCondition.valueOf(condStr.toUpperCase());
                    r.setCondition(cond);
                    ctx.json(Map.of("ok", true, "roadId", roadId, "condition", cond.name()));
                } catch (IllegalArgumentException ex) {
                    ctx.status(400).json(Map.of("error", "Invalid condition: " + condStr));
                }
                return;
            }
            ctx.status(400).json(Map.of("error", "Invalid congestion command"));
        });

        // WebSocket
        app.ws("/ws/live", ws -> {
            ws.onConnect(ctx -> {
                wsClients.add(ctx);
                System.out.println("[WS] Client connected (total=" + wsClients.size() + ")");
            });
            ws.onClose(ctx -> wsClients.remove(ctx));
            ws.onError(ctx -> wsClients.remove(ctx));
        });

        // WS pusher
        wsPusher.scheduleAtFixedRate(() -> {
            if (wsClients.isEmpty()) return;
            try {
                Map<String, Object> snapshot = new LinkedHashMap<>();
                snapshot.put("t", Math.round(engine.getSignalController().getSimulationTime() * 10.0) / 10.0);
                snapshot.put("paused", engine.isPaused());
                List<Map<String, Object>> vList = new ArrayList<>();
                for (Vehicle v : engine.getVehicleManager().getVehicles()) {
                    vList.add(JsonMapper.vehicleToJson(v));
                }
                snapshot.put("vehicles", vList);
                Map<String, Map<String, String>> sigMap = new LinkedHashMap<>();
                for (Map.Entry<String, SignalPlan> e : engine.getSignalController().getPlans().entrySet()) {
                    Map<String, String> roadStates = new LinkedHashMap<>();
                    for (String roadId : e.getValue().getTrackedRoadIds()) {
                        roadStates.put(roadId, e.getValue().getSignalStateForRoad(roadId).name());
                    }
                    sigMap.put(e.getKey(), roadStates);
                }
                snapshot.put("signals", sigMap);

                // Live Road network states (conditions, congestion)
                List<Map<String, Object>> rList = new ArrayList<>();
                for (Road r : engine.getCityMap().getRoads()) {
                    rList.add(JsonMapper.roadToJson(r));
                }
                snapshot.put("roads", rList);

                String json = jackson.writeValueAsString(snapshot);
                for (WsContext client : wsClients) {
                    try { client.send(json); }
                    catch (Exception ignored) { wsClients.remove(client); }
                }
            } catch (Exception e) {
                System.err.println("[WS-Push] Error: " + e.getMessage());
            }
        }, 0, WS_PUSH_MS, TimeUnit.MILLISECONDS);

        app.start(PORT);
        System.out.println("=================================================");
        System.out.println(" Traffic API Server started on port " + PORT);
        System.out.println(" REST:  http://localhost:" + PORT + "/api/");
        System.out.println(" WS:    ws://localhost:"   + PORT + "/ws/live");
        System.out.println("=================================================");
    }
}