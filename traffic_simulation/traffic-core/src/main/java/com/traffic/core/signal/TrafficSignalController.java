package com.traffic.core.signal;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import com.traffic.core.model.SignalColor;
import com.traffic.core.model.TrafficSignal;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * TrafficSignalController manages authoritative traffic signals across all signalized intersections.
 * Uses deterministic simulation clock ticks rather than separate independent UI timers.
 *
 * Default timing parameters (configurable):
 * - Green: 15.0 seconds
 * - Yellow: 3.0 seconds
 * - All-Red: 1.0 seconds
 */
public class TrafficSignalController {

    public static final double DEFAULT_GREEN_SECONDS = 5.0;
    public static final double DEFAULT_YELLOW_SECONDS = 1.5;
    public static final double DEFAULT_ALL_RED_SECONDS = 0.5;

    private final CityMap cityMap;
    private final Map<String, SignalPlan> plans;
    private double simulationTime;

    public TrafficSignalController(CityMap cityMap) {
        this(cityMap, DEFAULT_GREEN_SECONDS, DEFAULT_YELLOW_SECONDS, DEFAULT_ALL_RED_SECONDS);
    }

    public TrafficSignalController(CityMap cityMap, double greenSeconds, double yellowSeconds, double allRedSeconds) {
        this.cityMap = cityMap;
        this.plans = new LinkedHashMap<>();
        this.simulationTime = 0.0;
        initializePlans(greenSeconds, yellowSeconds, allRedSeconds);
        applySignalsToModel();
    }

