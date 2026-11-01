package com.traffic.core.model;

import java.util.ArrayList;
import java.util.List;

/**
 * Represents an intersection (junction) in the city grid.
 * Holds its spatial coordinates (x, y) and an associated TrafficSignal.
 */
public class Intersection {
    private final String id;
    private final String name;
    private final double x;
    private final double y;
    private final TrafficSignal signal;
    private final List<Road> connectedRoads;
    private final java.util.Map<String, TrafficSignal> approachSignals;
    private Landmark landmark;

    public Intersection(String id, String name, double x, double y) {
        this.id = id;
        this.name = name;
        this.x = x;
        this.y = y;
        this.signal = new TrafficSignal("SIG-" + id);
        this.connectedRoads = new ArrayList<>();
        this.approachSignals = new java.util.LinkedHashMap<>();
        this.landmark = null;
    }

    public java.util.Map<String, TrafficSignal> getApproachSignals() {
        return approachSignals;
    }

    public java.util.Collection<TrafficSignal> getAllApproachSignals() {
        return approachSignals.values();
    }

    public TrafficSignal getApproachSignal(String roadId) {
        return approachSignals.computeIfAbsent(roadId, rId -> new TrafficSignal("SIG-" + id + "-" + rId, rId));
    }

    public Landmark getLandmark() {
        return landmark;
    }

    public void setLandmark(Landmark landmark) {
        this.landmark = landmark;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public double getX() {
        return x;
    }

    public double getY() {
        return y;
    }

    public TrafficSignal getSignal() {
        return signal;
    }

    public List<Road> getConnectedRoads() {
        return connectedRoads;
    }

    public void addConnectedRoad(Road road) {
        if (!connectedRoads.contains(road)) {
            connectedRoads.add(road);
        }
    }

    @Override
    public String toString() {
        return "Intersection{" + "id='" + id + '\'' + ", name='" + name + '\'' + '}';
    }
}
