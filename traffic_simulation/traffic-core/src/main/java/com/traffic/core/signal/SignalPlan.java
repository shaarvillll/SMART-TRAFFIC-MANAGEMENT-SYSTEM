package com.traffic.core.signal;

import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * Stage of phase progression: GREEN (moving), YELLOW (stopping), ALL_RED (clearance).
 */
enum PhaseInterval {
    GREEN,
    YELLOW,
    ALL_RED
}

/**
 * SignalPlan coordinates ordered sequence of signal phases for a specific intersection.
 * Deterministic fixed-time controller advancing via simulation clock.
 */
public class SignalPlan {
    private final String intersectionId;
    private final List<SignalPhase> phases;
    private int currentPhaseIndex;
    private PhaseInterval currentInterval;
    private double timeInInterval;

    public SignalPlan(String intersectionId, List<SignalPhase> phases) {
        if (phases == null || phases.isEmpty()) {
            throw new IllegalArgumentException("Signal plan must contain at least one phase for intersection " + intersectionId);
        }
        this.intersectionId = intersectionId;
        this.phases = Collections.unmodifiableList(new ArrayList<>(phases));
        this.currentPhaseIndex = 0;
        this.currentInterval = PhaseInterval.GREEN;
        this.timeInInterval = 0.0;
    }

    public String getIntersectionId() {
        return intersectionId;
    }

    public List<SignalPhase> getPhases() {
        return phases;
    }

    public int getCurrentPhaseIndex() {
        return currentPhaseIndex;
    }

    public SignalPhase getCurrentPhase() {
        return phases.get(currentPhaseIndex);
    }

    public PhaseInterval getCurrentInterval() {
        return currentInterval;
    }

    public double getTimeInInterval() {
        return timeInInterval;
    }

    public double getRemainingIntervalTime() {
        SignalPhase phase = getCurrentPhase();
        switch (currentInterval) {
            case GREEN:
                return Math.max(0.0, phase.getGreenDuration() - timeInInterval);
            case YELLOW:
                return Math.max(0.0, phase.getYellowDuration() - timeInInterval);
            case ALL_RED:
                return Math.max(0.0, phase.getAllRedDuration() - timeInInterval);
            default:
                return 0.0;
        }
    }

    /**
     * Advance the signal plan by deltaSeconds along the authoritative simulation clock.
     * Transitions deterministically:
     * GREEN -> YELLOW -> ALL_RED -> Next Phase GREEN
     */
    public void step(double deltaSeconds) {
        if (deltaSeconds <= 0.0) return;

        timeInInterval += deltaSeconds;

        boolean advanced = true;
        int maxTransitions = (phases.size() * 3) + 20;
        int iterations = 0;
        while (advanced && iterations++ < maxTransitions) {
            SignalPhase activePhase = getCurrentPhase();
            switch (currentInterval) {
                case GREEN:
                    if (timeInInterval >= activePhase.getGreenDuration()) {
                        timeInInterval -= activePhase.getGreenDuration();
                        currentInterval = PhaseInterval.YELLOW;
                    } else {
                        advanced = false;
                    }
                    break;
                case YELLOW:
                    if (timeInInterval >= activePhase.getYellowDuration()) {
                        timeInInterval -= activePhase.getYellowDuration();
                        currentInterval = PhaseInterval.ALL_RED;
                    } else {
                        advanced = false;
                    }
                    break;
                case ALL_RED:
                    if (timeInInterval >= activePhase.getAllRedDuration()) {
                        timeInInterval -= activePhase.getAllRedDuration();
                        currentPhaseIndex = (currentPhaseIndex + 1) % phases.size();
                        currentInterval = PhaseInterval.GREEN;
                    } else {
                        advanced = false;
                    }
                    break;
            }
        }
    }

    /**
     * Resolves the current SignalState for a specific incoming road approach at this intersection.
     */
    public SignalState getSignalStateForRoad(String incomingRoadId) {
        SignalPhase phase = getCurrentPhase();
        boolean roadServicedInPhase = phase.getGreenRoadIds().contains(incomingRoadId);

        if (!roadServicedInPhase) {
            return SignalState.RED;
        }

        switch (currentInterval) {
            case GREEN:
                return SignalState.GREEN;
            case YELLOW:
                return SignalState.YELLOW;
            case ALL_RED:
            default:
                return SignalState.RED;
        }
    }

    /**
     * Returns remaining time in the current phase interval (GREEN/YELLOW/ALL_RED).
     * Used by the API layer for JSON serialization.
     */
    public double getPhaseTimeRemaining() {
        return getRemainingIntervalTime();
    }

    /**
     * Returns the set of all road IDs tracked by any phase in this plan.
     * Used by the API to know which roads have a signal entry here.
     */
    public Set<String> getTrackedRoadIds() {
        Set<String> ids = new LinkedHashSet<>();
        for (SignalPhase phase : phases) {
            ids.addAll(phase.getGreenRoadIds());
        }
        return ids;
    }

    /**
     * Request immediate green transition for a road approach.
     * Switches to the phase servicing this road so waiting vehicles or ambulances do not wait.
     */
    public boolean requestGreenForRoad(String roadId) {
        if (getCurrentPhase().getGreenRoadIds().contains(roadId) && currentInterval == PhaseInterval.GREEN) {
            return true;
        }
        for (int i = 0; i < phases.size(); i++) {
            if (phases.get(i).getGreenRoadIds().contains(roadId)) {
                this.currentPhaseIndex = i;
                this.currentInterval = PhaseInterval.GREEN;
                this.timeInInterval = 0.0;
                return true;
            }
        }
        return false;
    }

    /**
     * Reset the plan back to the start of Phase 0.
     */
    public void reset() {
        this.currentPhaseIndex = 0;
        this.currentInterval = PhaseInterval.GREEN;
        this.timeInInterval = 0.0;
    }
}