    /**
     * Initializes customized signal plans for each multi-way intersection on the map.
     * Only intersections with > 2 connecting roads have signal plans (J2, J4, J5, J6, J7, J8, J9).
     */
    private void initializePlans(double g, double y, double r) {
        // --- 1. J2 (4-way intersection): North-South vs East-West vs Diagonal ---
        // Connected roads: R1 (from J1 West), R2 (to J3 East), R6 (to J5 South), R10_D (to J6 Southeast)
        List<SignalPhase> j2Phases = new ArrayList<>();
        // Phase 1: East-West Arterial Corridor (R1 & R2)
        List<TrafficMovement> j2p1 = List.of(
            new TrafficMovement("J2_M_R1_R2", "J2", "R1", "R2", "R1 Westbound to R2 Eastbound"),
            new TrafficMovement("J2_M_R2_R1", "J2", "R2", "R1", "R2 Eastbound to R1 Westbound")
        );
        j2Phases.add(new SignalPhase("J2_PH_1", "East-West Arterial", j2p1, g, y, r));

        // Phase 2: South Link (R6)
        List<TrafficMovement> j2p2 = List.of(
            new TrafficMovement("J2_M_R6_R1", "J2", "R6", "R1", "R6 Northbound to R1 Westbound")
        );
        j2Phases.add(new SignalPhase("J2_PH_2", "South Civic Approach", j2p2, g, y, r));

        // Phase 3: Southeast Diagonal Express (R10_D)
        List<TrafficMovement> j2p3 = List.of(
            new TrafficMovement("J2_M_R10_R2", "J2", "R10_D", "R2", "R10_D Northwest to R2 Eastbound")
        );
        j2Phases.add(new SignalPhase("J2_PH_3", "Southeast Diagonal Bypass", j2p3, g, y, r));
        plans.put("J2", new SignalPlan("J2", j2Phases));

        // --- 2. J4 (3-way T-junction): Station Corridor ---
        // Connected roads: R3 (from J1 North), R5 (to J5 East), R4 (to J8 South)
        List<SignalPhase> j4Phases = new ArrayList<>();
        // Phase 1: North-South Western Corridor (R3 & R4)
        List<TrafficMovement> j4p1 = List.of(
            new TrafficMovement("J4_M_R3_R4", "J4", "R3", "R4", "North R3 to South R4"),
            new TrafficMovement("J4_M_R4_R3", "J4", "R4", "R3", "South R4 to North R3")
        );
        j4Phases.add(new SignalPhase("J4_PH_1", "Western Spine Corridor", j4p1, g, y, r));

        // Phase 2: East Cross Link (R5)
        List<TrafficMovement> j4p2 = List.of(
            new TrafficMovement("J4_M_R5_R3", "J4", "R5", "R3", "East R5 to North R3")
        );
        j4Phases.add(new SignalPhase("J4_PH_2", "Station East Cross Link", j4p2, g, y, r));
        plans.put("J4", new SignalPlan("J4", j4Phases));

        // --- 3. J5 (4-way crossroad): Civic Central Hub ---
        // Connected roads: R6 (North to J2), R8 (East to J6), R14 (Southwest to J8), R5 (West to J4)
        List<SignalPhase> j5Phases = new ArrayList<>();
        // Phase 1: East-West Axis (R5 & R8)
        List<TrafficMovement> j5p1 = List.of(
            new TrafficMovement("J5_M_R5_R8", "J5", "R5", "R8", "West R5 to East R8"),
            new TrafficMovement("J5_M_R8_R5", "J5", "R8", "R5", "East R8 to West R5")
        );
        j5Phases.add(new SignalPhase("J5_PH_1", "Central Boulevard East-West", j5p1, g, y, r));

        // Phase 2: North Connector (R6)
        List<TrafficMovement> j5p2 = List.of(
            new TrafficMovement("J5_M_R6_R14", "J5", "R6", "R14", "North R6 to Southwest R14")
        );
        j5Phases.add(new SignalPhase("J5_PH_2", "Civic Park North Approach", j5p2, g, y, r));

        // Phase 3: Southwest Connector (R14)
        List<TrafficMovement> j5p3 = List.of(
            new TrafficMovement("J5_M_R14_R8", "J5", "R14", "R8", "Southwest R14 to East R8")
        );
        j5Phases.add(new SignalPhase("J5_PH_3", "Midtown South Link Approach", j5p3, g, y, r));
        plans.put("J5", new SignalPlan("J5", j5Phases));

        // --- 4. J6 (4-way intersection): Downtown City Center ---
        // Connected roads: R8 (West to J5), R9 (East to J7), R10_D (Northwest to J2), R15 (South to J9)
        List<SignalPhase> j6Phases = new ArrayList<>();
        // Phase 1: East-West Core (R8 & R9)
        List<TrafficMovement> j6p1 = List.of(
            new TrafficMovement("J6_M_R8_R9", "J6", "R8", "R9", "West R8 to East R9"),
            new TrafficMovement("J6_M_R9_R8", "J6", "R9", "R8", "East R9 to West R8")
        );
        j6Phases.add(new SignalPhase("J6_PH_1", "Downtown East-West Axis", j6p1, g, y, r));

        // Phase 2: South Mall Parkway (R15)
        List<TrafficMovement> j6p2 = List.of(
            new TrafficMovement("J6_M_R15_R8", "J6", "R15", "R8", "South R15 to West R8")
        );
        j6Phases.add(new SignalPhase("J6_PH_2", "Mall Parkway South Approach", j6p2, g, y, r));

        // Phase 3: Northwest Diagonal Bypass (R10_D)
        List<TrafficMovement> j6p3 = List.of(
            new TrafficMovement("J6_M_R10_R9", "J6", "R10_D", "R9", "Diagonal R10_D to East R9")
        );
        j6Phases.add(new SignalPhase("J6_PH_3", "Hospital Diagonal Approach", j6p3, g, y, r));
        plans.put("J6", new SignalPlan("J6", j6Phases));

        // --- 5. J7 (3-way T-junction): East Industrial Link ---
        // Connected roads: R12_D (North to J3), R9 (West to J6), R17 (South to J10)
        List<SignalPhase> j7Phases = new ArrayList<>();
        // Phase 1: North-South Outer Ring (R12_D & R17)
        List<TrafficMovement> j7p1 = List.of(
            new TrafficMovement("J7_M_R12_R17", "J7", "R12_D", "R17", "North R12_D to South R17"),
            new TrafficMovement("J7_M_R17_R12", "J7", "R17", "R12_D", "South R17 to North R12_D")
        );
        j7Phases.add(new SignalPhase("J7_PH_1", "East Ring Highway", j7p1, g, y, r));

        // Phase 2: West Inbound (R9)
        List<TrafficMovement> j7p2 = List.of(
            new TrafficMovement("J7_M_R9_R17", "J7", "R9", "R17", "West R9 to South R17")
        );
        j7Phases.add(new SignalPhase("J7_PH_2", "Commercial Inbound Approach", j7p2, g, y, r));
        plans.put("J7", new SignalPlan("J7", j7Phases));

        // --- 6. J8 (3-way Y-junction): Metro University Campus ---
        // Connected roads: R4 (North to J4), R14 (Northeast to J5), R13 (East to J9)
        List<SignalPhase> j8Phases = new ArrayList<>();
        // Phase 1: North-East Main Approach (R4)
        List<TrafficMovement> j8p1 = List.of(
            new TrafficMovement("J8_M_R4_R13", "J8", "R4", "R13", "North R4 to East R13")
        );
        j8Phases.add(new SignalPhase("J8_PH_1", "Station West Inbound", j8p1, g, y, r));

        // Phase 2: Midtown South Approach (R14)
        List<TrafficMovement> j8p2 = List.of(
            new TrafficMovement("J8_M_R14_R13", "J8", "R14", "R13", "Northeast R14 to East R13")
        );
        j8Phases.add(new SignalPhase("J8_PH_2", "Midtown Inbound Approach", j8p2, g, y, r));

        // Phase 3: East University Ring Road (R13)
        List<TrafficMovement> j8p3 = List.of(
            new TrafficMovement("J8_M_R13_R4", "J8", "R13", "R4", "East R13 to North R4")
        );
        j8Phases.add(new SignalPhase("J8_PH_3", "Campus Ring Road", j8p3, g, y, r));
        plans.put("J8", new SignalPlan("J8", j8Phases));

        // --- 7. J9 (3-way T-junction): South Commercial Hub ---
        // Connected roads: R15 (North to J6), R13 (West to J8), R16 (East to J10)
        List<SignalPhase> j9Phases = new ArrayList<>();
        // Phase 1: Southern Ring Perimeter (R13 & R16)
        List<TrafficMovement> j9p1 = List.of(
            new TrafficMovement("J9_M_R13_R16", "J9", "R13", "R16", "West R13 to East R16"),
            new TrafficMovement("J9_M_R16_R13", "J9", "R16", "R13", "East R16 to West R13")
        );
        j9Phases.add(new SignalPhase("J9_PH_1", "Southern Arterial Corridor", j9p1, g, y, r));

        // Phase 2: Downtown North Inbound (R15)
        List<TrafficMovement> j9p2 = List.of(
            new TrafficMovement("J9_M_R15_R16", "J9", "R15", "R16", "North R15 to East R16")
        );
        j9Phases.add(new SignalPhase("J9_PH_2", "Downtown Mall Inbound Approach", j9p2, g, y, r));
        plans.put("J9", new SignalPlan("J9", j9Phases));
    }

