package com.traffic.core.model;

/**
 * Represents an important landmark attached to or near an intersection.
 */
public class Landmark {
    private final String id;
    private final String name;
    private final LandmarkType type;
    private final String intersectionId;
    private final String iconCode;

    public Landmark(String id, String name, LandmarkType type, String intersectionId, String iconCode) {
        this.id = id;
        this.name = name;
        this.type = type;
        this.intersectionId = intersectionId;
        this.iconCode = iconCode;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public LandmarkType getType() {
        return type;
    }

    public String getIntersectionId() {
        return intersectionId;
    }

    public String getIconCode() {
        return iconCode;
    }
}
