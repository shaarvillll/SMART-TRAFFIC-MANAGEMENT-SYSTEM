package com.traffic.desktop;

import com.traffic.core.model.Intersection;
import com.traffic.core.vehicle.VehicleStatus;
import com.traffic.core.vehicle.VehicleType;

import java.util.List;

/**
 * Lightweight vehicle representation used when the desktop app is connected to the backend.
 * Holds the position/heading/type received via WebSocket instead of local physics simulation.
 * The MapCanvasRenderer is updated to accept a List<GhostVehicle> in connected mode.
 */
public class GhostVehicle {

    private final String id;
    private final VehicleType type;
    private VehicleStatus status;
    private double x;
    private double y;
    private double headingAngle;
    private double progressPercent;
    private final List<String> routePath;
    private final Intersection source;
    private final Intersection destination;

    public GhostVehicle(String id, VehicleType type, VehicleStatus status,
                        double x, double y, double headingAngle, double progressPercent,
                        List<String> routePath, Intersection source, Intersection destination) {
        this.id = id;
        this.type = type;
        this.status = status;
        this.x = x;
        this.y = y;
        this.headingAngle = headingAngle;
        this.progressPercent = progressPercent;
        this.routePath = routePath;
        this.source = source;
        this.destination = destination;
    }

    public String getId()               { return id; }
    public VehicleType getType()        { return type; }
    public VehicleStatus getStatus()    { return status; }
    public double getX()                { return x; }
    public double getY()                { return y; }
    public double getHeadingAngle()     { return headingAngle; }
    public double getProgressPercent()  { return progressPercent; }
    public List<String> getRoutePath()  { return routePath; }
    public Intersection getSource()     { return source; }
    public Intersection getDestination(){ return destination; }

    public void update(double x, double y, double headingAngle, VehicleStatus status, double progressPercent) {
        this.x = x;
        this.y = y;
        this.headingAngle = headingAngle;
        this.status = status;
        this.progressPercent = progressPercent;
    }

    /** Adapter: mimic Vehicle.getProgressPercentage() for the vehicle list UI. */
    public double getProgressPercentage() { return progressPercent; }
}
