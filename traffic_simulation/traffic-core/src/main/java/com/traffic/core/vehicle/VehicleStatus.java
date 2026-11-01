package com.traffic.core.vehicle;

/**
 * Lifecycle state of a vehicle within the simulation.
 */
public enum VehicleStatus {
    WAITING("Waiting"),
    MOVING("Moving"),
    STOPPED_AT_SIGNAL("Stopped at Signal"),
    COMPLETED("Completed");

    private final String label;

    VehicleStatus(String label) {
        this.label = label;
    }

    public String getLabel() {
        return label;
    }

    @Override
    public String toString() {
        return label;
    }
}
