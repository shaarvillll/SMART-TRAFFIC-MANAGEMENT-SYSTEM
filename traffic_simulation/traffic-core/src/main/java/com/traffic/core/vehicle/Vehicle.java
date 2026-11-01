package com.traffic.core.vehicle;

import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import com.traffic.core.routing.Route;

/**
 * Represents an active or completed vehicle traveling along a calculated route in the network.
 */
public class Vehicle {
    private final String id;
    private final VehicleType type;
    private final Intersection source;
    private final Intersection destination;
    private final Route route;

    private int currentRouteIndex;         // Index of road in route.getRoads()
    private double distanceAlongRoad;       // Traveled distance on current road segment
    private double currentSpeed;            // Current speed in pixels/s
    private double x;                       // Current X coordinate on map
    private double y;                       // Current Y coordinate on map
    private double headingAngle;            // Direction of travel in radians
    private VehicleStatus status;
    private double waitTimeSeconds;         // Time spent stopped at signals or waiting
    private double tripDurationSeconds;     // Total duration of trip

    public Vehicle(String id, VehicleType type, Intersection source, Intersection destination, Route route) {
        if (id == null || type == null || source == null || destination == null) {
            throw new IllegalArgumentException("Vehicle parameters cannot be null");
        }
        this.id = id;
        this.type = type;
        this.source = source;
        this.destination = destination;
        this.route = route;
        this.currentRouteIndex = 0;
        this.distanceAlongRoad = 0.0;
        this.currentSpeed = type.getBaseSpeed();
        this.status = VehicleStatus.WAITING;
        this.waitTimeSeconds = 0.0;
        this.tripDurationSeconds = 0.0;

        // Initialize spatial coordinates
        updatePosition();
    }

    public String getId() {
        return id;
    }

    public VehicleType getType() {
        return type;
    }

    public Intersection getSource() {
        return source;
    }

    public Intersection getDestination() {
        return destination;
    }

    public Route getRoute() {
        return route;
    }

    public int getCurrentRouteIndex() {
        return currentRouteIndex;
    }

    public void setCurrentRouteIndex(int currentRouteIndex) {
        this.currentRouteIndex = currentRouteIndex;
        updatePosition();
    }

    public Road getCurrentRoad() {
        if (route == null || route.isEmpty() || currentRouteIndex >= route.getRoads().size()) {
            return null;
        }
        return route.getRoads().get(currentRouteIndex);
    }

    public Intersection getCurrentFromIntersection() {
        if (route == null || route.isEmpty() || currentRouteIndex >= route.getPath().size() - 1) {
            return null;
        }
        return route.getPath().get(currentRouteIndex);
    }

    public Intersection getCurrentToIntersection() {
        if (route == null || route.isEmpty() || currentRouteIndex >= route.getPath().size() - 1) {
            return null;
        }
        return route.getPath().get(currentRouteIndex + 1);
    }

    public double getDistanceAlongRoad() {
        return distanceAlongRoad;
    }

    public void setDistanceAlongRoad(double distanceAlongRoad) {
        this.distanceAlongRoad = distanceAlongRoad;
        updatePosition();
    }

    public double getCurrentSpeed() {
        return currentSpeed;
    }

    public void setCurrentSpeed(double currentSpeed) {
        this.currentSpeed = currentSpeed;
    }

    public double getX() {
        return x;
    }

    public double getY() {
        return y;
    }

    public double getHeadingAngle() {
        return headingAngle;
    }

    public VehicleStatus getStatus() {
        return status;
    }

    public void setStatus(VehicleStatus status) {
        this.status = status;
    }

    public double getWaitTimeSeconds() {
        return waitTimeSeconds;
    }

    public void addWaitTime(double deltaSeconds) {
        this.waitTimeSeconds += deltaSeconds;
    }

    public double getTripDurationSeconds() {
        return tripDurationSeconds;
    }

    public void addTripDuration(double deltaSeconds) {
        this.tripDurationSeconds += deltaSeconds;
    }

    /**
     * Calculates overall progress along the calculated route as a percentage (0.0 to 100.0).
     */
    public double getProgressPercentage() {
        if (status == VehicleStatus.COMPLETED) {
            return 100.0;
        }
        if (route == null || route.isEmpty() || route.getTotalDistance() <= 0.0) {
            return 0.0;
        }

        double completedDist = 0.0;
        for (int i = 0; i < currentRouteIndex && i < route.getRoads().size(); i++) {
            completedDist += route.getRoads().get(i).getLength();
        }
        completedDist += distanceAlongRoad;

        return Math.min(100.0, Math.max(0.0, (completedDist / route.getTotalDistance()) * 100.0));
    }

    /**
     * Computes the 2D Cartesian position and heading along the right-hand lane of the current road segment.
     */
    public void updatePosition() {
        if (route == null || route.isEmpty() || currentRouteIndex >= route.getRoads().size()) {
            if (destination != null) {
                this.x = destination.getX();
                this.y = destination.getY();
            }
            return;
        }

        Intersection fromNode = getCurrentFromIntersection();
        Intersection toNode = getCurrentToIntersection();
        if (fromNode == null || toNode == null) return;

        double dx = toNode.getX() - fromNode.getX();
        double dy = toNode.getY() - fromNode.getY();
        double roadLen = Math.hypot(dx, dy);

        if (roadLen > 0.0) {
            double ux = dx / roadLen;
            double uy = dy / roadLen;

            // Lateral offset to drive along the right lane (ROAD_WIDTH / 4.0 = ~6.5px)
            double perpX = -uy;
            double perpY = ux;
            double lateralOffset = 10.5; // Center of right lane (42px road / 4)

            double clampedDist = Math.min(distanceAlongRoad, roadLen);
            double baseX = fromNode.getX() + ux * clampedDist;
            double baseY = fromNode.getY() + uy * clampedDist;

            this.x = baseX + perpX * lateralOffset;
            this.y = baseY + perpY * lateralOffset;
            this.headingAngle = Math.atan2(dy, dx);
        }
    }

    @Override
    public String toString() {
        return "Vehicle{" + id + " (" + type + "): " + source.getId() + " -> " + destination.getId() + " [" + status + "]}";
    }
}
