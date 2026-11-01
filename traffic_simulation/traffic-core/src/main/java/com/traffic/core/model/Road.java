package com.traffic.core.model;

/**
 * Represents a two-lane bi-directional road connecting two intersections.
 * Contains one lane in the forward direction (A -> B) and one in the reverse direction (B -> A).
 */
public class Road {
    private final String id;
    private final String name;
    private final Intersection intersectionA;
    private final Intersection intersectionB;
    private final RoadType roadType;
    private final double length;
    private final double speedLimit;
    private final Lane forwardLane;
    private final Lane reverseLane;
    private RoadCondition condition;

    public Road(String id, String name, Intersection intersectionA, Intersection intersectionB, RoadType roadType) {
        this.id = id;
        this.name = name;
        this.intersectionA = intersectionA;
        this.intersectionB = intersectionB;
        this.roadType = roadType;
        this.condition = RoadCondition.NORMAL;
        this.speedLimit = 50.0; // 50 km/h default

        // Calculate Euclidean distance between intersections
        double dx = intersectionB.getX() - intersectionA.getX();
        double dy = intersectionB.getY() - intersectionA.getY();
        this.length = Math.hypot(dx, dy);

        // One lane in each direction
        this.forwardLane = new Lane(id + "-L1", intersectionA, intersectionB, 18.0);
        this.reverseLane = new Lane(id + "-L2", intersectionB, intersectionA, 18.0);

        intersectionA.addConnectedRoad(this);
        intersectionB.addConnectedRoad(this);
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public Intersection getIntersectionA() {
        return intersectionA;
    }

    public Intersection getIntersectionB() {
        return intersectionB;
    }

    public RoadType getRoadType() {
        return roadType;
    }

    public double getLength() {
        return length;
    }

    public double getSpeedLimit() {
        return speedLimit;
    }

    public Lane getForwardLane() {
        return forwardLane;
    }

    public Lane getReverseLane() {
        return reverseLane;
    }

    public RoadCondition getCondition() {
        return condition;
    }

    public void setCondition(RoadCondition condition) {
        this.condition = condition;
    }

    public Intersection getOtherEnd(Intersection current) {
        if (current.equals(intersectionA)) {
            return intersectionB;
        } else if (current.equals(intersectionB)) {
            return intersectionA;
        }
        return null;
    }

    @Override
    public String toString() {
        return "Road{" + id + ": " + intersectionA.getId() + " <-> " + intersectionB.getId() + "}";
    }
}
