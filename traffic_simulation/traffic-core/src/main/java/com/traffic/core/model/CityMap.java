package com.traffic.core.model;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Clean & Balanced Irregular City Road Network:
 * - 10 Intersections (J1 to J10).
 * - Maximum 4 roads per junction.
 * - Balanced mix of 3-way (T/Y) and 4-way junctions.
 * - Removed roads:
 *     * Removed J1 - J5 road
 *     * Removed J3 - J6 road
 * - Landmark Locations:
 *     1. Central Railway Station -> J1
 *     2. City General Hospital -> J3
 *     3. Downtown City Center -> J6
 *     4. Metro State University -> J8
 *     5. Grand Galleria Mall -> J10
 */
public class CityMap {
    private final Map<String, Intersection> intersections;
    private final List<Road> roads;
    private final Map<String, Landmark> landmarks;

    public CityMap() {
        this.intersections = new LinkedHashMap<>();
        this.roads = new ArrayList<>();
        this.landmarks = new LinkedHashMap<>();
        buildCityNetwork();
    }

    private void buildCityNetwork() {
        // --- 1. Create 10 Intersections ---
        // North Row
        createIntersection("J1", "Central Railway Station", 160, 140);
        createIntersection("J2", "North Civic Junction", 510, 140);
        createIntersection("J3", "City General Hospital", 860, 140);

        // Mid-Upper Row
        createIntersection("J4", "West District Hub", 160, 420);
        createIntersection("J5", "Civic Park Junction", 450, 400);
        createIntersection("J6", "Downtown City Center", 750, 400);
        createIntersection("J7", "East Industrial Link", 890, 470);

        // South Row
        createIntersection("J8", "Metro University Campus", 240, 710);
        createIntersection("J9", "South Commercial Hub", 560, 680);
        createIntersection("J10", "Grand Galleria Mall", 860, 710);

        // --- 2. Attach 5 Key Strategic Landmarks as requested ---
        addLandmark("LM_STATION", "Central Railway Station", LandmarkType.RAILWAY_STATION, "J1", "RS");
        addLandmark("LM_HOSPITAL", "City General Hospital", LandmarkType.HOSPITAL, "J3", "H");
        addLandmark("LM_CITY_CENTER", "Downtown City Center", LandmarkType.CITY_CENTER, "J6", "CC");
        addLandmark("LM_UNIVERSITY", "Metro State University", LandmarkType.UNIVERSITY, "J8", "UN");
        addLandmark("LM_MALL", "Grand Galleria Mall", LandmarkType.SHOPPING_MALL, "J10", "SM");

        // --- 3. Create Roads (Removed J1-J5 and J3-J6) ---
        // North Corridor
        addRoad("R1", "North Boulevard West", "J1", "J2", RoadType.MAIN_GRID);     // J1-J2
        addRoad("R2", "North Boulevard East", "J2", "J3", RoadType.MAIN_GRID);     // J2-J3

        // West Corridor
        addRoad("R3", "Station South Approach", "J1", "J4", RoadType.MAIN_GRID);   // J1-J4
        addRoad("R4", "University West Link", "J4", "J8", RoadType.MAIN_GRID);     // J4-J8

        // Central District Roads
        addRoad("R5", "Station Avenue East", "J4", "J5", RoadType.MAIN_GRID);      // J4-J5
        addRoad("R6", "Civic Park Connector", "J2", "J5", RoadType.MAIN_GRID);     // J2-J5
        // REMOVED J3-J6 ("R7") as requested
        addRoad("R8", "Metro Central Boulevard", "J5", "J6", RoadType.MAIN_GRID);  // J5-J6
        addRoad("R9", "East Commercial Ave", "J6", "J7", RoadType.MAIN_GRID);      // J6-J7

        // Diagonal Bypasses
        addRoad("R10_D", "Hospital Express Bypass", "J2", "J6", RoadType.DIAGONAL); // J2-J6
        // REMOVED J1-J5 ("R11_D") as requested
        addRoad("R12_D", "Northeast Industrial Link", "J3", "J7", RoadType.DIAGONAL);// J3-J7

        // South Arterials & Access
        addRoad("R13", "University Ring Road", "J8", "J9", RoadType.MAIN_GRID);    // J8-J9
        addRoad("R14", "Midtown South Link", "J5", "J8", RoadType.MAIN_GRID);      // J5-J8
        addRoad("R15", "Downtown South Parkway", "J6", "J9", RoadType.MAIN_GRID);  // J6-J9
        addRoad("R16", "Galleria Mall Boulevard", "J9", "J10", RoadType.MAIN_GRID);// J9-J10
        addRoad("R17", "Terminal East Highway", "J7", "J10", RoadType.MAIN_GRID);  // J7-J10
    }

    public Intersection createIntersection(String id, String name, double x, double y) {
        Intersection intersection = new Intersection(id, name, x, y);
        intersections.put(id, intersection);
        return intersection;
    }

    public Road addRoad(String id, String name, String fromId, String toId, RoadType type) {
        Intersection from = intersections.get(fromId);
        Intersection to = intersections.get(toId);
        if (from != null && to != null) {
            Road road = new Road(id, name, from, to, type);
            roads.add(road);
            return road;
        }
        return null;
    }

    public Landmark addLandmark(String id, String name, LandmarkType type, String intersectionId, String iconCode) {
        Landmark landmark = new Landmark(id, name, type, intersectionId, iconCode);
        landmarks.put(id, landmark);
        Intersection intersection = intersections.get(intersectionId);
        if (intersection != null) {
            intersection.setLandmark(landmark);
        }
        return landmark;
    }

    public Map<String, Intersection> getIntersections() {
        return intersections;
    }

    public List<Road> getRoads() {
        return roads;
    }

    public Map<String, Landmark> getLandmarks() {
        return landmarks;
    }

    public Intersection getIntersection(String id) {
        return intersections.get(id);
    }

    public Road getRoad(String id) {
        for (Road r : roads) {
            if (r.getId().equals(id)) return r;
        }
        return null;
    }

    public Road getRoadBetween(Intersection a, Intersection b) {
        if (a == null || b == null) return null;
        for (Road r : a.getConnectedRoads()) {
            if (b.equals(r.getOtherEnd(a))) {
                return r;
            }
        }
        return null;
    }

    public Road getRoadBetween(String aId, String bId) {
        return getRoadBetween(getIntersection(aId), getIntersection(bId));
    }
}
