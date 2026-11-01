package com.traffic.core.routing;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;

import java.util.*;

/**
 * RouteFinder implements Dijkstra's shortest path algorithm across the city road network.
 * Uses Euclidean road lengths as edge weights and supports bidirectional road traversal.
 */
public class RouteFinder {

    private static class QueueNode {
        final Intersection node;
        final double dist;

        QueueNode(Intersection node, double dist) {
            this.node = node;
            this.dist = dist;
        }

        double getDist() {
            return dist;
        }
    }

    /**
     * Finds the shortest route between two intersections identified by their IDs.
     */
    public Route findShortestRoute(CityMap cityMap, String sourceId, String destinationId) {
        if (cityMap == null || sourceId == null || destinationId == null) {
            return null;
        }
        Intersection source = cityMap.getIntersection(sourceId);
        Intersection destination = cityMap.getIntersection(destinationId);
        return findShortestRoute(cityMap, source, destination);
    }

    /**
     * Finds the shortest route between two intersections using Dijkstra's algorithm.
     * Returns null if no route exists or if inputs are invalid.
     * Returns empty route if source equals destination.
     */
    public Route findShortestRoute(CityMap cityMap, Intersection source, Intersection destination) {
        if (cityMap == null || source == null || destination == null) {
            return null;
        }

        // Trivial case: Source == Destination
        if (source.equals(destination)) {
            return Route.empty(source, destination);
        }

        Map<Intersection, Double> dist = new HashMap<>();
        Map<Intersection, Intersection> parentNode = new HashMap<>();
        Map<Intersection, Road> parentRoad = new HashMap<>();
        Set<Intersection> visited = new HashSet<>();

        PriorityQueue<QueueNode> pq = new PriorityQueue<>(Comparator.comparingDouble(QueueNode::getDist));

        for (Intersection node : cityMap.getIntersections().values()) {
            dist.put(node, Double.POSITIVE_INFINITY);
        }

        dist.put(source, 0.0);
        pq.add(new QueueNode(source, 0.0));

        while (!pq.isEmpty()) {
            QueueNode current = pq.poll();
            Intersection u = current.node;

            if (visited.contains(u)) {
                continue;
            }
            visited.add(u);

            if (u.equals(destination)) {
                break; // Target reached with shortest distance
            }

            for (Road road : u.getConnectedRoads()) {
                Intersection v = road.getOtherEnd(u);
                if (v == null || visited.contains(v)) {
                    continue;
                }

                // Avoid completely closed roads
                if (road.getCondition() == com.traffic.core.model.RoadCondition.CLOSED) {
                    continue;
                }

                double weight = road.getLength();
                // Heavy penalty for congested roads so Dijkstra dynamically picks faster bypasses
                if (road.getCondition() == com.traffic.core.model.RoadCondition.CONGESTED) {
                    weight = road.getLength() * 4.0;
                }

                double newDist = dist.get(u) + weight;

                if (newDist < dist.get(v)) {
                    dist.put(v, newDist);
                    parentNode.put(v, u);
                    parentRoad.put(v, road);
                    pq.add(new QueueNode(v, newDist));
                }
            }
        }

        // Check if destination is reachable
        if (!dist.containsKey(destination) || Double.isInfinite(dist.get(destination))) {
            return null;
        }

        // Reconstruct path from destination backwards to source
        List<Intersection> path = new ArrayList<>();
        List<Road> roads = new ArrayList<>();
        Intersection curr = destination;

        while (!curr.equals(source)) {
            path.add(curr);
            Road r = parentRoad.get(curr);
            if (r == null) {
                return null; // Broken path (unreachable)
            }
            roads.add(r);
            curr = parentNode.get(curr);
            if (curr == null) {
                return null;
            }
        }

        path.add(source);
        Collections.reverse(path);
        Collections.reverse(roads);

        return new Route(source, destination, path, roads, dist.get(destination));
    }
}
