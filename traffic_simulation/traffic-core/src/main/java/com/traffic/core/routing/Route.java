package com.traffic.core.routing;

import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Represents a directed route across the city graph from a source to a destination.
 * Contains ordered sequence of intersections and the roads connecting them.
 */
public class Route {
    private final Intersection source;
    private final Intersection destination;
    private final List<Intersection> path;
    private final List<Road> roads;
    private final double totalDistance;

    public Route(Intersection source, Intersection destination, List<Intersection> path, List<Road> roads, double totalDistance) {
        this.source = source;
        this.destination = destination;
        this.path = (path != null) ? Collections.unmodifiableList(new ArrayList<>(path)) : Collections.emptyList();
        this.roads = (roads != null) ? Collections.unmodifiableList(new ArrayList<>(roads)) : Collections.emptyList();
        this.totalDistance = totalDistance;
    }

    public static Route empty(Intersection source, Intersection destination) {
        List<Intersection> p = new ArrayList<>();
        if (source != null) p.add(source);
        return new Route(source, destination, p, Collections.emptyList(), 0.0);
    }

    public Intersection getSource() {
        return source;
    }

    public Intersection getDestination() {
        return destination;
    }

    public List<Intersection> getPath() {
        return path;
    }

    public List<Road> getRoads() {
        return roads;
    }

    public double getTotalDistance() {
        return totalDistance;
    }

    public boolean isValid() {
        if (source == null || destination == null) return false;
        if (source.equals(destination)) return true;
        return !roads.isEmpty() && path.size() == roads.size() + 1;
    }

    public boolean isEmpty() {
        return roads.isEmpty();
    }

    public int getRoadCount() {
        return roads.size();
    }

    public int getHopCount() {
        return Math.max(0, path.size() - 1);
    }

    public String getRouteDescription() {
        if (!isValid() || path.isEmpty()) {
            return "No valid route";
        }
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < path.size(); i++) {
            sb.append(path.get(i).getId());
            if (i < path.size() - 1) {
                sb.append(" \u2192 ");
            }
        }
        sb.append(String.format(" (%.1fm)", totalDistance));
        return sb.toString();
    }

    @Override
    public String toString() {
        return "Route{" + getRouteDescription() + "}";
    }
}
