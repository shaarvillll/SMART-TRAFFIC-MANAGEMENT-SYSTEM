package com.traffic.core.routing;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import com.traffic.core.model.RoadType;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class RouteFinderTest {

    private CityMap cityMap;
    private RouteFinder routeFinder;

    @BeforeEach
    public void setUp() {
        cityMap = new CityMap();
        routeFinder = new RouteFinder();
    }

    @Test
    @DisplayName("Verify valid direct route between adjacent intersections (J1 -> J2)")
    public void testDirectAdjacentRoute() {
        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J2");
        assertNotNull(route);
        assertTrue(route.isValid());
        assertEquals(2, route.getPath().size());
        assertEquals("J1", route.getPath().get(0).getId());
        assertEquals("J2", route.getPath().get(1).getId());
        assertEquals(1, route.getRoads().size());
        assertEquals("R1", route.getRoads().get(0).getId());
        assertTrue(route.getTotalDistance() > 0);
    }

    @Test
    @DisplayName("Verify multi-hop shortest route across city (J1 -> J10)")
    public void testMultiHopRoute() {
        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J10");
        assertNotNull(route);
        assertTrue(route.isValid());
        assertEquals("J1", route.getSource().getId());
        assertEquals("J10", route.getDestination().getId());
        assertTrue(route.getRoadCount() >= 3);

        // Verify that consecutive intersections in path are actually connected by the assigned road
        for (int i = 0; i < route.getRoads().size(); i++) {
            Intersection u = route.getPath().get(i);
            Intersection v = route.getPath().get(i + 1);
            Road r = route.getRoads().get(i);

            assertTrue((r.getIntersectionA().equals(u) && r.getIntersectionB().equals(v)) ||
                       (r.getIntersectionA().equals(v) && r.getIntersectionB().equals(u)),
                       "Road " + r.getId() + " does not connect " + u.getId() + " and " + v.getId());
        }
    }

    @Test
    @DisplayName("Verify source equal to destination returns empty zero-distance route")
    public void testSourceEqualsDestination() {
        Route route = routeFinder.findShortestRoute(cityMap, "J6", "J6");
        assertNotNull(route);
        assertTrue(route.isEmpty());
        assertEquals(0.0, route.getTotalDistance(), 1e-6);
        assertEquals(1, route.getPath().size());
        assertEquals("J6", route.getPath().get(0).getId());
    }

    @Test
    @DisplayName("Verify null and invalid intersection IDs return null")
    public void testInvalidInputs() {
        assertNull(routeFinder.findShortestRoute(cityMap, "INVALID", "J2"));
        assertNull(routeFinder.findShortestRoute(cityMap, "J1", "NON_EXISTENT"));
        assertNull(routeFinder.findShortestRoute(null, "J1", "J2"));
        assertNull(routeFinder.findShortestRoute(cityMap, (String) null, "J2"));
    }

    @Test
    @DisplayName("Verify disconnected intersection returns null (unreachable)")
    public void testDisconnectedIntersection() {
        // Create an isolated island node with no road connections
        cityMap.createIntersection("J_ISLAND", "Isolated Island", 1200, 1200);

        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J_ISLAND");
        assertNull(route, "Isolated node must be unreachable");

        Route reverseRoute = routeFinder.findShortestRoute(cityMap, "J_ISLAND", "J1");
        assertNull(reverseRoute, "Isolated node cannot reach other nodes");
    }

    @Test
    @DisplayName("Verify Dijkstra selects the truly shorter path over longer alternative")
    public void testDijkstraOptimality() {
        // Construct a small custom map with 2 parallel routes: short vs long
        CityMap testMap = new CityMap();
        Intersection a = testMap.createIntersection("A", "Node A", 0, 0);
        Intersection b = testMap.createIntersection("B", "Node B", 100, 0);
        Intersection c = testMap.createIntersection("C", "Node C", 200, 0);
        Intersection d = testMap.createIntersection("D", "Node D", 100, 200);

        // Path 1: A -> B -> C (distance: 100 + 100 = 200)
        testMap.addRoad("R_AB", "AB", "A", "B", RoadType.MAIN_GRID);
        testMap.addRoad("R_BC", "BC", "B", "C", RoadType.MAIN_GRID);

        // Path 2: A -> D -> C (distance: sqrt(100^2 + 200^2) + sqrt(100^2 + 200^2) ~= 223.6 * 2 = 447.2)
        testMap.addRoad("R_AD", "AD", "A", "D", RoadType.MAIN_GRID);
        testMap.addRoad("R_DC", "DC", "D", "C", RoadType.MAIN_GRID);

        Route route = routeFinder.findShortestRoute(testMap, "A", "C");
        assertNotNull(route);
        assertEquals(3, route.getPath().size());
        assertEquals("A", route.getPath().get(0).getId());
        assertEquals("B", route.getPath().get(1).getId());
        assertEquals("C", route.getPath().get(2).getId());
        assertEquals(200.0, route.getTotalDistance(), 1e-3);
    }
}
