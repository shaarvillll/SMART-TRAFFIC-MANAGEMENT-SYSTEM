package com.traffic.core.model;

/**
 * Traffic signal model attached to an intersection.
 */
public class TrafficSignal {
    private final String id;
    private final String approachRoadId;
    private SignalColor state;
    private double timeInCurrentPhase;

    public TrafficSignal(String id) {
        this(id, null);
    }

    public TrafficSignal(String id, String approachRoadId) {
        this.id = id;
        this.approachRoadId = approachRoadId;
        this.state = SignalColor.RED;
        this.timeInCurrentPhase = 0.0;
    }

    public String getApproachRoadId() {
        return approachRoadId;
    }

    public String getId() {
        return id;
    }

    public SignalColor getState() {
        return state;
    }

    public void setState(SignalColor state) {
        this.state = state;
    }

    public double getTimeInCurrentPhase() {
        return timeInCurrentPhase;
    }

    public void setTimeInCurrentPhase(double timeInCurrentPhase) {
        this.timeInCurrentPhase = timeInCurrentPhase;
    }
}
