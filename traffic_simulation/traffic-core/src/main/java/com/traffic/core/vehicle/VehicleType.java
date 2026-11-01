package com.traffic.core.vehicle;

/**
 * Defines vehicle categories with distinct physical dimensions, operating speeds, and colors.
 */
public enum VehicleType {
    CAR("Car", 65.0, 14.0, 8.0, "#38bdf8"),
    BUS("Bus", 42.0, 24.0, 10.0, "#f59e0b"),
    TRUCK("Truck", 38.0, 26.0, 10.0, "#ec4899"),
    MOTORCYCLE("Motorcycle", 75.0, 10.0, 5.0, "#a855f7"),
    AMBULANCE("Ambulance", 82.0, 16.0, 9.0, "#ef4444");

    private final String displayName;
    private final double baseSpeed;  // pixels per simulation second
    private final double length;     // visual length
    private final double width;      // visual width
    private final String colorHex;   // accent color hex code

    VehicleType(String displayName, double baseSpeed, double length, double width, String colorHex) {
        this.displayName = displayName;
        this.baseSpeed = baseSpeed;
        this.length = length;
        this.width = width;
        this.colorHex = colorHex;
    }

    public String getDisplayName() {
        return displayName;
    }

    public double getBaseSpeed() {
        return baseSpeed;
    }

    public double getLength() {
        return length;
    }

    public double getWidth() {
        return width;
    }

    public String getColorHex() {
        return colorHex;
    }

    @Override
    public String toString() {
        return displayName;
    }
}
