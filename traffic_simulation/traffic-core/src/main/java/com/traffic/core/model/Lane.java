package com.traffic.core.model;

/**
 * Represents a single directional lane on a road.
 */
public class Lane {
    private final String id;
    private final Intersection startIntersection;
    private final Intersection endIntersection;
    private final double width;

    public Lane(String id, Intersection startIntersection, Intersection endIntersection, double width) {
        this.id = id;
        this.startIntersection = startIntersection;
        this.endIntersection = endIntersection;
        this.width = width;
    }

    public String getId() {
        return id;
    }

    public Intersection getStartIntersection() {
        return startIntersection;
    }

    public Intersection getEndIntersection() {
        return endIntersection;
    }

    public double getWidth() {
        return width;
    }
}
