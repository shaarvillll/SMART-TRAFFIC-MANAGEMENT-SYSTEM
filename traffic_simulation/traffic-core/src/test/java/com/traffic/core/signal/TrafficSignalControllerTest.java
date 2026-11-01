package com.traffic.core.signal;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Unit tests verifying:
 * 1. Conflicting movements never receive green simultaneously.
 * 2. Deterministic phase cycle transitions (GREEN -> YELLOW -> ALL_RED -> Next Phase).
 * 3. Configurable timing parameters.
 * 4. Distinct signal plans for different junction layouts.
 * 5. Simulation clock advancement.
 */
public class TrafficSignalControllerTest {

    private CityMap cityMap;
    private TrafficSignalController controller;

    @BeforeEach
    public void setUp() {
        cityMap = new CityMap();
        // Timing: Green: 15s, Yellow: 3s, All-Red: 1s (total phase duration = 19s)
        controller = new TrafficSignalController(cityMap, 15.0, 3.0, 1.0);
    }

    @Test
    @DisplayName("Verify only multi-way junctions have signal plans (no 2-way junctions)")
    public void testSignalizedJunctions() {
        Map<String, SignalPlan> plans = controller.getPlans();
        // Signalized: J2, J4, J5, J6, J7, J8, J9
        assertTrue(plans.containsKey("J2"));
        assertTrue(plans.containsKey("J4"));
        assertTrue(plans.containsKey("J5"));
        assertTrue(plans.containsKey("J6"));
        assertTrue(plans.containsKey("J7"));
        assertTrue(plans.containsKey("J8"));
        assertTrue(plans.containsKey("J9"));

        // 2-way junctions must NOT have signal plans
        assertFalse(plans.containsKey("J1"));
        assertFalse(plans.containsKey("J3"));
        assertFalse(plans.containsKey("J10"));
    }

    @Test
    @DisplayName("Verify that conflicting movements never receive green simultaneously across any phase")
    public void testNoConflictingMovementsInAnyPhase() {
        for (SignalPlan plan : controller.getPlans().values()) {
            for (SignalPhase phase : plan.getPhases()) {
                List<TrafficMovement> movements = phase.getAllowedMovements();
                for (int i = 0; i < movements.size(); i++) {
                    for (int j = i + 1; j < movements.size(); j++) {
                        TrafficMovement m1 = movements.get(i);
                        TrafficMovement m2 = movements.get(j);
                        assertFalse(m1.conflictsWith(m2),
                            "Phase " + phase.getId() + " at " + plan.getIntersectionId() +
                            " illegally contains conflicting movements: " + m1 + " vs " + m2);
                    }
                }
            }
        }
    }

    @Test
    @DisplayName("Verify deterministic phase transitions: GREEN -> YELLOW -> ALL_RED -> Next Phase GREEN")
    public void testPhaseTransitions() {
        SignalPlan j2Plan = controller.getSignalPlan("J2");
        assertNotNull(j2Plan);

        // At t = 0s: Phase 0 is in GREEN
        assertEquals(0, j2Plan.getCurrentPhaseIndex());
        assertEquals(PhaseInterval.GREEN, j2Plan.getCurrentInterval());
        assertEquals(SignalState.GREEN, j2Plan.getSignalStateForRoad("R1"));
        assertEquals(SignalState.GREEN, j2Plan.getSignalStateForRoad("R2"));
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad("R6"));

        // Step by 14 seconds (still GREEN, 1s remaining)
        controller.step(14.0);
        assertEquals(PhaseInterval.GREEN, j2Plan.getCurrentInterval());
        assertEquals(SignalState.GREEN, j2Plan.getSignalStateForRoad("R1"));