    /**
     * Advance the authoritative simulation clock by deltaSeconds.
     */
    public void step(double deltaSeconds) {
        step(deltaSeconds, null);
    }

    /**
     * Intelligent simulation step with dynamic queue clearance & emergency green corridors.
     */
    public void step(double deltaSeconds, com.traffic.core.vehicle.VehicleManager vehicleManager) {
        if (deltaSeconds <= 0.0) return;
        simulationTime += deltaSeconds;

        // Dynamic Queue Clearance & Priority Green Corridors
        if (vehicleManager != null) {
            for (com.traffic.core.vehicle.Vehicle v : vehicleManager.getVehicles()) {
                if (v.getStatus() == com.traffic.core.vehicle.VehicleStatus.COMPLETED) continue;
                Intersection to = v.getCurrentToIntersection();
                Road road = v.getCurrentRoad();
                if (to != null && road != null) {
                    SignalPlan plan = plans.get(to.getId());
                    if (plan != null) {
                        // Emergency vehicle (Ambulance/TRUCK) gets INSTANT green corridor!
                        if (v.getType() == com.traffic.core.vehicle.VehicleType.TRUCK) {
                            plan.requestGreenForRoad(road.getId());
                        }
                        // Any car or bus waiting for >= 2.0s triggers snappy green clearing
                        else if (v.getStatus() == com.traffic.core.vehicle.VehicleStatus.STOPPED_AT_SIGNAL && v.getWaitTimeSeconds() >= 2.0) {
                            plan.requestGreenForRoad(road.getId());
                        }
                    }
                }
            }
        }

        for (SignalPlan plan : plans.values()) {
            plan.step(deltaSeconds);
        }
        applySignalsToModel();
    }

    /**
     * Request priority green for an incoming road approach at a junction.
     */
    public boolean requestGreenForRoad(String junctionId, String roadId) {
        SignalPlan plan = plans.get(junctionId);
        if (plan != null) {
            boolean switched = plan.requestGreenForRoad(roadId);
            if (switched) applySignalsToModel();
            return switched;
        }
        return false;
    }

    /**
     * Syncs the computed signal states into the core model's TrafficSignal objects
     * so that the JavaFX renderer automatically paints the exact authoritative states.
     */
    public void applySignalsToModel() {
        for (Map.Entry<String, SignalPlan> entry : plans.entrySet()) {
            String junctionId = entry.getKey();
            SignalPlan plan = entry.getValue();
            Intersection intersection = cityMap.getIntersection(junctionId);
            if (intersection == null) continue;

            for (Road road : intersection.getConnectedRoads()) {
                TrafficSignal signal = intersection.getApproachSignal(road.getId());
                SignalState state = plan.getSignalStateForRoad(road.getId());
                switch (state) {
                    case GREEN:
                        signal.setState(SignalColor.GREEN);
                        break;
                    case YELLOW:
                        signal.setState(SignalColor.YELLOW);
                        break;
                    case RED:
                    default:
                        signal.setState(SignalColor.RED);
                        break;
                }
            }
        }
    }

    public SignalPlan getSignalPlan(String intersectionId) {
        return plans.get(intersectionId);
    }

    public Map<String, SignalPlan> getPlans() {
        return Collections.unmodifiableMap(plans);
    }

    public double getSimulationTime() {
        return simulationTime;
    }

    public void reset() {
        simulationTime = 0.0;
        for (SignalPlan plan : plans.values()) {
            plan.reset();
        }
        applySignalsToModel();
    }
}
