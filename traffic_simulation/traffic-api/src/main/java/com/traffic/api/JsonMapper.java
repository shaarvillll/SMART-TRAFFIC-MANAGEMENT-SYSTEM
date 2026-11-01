package com.traffic.api;

import com.traffic.core.model.*;
import com.traffic.core.routing.Route;
import com.traffic.core.signal.SignalPlan;
import com.traffic.core.signal.SignalState;
import com.traffic.core.vehicle.Vehicle;

import java.util.*;

/**
 * Converts core simulation objects to plain Map/List structures
 * that Jackson will serialize to JSON for the Flutter client.
 */
public class JsonMapper {

    public static Map<String, Object> intersectionToJson(Intersection i) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", i.getId());
        m.put("name", i.getName());
        m.put("x", i.getX());
        m.put("y", i.getY());
        Landmark lm = i.getLandmark();
        if (lm != null) {
            Map<String, Object> lmMap = new LinkedHashMap<>();
            lmMap.put("id", lm.getId());
            lmMap.put("name", lm.getName());
            lmMap.put("type", lm.getType().name());
            lmMap.put("iconCode", lm.getIconCode());
            m.put("landmark", lmMap);
        } else {
            m.put("landmark", null);
        }
        Map<String, String> signals = new LinkedHashMap<>();
        for (TrafficSignal ts : i.getAllApproachSignals()) {
            String roadKey = ts.getApproachRoadId() != null ? ts.getApproachRoadId() : ts.getId();
            signals.put(roadKey, ts.getState().name());
        }
        m.put("signals", signals);
        return m;
    }

    public static Map<String, Object> roadToJson(Road r) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", r.getId());
        m.put("name", r.getName());
        m.put("fromId", r.getIntersectionA().getId());
        m.put("toId", r.getIntersectionB().getId());
        m.put("length", Math.round(r.getLength() * 10.0) / 10.0);
        m.put("type", r.getRoadType().name());
        m.put("condition", r.getCondition().name());
        return m;
    }

    public static Map<String, Object> vehicleToJson(Vehicle v) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", v.getId());
        m.put("type", v.getType().name());
        m.put("status", v.getStatus().name());
        m.put("sourceId", v.getSource().getId());
        m.put("sourceName", v.getSource().getName());
        m.put("destinationId", v.getDestination().getId());
        m.put("destinationName", v.getDestination().getName());
        m.put("x", Math.round(v.getX() * 10.0) / 10.0);
        m.put("y", Math.round(v.getY() * 10.0) / 10.0);
        m.put("speed", Math.round(v.getCurrentSpeed() * 10.0) / 10.0);
        m.put("progressPercent", Math.round(v.getProgressPercentage() * 10.0) / 10.0);
        m.put("waitTimeSec", Math.round(v.getWaitTimeSeconds() * 10.0) / 10.0);
        m.put("tripDurationSec", Math.round(v.getTripDurationSeconds() * 10.0) / 10.0);
        List<String> routePath = new ArrayList<>();
        if (v.getRoute() != null && v.getRoute().getPath() != null) {
            for (Intersection node : v.getRoute().getPath()) {
                routePath.add(node.getId());
            }
        }
        m.put("routePath", routePath);
        return m;
    }

    public static Map<String, Object> signalStateToJson(String junctionId, SignalPlan plan) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("junctionId", junctionId);
        m.put("currentPhase", plan.getCurrentPhaseIndex());
        m.put("phaseTimeRemaining", Math.round(plan.getPhaseTimeRemaining() * 10.0) / 10.0);
        Map<String, String> roadStates = new LinkedHashMap<>();
        for (String roadId : plan.getTrackedRoadIds()) {
            SignalState state = plan.getSignalStateForRoad(roadId);
            roadStates.put(roadId, state.name());
        }
        m.put("roadStates", roadStates);
        return m;
    }

    public static Map<String, Object> routeToJson(Route route) {
        Map<String, Object> m = new LinkedHashMap<>();
        if (route == null || !route.isValid()) {
            m.put("found", false);
            return m;
        }
        m.put("found", true);
        m.put("totalDistance", Math.round(route.getTotalDistance() * 10.0) / 10.0);
        m.put("hopCount", route.getHopCount());
        m.put("description", route.getRouteDescription());
        List<String> path = new ArrayList<>();
        for (Intersection node : route.getPath()) path.add(node.getId());
        m.put("path", path);
        List<String> roads = new ArrayList<>();
        for (Road r : route.getRoads()) roads.add(r.getId());
        m.put("roads", roads);
        return m;
    }

    public static Map<String, Object> mapSnapshot(Collection<Intersection> intersections, Collection<Road> roads) {
        Map<String, Object> m = new LinkedHashMap<>();
        List<Map<String, Object>> iList = new ArrayList<>();
        for (Intersection i : intersections) iList.add(intersectionToJson(i));
        List<Map<String, Object>> rList = new ArrayList<>();
        for (Road r : roads) rList.add(roadToJson(r));
        m.put("intersections", iList);
        m.put("roads", rList);
        return m;
    }
}