        // Step by 2 seconds (now at t = 16s -> in YELLOW interval: 15s to 18s)
        controller.step(2.0);
        assertEquals(PhaseInterval.YELLOW, j2Plan.getCurrentInterval());
        assertEquals(SignalState.YELLOW, j2Plan.getSignalStateForRoad("R1"));
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad("R6"));

        // Step by 2.5 seconds (now at t = 18.5s -> in ALL_RED clearance interval: 18s to 19s)
        controller.step(2.5);
        assertEquals(PhaseInterval.ALL_RED, j2Plan.getCurrentInterval());
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad("R1"));
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad("R2"));
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad("R6"));

        // Step by 1 second (now at t = 19.5s -> Phase 1 GREEN should start)
        controller.step(1.0);
        assertEquals(1, j2Plan.getCurrentPhaseIndex());
        assertEquals(PhaseInterval.GREEN, j2Plan.getCurrentInterval());
        // Phase 1 gives green to R6, R1 and R2 become RED
        assertEquals(SignalState.GREEN, j2Plan.getSignalStateForRoad("R6"));
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad("R1"));
        assertEquals(SignalState.RED, j2Plan.getSignalStateForRoad("R2"));
    }

    @Test
    @DisplayName("Verify full cycle wraps around back to Phase 0")
    public void testFullCycleWrapAround() {
        SignalPlan j4Plan = controller.getSignalPlan("J4");
        // J4 has 2 phases, each 19s total -> full cycle = 38s
        assertEquals(0, j4Plan.getCurrentPhaseIndex());

        controller.step(19.0); // Now in Phase 1
        assertEquals(1, j4Plan.getCurrentPhaseIndex());

        controller.step(19.0); // Now wrapped back to Phase 0
        assertEquals(0, j4Plan.getCurrentPhaseIndex());
        assertEquals(PhaseInterval.GREEN, j4Plan.getCurrentInterval());
    }

    @Test
    @DisplayName("Verify synchronized model updates across all signalized approaches")
    public void testModelSynchronization() {
        controller.step(5.0); // Still phase 0 green

        Intersection j2 = cityMap.getIntersection("J2");
        // Signal for R1 should be green, R6 should be red
        assertEquals(com.traffic.core.model.SignalColor.GREEN, j2.getApproachSignal("R1").getState());
        assertEquals(com.traffic.core.model.SignalColor.RED, j2.getApproachSignal("R6").getState());
    }

    @Test
    @DisplayName("Verify every multi-way intersection services ALL its connected roads across its phases")
    public void testAllConnectedRoadsServicedAcrossPhases() {
        String[] signalized = { "J2", "J4", "J5", "J6", "J7", "J8", "J9" };
        for (String jId : signalized) {
            SignalPlan plan = controller.getSignalPlan(jId);
            assertNotNull(plan, "Plan must exist for " + jId);
            Intersection intersection = cityMap.getIntersection(jId);
            assertNotNull(intersection, "Intersection must exist: " + jId);

            java.util.Set<String> servicedRoads = new java.util.HashSet<>();
            for (SignalPhase phase : plan.getPhases()) {
                servicedRoads.addAll(phase.getGreenRoadIds());
            }

            for (Road road : intersection.getConnectedRoads()) {
                assertTrue(servicedRoads.contains(road.getId()),
                    "Junction " + jId + " fails to service connected road " + road.getId() + " in any phase!");
            }
        }
    }

    @Test
    @DisplayName("Verify over continuous time (120s) that NO conflicting movements receive green simultaneously")
    public void testContinuousSimulationConflictSafety() {
        TrafficSignalController sim = new TrafficSignalController(cityMap, 15.0, 3.0, 1.0);

        // Step through 120s of simulation in 0.5s time increments
        for (double t = 0.0; t <= 120.0; t += 0.5) {
            sim.step(0.5);

            for (Map.Entry<String, SignalPlan> entry : sim.getPlans().entrySet()) {
                String jId = entry.getKey();
                SignalPlan plan = entry.getValue();
                Intersection intersection = cityMap.getIntersection(jId);

                // Collect all roads currently holding GREEN at this intersection
                List<String> greenRoads = new ArrayList<>();
                for (Road road : intersection.getConnectedRoads()) {
                    if (intersection.getApproachSignal(road.getId()).getState() == com.traffic.core.model.SignalColor.GREEN) {
                        greenRoads.add(road.getId());
                    }
                }

                // If multiple roads are green, they must only be non-conflicting opposite approaches
                if (greenRoads.size() > 1) {
                    SignalPhase currentPhase = plan.getCurrentPhase();
                    List<TrafficMovement> activeMovements = currentPhase.getAllowedMovements();
                    for (int i = 0; i < activeMovements.size(); i++) {
                        for (int j = i + 1; j < activeMovements.size(); j++) {
                            TrafficMovement m1 = activeMovements.get(i);
                            TrafficMovement m2 = activeMovements.get(j);
                            assertFalse(m1.conflictsWith(m2),
                                "Simulation t=" + t + "s: Junction " + jId + " had simultaneous conflicting green movements: " + m1 + " vs " + m2);
                        }
                    }
                }
            }
        }
    }

    @Test
    @DisplayName("Verify that during ALL_RED clearance, ALL approaches at every signalized junction are RED")
    public void testAllRedClearanceIntervalStrictRedAcrossAllApproaches() {
        String[] signalized = { "J2", "J4", "J5", "J6", "J7", "J8", "J9" };
        TrafficSignalController sim = new TrafficSignalController(cityMap, 15.0, 3.0, 1.0);

        // Step to t = 18.2s (Phase 0 clearance interval: 18.0s - 19.0s)
        sim.step(18.2);

        for (String jId : signalized) {
            SignalPlan plan = sim.getSignalPlan(jId);
            assertEquals(PhaseInterval.ALL_RED, plan.getCurrentInterval(), "Junction " + jId + " should be in ALL_RED clearance");
            Intersection intersection = cityMap.getIntersection(jId);
            for (Road road : intersection.getConnectedRoads()) {
                assertEquals(com.traffic.core.model.SignalColor.RED,
                    intersection.getApproachSignal(road.getId()).getState(),
                    "During ALL_RED clearance, road " + road.getId() + " at " + jId + " must be strictly RED!");
            }
        }
    }

    @Test
    @DisplayName("Verify simulation clock step and reset behaviour")
    public void testSimulationClockControls() {
        assertEquals(0.0, controller.getSimulationTime(), 1e-6);

        controller.step(0.0);
        assertEquals(0.0, controller.getSimulationTime(), 1e-6);

        controller.step(-5.0);
        assertEquals(0.0, controller.getSimulationTime(), 1e-6);

        controller.step(12.5);
        assertEquals(12.5, controller.getSimulationTime(), 1e-6);

        controller.reset();
        assertEquals(0.0, controller.getSimulationTime(), 1e-6);
        for (SignalPlan plan : controller.getPlans().values()) {
            assertEquals(0, plan.getCurrentPhaseIndex());
            assertEquals(PhaseInterval.GREEN, plan.getCurrentInterval());
        }
    }

    @Test
    @DisplayName("Verify city road graph matches user specification exactly (10 junctions, 15 roads, max 4 roads/junction)")
    public void testRoadGraphTopologyMatchesSpecification() {
        assertEquals(10, cityMap.getIntersections().size(), "Must have exactly 10 intersections (J1 - J10)");
        assertEquals(15, cityMap.getRoads().size(), "Must have exactly 15 roads");

        // Verify all 15 expected connections exist
        String[][] expectedConnections = {
            {"J1", "J2"}, {"J1", "J4"},
            {"J2", "J3"}, {"J2", "J5"}, {"J2", "J6"},
            {"J4", "J5"}, {"J4", "J8"},
            {"J5", "J6"}, {"J5", "J8"},
            {"J6", "J7"}, {"J6", "J9"},
            {"J7", "J3"}, {"J7", "J10"},
            {"J8", "J9"},
            {"J9", "J10"}
        };

        for (String[] conn : expectedConnections) {
            String u = conn[0];
            String v = conn[1];
            boolean found = cityMap.getRoads().stream().anyMatch(r ->
                (r.getIntersectionA().getId().equals(u) && r.getIntersectionB().getId().equals(v)) ||
                (r.getIntersectionA().getId().equals(v) && r.getIntersectionB().getId().equals(u))
            );
            assertTrue(found, "Road connection " + u + "-" + v + " must exist in graph!");
        }

        // Verify removed roads do NOT exist
        boolean j1j5Exists = cityMap.getRoads().stream().anyMatch(r ->
            (r.getIntersectionA().getId().equals("J1") && r.getIntersectionB().getId().equals("J5")) ||
            (r.getIntersectionA().getId().equals("J5") && r.getIntersectionB().getId().equals("J1"))
        );
        assertFalse(j1j5Exists, "Removed road J1-J5 must NOT exist");

        boolean j3j6Exists = cityMap.getRoads().stream().anyMatch(r ->
            (r.getIntersectionA().getId().equals("J3") && r.getIntersectionB().getId().equals("J6")) ||
            (r.getIntersectionA().getId().equals("J6") && r.getIntersectionB().getId().equals("J3"))
        );
        assertFalse(j3j6Exists, "Removed road J3-J6 must NOT exist");

        // Verify max 4 roads per junction
        for (Intersection node : cityMap.getIntersections().values()) {
            assertTrue(node.getConnectedRoads().size() <= 4,
                "Intersection " + node.getId() + " has " + node.getConnectedRoads().size() + " roads (max allowed is 4)");
        }
    }

    @Test
    @DisplayName("Verify SignalPhase safety assertions on invalid timings and conflicting movements")
    public void testSignalPhaseSafetyAssertions() {
        TrafficMovement m1 = new TrafficMovement("M1", "J2", "R1", "R2", "Straight");
        TrafficMovement m2 = new TrafficMovement("M2", "J2", "R6", "R1", "Turn");

        // Conflicting movements must throw IllegalArgumentException
        assertThrows(IllegalArgumentException.class, () -> {
            new SignalPhase("PH_ERR", "Illegal", List.of(m1, m2), 15.0, 3.0, 1.0);
        });

        // Non-positive green duration must throw IllegalArgumentException
        assertThrows(IllegalArgumentException.class, () -> {
            new SignalPhase("PH_ERR2", "Illegal", List.of(m1), 0.0, 3.0, 1.0);
        });

        // Non-positive yellow duration must throw IllegalArgumentException
        assertThrows(IllegalArgumentException.class, () -> {
            new SignalPhase("PH_ERR3", "Illegal", List.of(m1), 15.0, 0.0, 1.0);
        });

        // Negative all-red duration must throw IllegalArgumentException
        assertThrows(IllegalArgumentException.class, () -> {
            new SignalPhase("PH_ERR4", "Illegal", List.of(m1), 15.0, 3.0, -1.0);
        });
    }
}
