package com.traffic.core.signal;

import java.util.Objects;

/**
 * Represents a directional movement through an intersection:
 * from an incoming road to an outgoing road at a specific intersection.
 */
public class TrafficMovement {
    private final String id;
    private final String intersectionId;
    private final String incomingRoadId;
    private final String outgoingRoadId;
    private final String description;

    public TrafficMovement(String id, String intersectionId, String incomingRoadId, String outgoingRoadId, String description) {
        this.id = id;
        this.intersectionId = intersectionId;
        this.incomingRoadId = incomingRoadId;
        this.outgoingRoadId = outgoingRoadId;
        this.description = description;
    }

    public String getId() {
        return id;
    }

    public String getIntersectionId() {
        return intersectionId;
    }

    public String getIncomingRoadId() {
        return incomingRoadId;
    }

    public String getOutgoingRoadId() {
        return outgoingRoadId;
    }

    public String getDescription() {
        return description;
    }

    /**
     * Determines whether this movement conflicts with another movement at the same intersection.
     * Movements conflict if:
     * 1. They originate from different incoming roads, AND
     * 2. Their crossing paths through the intersection conflict.
     */
    public boolean conflictsWith(TrafficMovement other) {
        if (other == null || this.equals(other)) {
            return false;
        }
        if (!this.intersectionId.equals(other.intersectionId)) {
            return false;
        }
        // Same incoming road sharing green is always non-conflicting (queued into common approach)
        if (this.incomingRoadId.equals(other.incomingRoadId)) {
            return false;
        }
        // Movements into the same outgoing road from different approaches merge into one lane (conflict)
        if (this.outgoingRoadId.equals(other.outgoingRoadId)) {
            return true;
        }
        // Opposite straight/through movements across the same roadway axis pass each other safely (non-conflicting)
        if (this.incomingRoadId.equals(other.outgoingRoadId) && this.outgoingRoadId.equals(other.incomingRoadId)) {
            return false;
        }
        // Crossing paths are conflicting
        return true;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        TrafficMovement that = (TrafficMovement) o;
        return Objects.equals(id, that.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }

    @Override
    public String toString() {
        return "TrafficMovement{" + id + ": " + incomingRoadId + " -> " + outgoingRoadId + " (" + description + ")}";
    }
}
