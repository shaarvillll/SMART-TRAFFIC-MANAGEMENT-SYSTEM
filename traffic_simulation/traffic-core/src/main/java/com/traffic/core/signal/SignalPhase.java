package com.traffic.core.signal;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * A signal phase represents a group of compatible, non-conflicting traffic movements
 * that receive right-of-way (GREEN) together, followed by YELLOW and ALL-RED clearance.
 */
public class SignalPhase {
    private final String id;
    private final String name;
    private final List<TrafficMovement> allowedMovements;
    private final Set<String> greenRoadIds;
    private final double greenDuration;
    private final double yellowDuration;
    private final double allRedDuration;

    public SignalPhase(String id, String name, List<TrafficMovement> allowedMovements,
                       double greenDuration, double yellowDuration, double allRedDuration) {
        this.id = id;
        this.name = name;
        this.allowedMovements = Collections.unmodifiableList(new ArrayList<>(allowedMovements));
        if (allowedMovements == null || allowedMovements.isEmpty()) {
            throw new IllegalArgumentException("Allowed movements cannot be empty for phase " + id);
        }
        if (greenDuration <= 0.0) {
            throw new IllegalArgumentException("Green duration must be positive: " + greenDuration);
        }
        if (yellowDuration <= 0.0) {
            throw new IllegalArgumentException("Yellow duration must be positive: " + yellowDuration);
        }
        if (allRedDuration < 0.0) {
            throw new IllegalArgumentException("All-red duration cannot be negative: " + allRedDuration);
        }
        this.greenDuration = greenDuration;
        this.yellowDuration = yellowDuration;
        this.allRedDuration = allRedDuration;

        Set<String> roadIds = new HashSet<>();
        for (TrafficMovement tm : allowedMovements) {
            roadIds.add(tm.getIncomingRoadId());
        }
        this.greenRoadIds = Collections.unmodifiableSet(roadIds);

        // Safety assertion: ensure no conflicting movements exist within this phase
        for (int i = 0; i < allowedMovements.size(); i++) {
            for (int j = i + 1; j < allowedMovements.size(); j++) {
                TrafficMovement m1 = allowedMovements.get(i);
                TrafficMovement m2 = allowedMovements.get(j);
                if (m1.conflictsWith(m2)) {
                    throw new IllegalArgumentException("Safety violation: Phase " + id +
                        " contains conflicting movements: " + m1 + " and " + m2);
                }
            }
        }
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public List<TrafficMovement> getAllowedMovements() {
        return allowedMovements;
    }

    public Set<String> getGreenRoadIds() {
        return greenRoadIds;
    }

    public double getGreenDuration() {
        return greenDuration;
    }

    public double getYellowDuration() {
        return yellowDuration;
    }

    public double getAllRedDuration() {
        return allRedDuration;
    }

    public double getTotalPhaseDuration() {
        return greenDuration + yellowDuration + allRedDuration;
    }

    @Override
    public String toString() {
        return "SignalPhase{" + id + ": " + name + " (G:" + greenDuration + "s, Y:" + yellowDuration + "s, R:" + allRedDuration + "s)}";
    }
}
