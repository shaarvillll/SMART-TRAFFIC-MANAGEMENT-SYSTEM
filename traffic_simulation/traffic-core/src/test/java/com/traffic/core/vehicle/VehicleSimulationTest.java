package com.traffic.core.vehicle;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import com.traffic.core.routing.Route;
import com.traffic.core.routing.RouteFinder;
import com.traffic.core.signal.SignalPlan;
import com.traffic.core.signal.SignalState;
import com.traffic.core.signal.TrafficSignalController;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

public class VehicleSimulationTest {

    private CityMap cityMap;
    private TrafficSignalController signalController;
    private RouteFinder routeFinder;
    private VehicleManager vehicleManager;

    @BeforeEach
    public void setUp() {
        cityMap = new CityMap();
        signalController = new TrafficSignalController(cityMap, 15.0, 3.0, 1.0);
        routeFinder = new RouteFinder();
        vehicleManager = new VehicleManager(cityMap);
    }

    @Test
    @DisplayName("Verify vehicle creation and initial positioning along right-hand lane")
    public void testVehicleCreationAndPosition() {
        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J2");
        assertNotNull(route);

        Vehicle v = vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J1"), cityMap.getIntersection("J2"), route);
        assertNotNull(v);
        assertEquals("V-01", v.getId());
        assertEquals(VehicleStatus.WAITING, v.getStatus());
        assertEquals(0.0, v.getDistanceAlongRoad(), 1e-6);

        // Position should be offset to the right of J1 (160, 140)
        assertTrue(v.getX() >= 150.0 && v.getX() <= 170.0);
        assertTrue(v.getY() >= 140.0 && v.getY() <= 160.0);
    }

    @Test
    @DisplayName("Verify vehicle movement progression over simulation clock steps")
    public void testVehicleProgression() {
        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J2");
        Vehicle v = vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J1"), cityMap.getIntersection("J2"), route);

        double initialDist = v.getDistanceAlongRoad();
        double speed = v.getType().getBaseSpeed();

        // Step by 1.0 second
        vehicleManager.step(1.0, signalController);

        assertEquals(VehicleStatus.MOVING, v.getStatus());
        assertEquals(initialDist + speed * 1.0, v.getDistanceAlongRoad(), 1e-3);
        assertTrue(v.getProgressPercentage() > 0.0);
    }

    @Test
    @DisplayName("Verify vehicle stops at RED signal before entering an intersection")
    public void testVehicleStopsAtRedSignal() {
        // Route from J5 to J3 via J2 (J5 -> J2 -> J3)
        // First road in route is R6 (J5 to J2). At J2, R6 has RED signal during Phase 1 (0-19s).
        Route route = routeFinder.findShortestRoute(cityMap, "J5", "J3");
        assertNotNull(route);
        assertEquals("R6", route.getRoads().get(0).getId());

        Vehicle v = vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J5"), cityMap.getIntersection("J3"), route);

        Road r6 = route.getRoads().get(0);
        double roadLen = r6.getLength();

        // Place vehicle close to the stop line of J2
        v.setDistanceAlongRoad(roadLen - 30.0);

        // Verify approach signal at J2 for R6 is indeed RED
        SignalPlan j2Plan = signalController.getSignalPlan("J2");
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad(r6.getId()));

        // Step simulation forward
        vehicleManager.step(0.5, signalController);

        // Vehicle must stop before the stop line and change status to STOPPED_AT_SIGNAL
        assertEquals(VehicleStatus.STOPPED_AT_SIGNAL, v.getStatus());
        assertEquals(0.0, v.getCurrentSpeed(), 1e-6);
        assertTrue(v.getDistanceAlongRoad() <= roadLen - 26.0);
    }

    @Test
    @DisplayName("Verify vehicle resumes and enters intersection when signal turns GREEN")
    public void testVehicleResumesOnGreen() {
        Route route = routeFinder.findShortestRoute(cityMap, "J5", "J3");
        assertNotNull(route);
        assertEquals("R6", route.getRoads().get(0).getId());

        Vehicle v = vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J5"), cityMap.getIntersection("J3"), route);

        Road r6 = route.getRoads().get(0);
        double roadLen = r6.getLength();
        v.setDistanceAlongRoad(roadLen - 28.0);

        // Initially at t=0s, R6 is RED at J2
        vehicleManager.step(0.1, signalController);
        assertEquals(VehicleStatus.STOPPED_AT_SIGNAL, v.getStatus());

        // Advance simulation clock until Phase 2 starts (at t=19.5s, R6 becomes GREEN!)
        signalController.step(19.5);
        SignalPlan j2Plan = signalController.getSignalPlan("J2");
        assertEquals(SignalState.GREEN, j2Plan.getSignalStateForRoad(r6.getId()));

        // Now step vehicle manager: vehicle should detect green and resume moving
        vehicleManager.step(0.5, signalController);
        assertEquals(VehicleStatus.MOVING, v.getStatus());
        assertTrue(v.getCurrentSpeed() > 0.0);
    }

    @Test
    @DisplayName("Verify safe car-following distance prevents vehicles from overlapping")
    public void testCarFollowingAntiOverlap() {
        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J2");

        // Spawn leading vehicle A and following vehicle B
        Vehicle vA = vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J1"), cityMap.getIntersection("J2"), route);
        Vehicle vB = vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J1"), cityMap.getIntersection("J2"), route);

        vA.setDistanceAlongRoad(50.0);
        vB.setDistanceAlongRoad(40.0); // Only 10px behind (less than safe gap + length)

        // Step simulation
        vehicleManager.step(0.2, signalController);

        // Vehicle B must maintain safe gap and not overtake/overlap vehicle A
        double distA = vA.getDistanceAlongRoad();
        double distB = vB.getDistanceAlongRoad();
        assertTrue(distB < distA, "Following vehicle must stay strictly behind leading vehicle");
        assertTrue(distA - distB >= vA.getType().getLength(), "Following vehicle must not overlap leading vehicle");
    }

    @Test
    @DisplayName("Verify vehicle reaches destination and completes trip")
    public void testTripCompletion() {
        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J2");
        Vehicle v = vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J1"), cityMap.getIntersection("J2"), route);

        Road r1 = route.getRoads().get(0);
        // Place vehicle 5 pixels before destination
        v.setDistanceAlongRoad(r1.getLength() - 5.0);

        // Step enough to cross destination
        vehicleManager.step(0.5, signalController);

        assertEquals(VehicleStatus.COMPLETED, v.getStatus());
        assertEquals(100.0, v.getProgressPercentage(), 1e-3);
        assertEquals(0.0, v.getCurrentSpeed(), 1e-6);
    }

    @Test
    @DisplayName("Verify simulation reset and clearing vehicles")
    public void testResetAndClear() {
        Route route = routeFinder.findShortestRoute(cityMap, "J1", "J2");
        vehicleManager.spawnVehicle(VehicleType.CAR, cityMap.getIntersection("J1"), cityMap.getIntersection("J2"), route);
        vehicleManager.spawnVehicle(VehicleType.BUS, cityMap.getIntersection("J1"), cityMap.getIntersection("J2"), route);

        assertEquals(2, vehicleManager.getVehicles().size());

        vehicleManager.clearVehicles();
        assertEquals(0, vehicleManager.getVehicles().size());
    }
}
