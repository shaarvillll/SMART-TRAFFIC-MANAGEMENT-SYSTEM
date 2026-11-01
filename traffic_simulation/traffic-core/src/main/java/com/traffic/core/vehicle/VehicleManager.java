package com.traffic.core.vehicle;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Road;
import com.traffic.core.routing.Route;
import com.traffic.core.signal.SignalPlan;
import com.traffic.core.signal.SignalState;
import com.traffic.core.signal.TrafficSignalController;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Manages vehicle lifecycles, kinematics, car-following spacing,
 * and traffic signal compliance.
 */
public class VehicleManager {

    private final CityMap cityMap;
    private final List<Vehicle> vehicles;
    private final AtomicInteger vehicleCounter;
    private static final double STOP_LINE_OFFSET = 26.0;   // Distance from intersection center
    private static final double MIN_CAR_GAP = 16.0;         // Minimum distance gap behind vehicle ahead

    public VehicleManager(CityMap cityMap) {
        this.cityMap = cityMap;
        this.vehicles = new ArrayList<>();
        this.vehicleCounter = new AtomicInteger(1);
    }

    /**
     * Creates and registers a new vehicle along a calculated route.
     */
    public synchronized Vehicle spawnVehicle(VehicleType type, Intersection source, Intersection destination, Route route) {
        if (route == null || !route.isValid() || route.isEmpty()) {
            throw new IllegalArgumentException("Cannot spawn vehicle with invalid or empty route");
        }
        String id = String.format("V-%02d", vehicleCounter.getAndIncrement());
        Vehicle vehicle = new Vehicle(id, type, source, destination, route);

        // Check if another vehicle is already departing the same source along the first road
        Road firstRoad = route.getRoads().get(0);
        Intersection firstFrom = route.getPath().get(0);
        for (Vehicle other : vehicles) {
            if (other.getStatus() != VehicleStatus.COMPLETED &&
                firstRoad.equals(other.getCurrentRoad()) &&
                firstFrom.equals(other.getCurrentFromIntersection())) {
                if (other.getDistanceAlongRoad() < other.getType().getLength() + MIN_CAR_GAP) {
                    vehicle.setStatus(VehicleStatus.WAITING);
                    break;
                }
            }
        }

        vehicles.add(vehicle);
        return vehicle;
    }

    public synchronized List<Vehicle> getVehicles() {
        return Collections.unmodifiableList(new ArrayList<>(vehicles));
    }

    public synchronized Vehicle getVehicleById(String id) {
        for (Vehicle v : vehicles) {
            if (v.getId().equalsIgnoreCase(id)) return v;
        }
        return null;
    }

    public synchronized void removeVehicle(Vehicle vehicle) {
        vehicles.remove(vehicle);
    }

    public synchronized void clearVehicles() {
        vehicles.clear();
        vehicleCounter.set(1);
    }

    /**
     * Step the simulation for all vehicles by deltaSeconds.
     */
    public synchronized void step(double deltaSeconds, TrafficSignalController signalController) {
        if (deltaSeconds <= 0.0) return;

        for (Vehicle vehicle : vehicles) {
            if (vehicle.getStatus() == VehicleStatus.COMPLETED) {
                continue;
            }

            Road currentRoad = vehicle.getCurrentRoad();
            if (currentRoad == null) {
                vehicle.setStatus(VehicleStatus.COMPLETED);
                continue;
            }

            vehicle.addTripDuration(deltaSeconds);

            double roadLen = currentRoad.getLength();
            double targetSpeed = vehicle.getType().getBaseSpeed();
            double distToIntersection = roadLen - vehicle.getDistanceAlongRoad();
            Intersection toNode = vehicle.getCurrentToIntersection();
            boolean isLastSegment = (vehicle.getCurrentRouteIndex() >= vehicle.getRoute().getRoads().size() - 1);

            // 1. Check departure headway for WAITING vehicles at start of trip
            if (vehicle.getDistanceAlongRoad() <= 2.0 && vehicle.getStatus() == VehicleStatus.WAITING) {
                boolean startBlocked = false;
                Intersection fromNode = vehicle.getCurrentFromIntersection();
                for (Vehicle other : vehicles) {
                    if (other == vehicle || other.getStatus() == VehicleStatus.COMPLETED) continue;
                    if (currentRoad.equals(other.getCurrentRoad()) && fromNode != null && fromNode.equals(other.getCurrentFromIntersection())) {
                        if (other.getDistanceAlongRoad() > 0.0 && other.getDistanceAlongRoad() < other.getType().getLength() + MIN_CAR_GAP) {
                            startBlocked = true;
                            break;
                        }
                    }
                }
                if (startBlocked) {
                    targetSpeed = 0.0;
                    vehicle.setCurrentSpeed(0.0);
                    continue;
                } else {
                    vehicle.setStatus(VehicleStatus.MOVING);
                }
            }

            // 2. Traffic Signal Compliance at toNode (including destination junctions!)
            if (toNode != null && signalController != null) {
                SignalPlan plan = signalController.getSignalPlan(toNode.getId());
                if (plan != null) {
                    SignalState sigState = plan.getSignalStateForRoad(currentRoad.getId());

                    if (sigState == SignalState.RED) {
                        // Vehicle must stop before stop line
                        if (distToIntersection <= STOP_LINE_OFFSET + 6.0) {
                            targetSpeed = 0.0;
                            vehicle.setStatus(VehicleStatus.STOPPED_AT_SIGNAL);
                            vehicle.addWaitTime(deltaSeconds);
                            if (vehicle.getDistanceAlongRoad() > roadLen - STOP_LINE_OFFSET) {
                                vehicle.setDistanceAlongRoad(roadLen - STOP_LINE_OFFSET);
                            }
                        }
                    } else if (sigState == SignalState.YELLOW) {
                        // If approaching and not yet in junction, slow down and stop
                        if (distToIntersection > 10.0 && distToIntersection <= STOP_LINE_OFFSET + 8.0) {
                            targetSpeed = 0.0;
                            vehicle.setStatus(VehicleStatus.STOPPED_AT_SIGNAL);
                            vehicle.addWaitTime(deltaSeconds);
                            if (vehicle.getDistanceAlongRoad() > roadLen - STOP_LINE_OFFSET) {
                                vehicle.setDistanceAlongRoad(roadLen - STOP_LINE_OFFSET);
                            }
                        }
                    } else if (sigState == SignalState.GREEN) {
                        // Permitted to proceed
                        if (vehicle.getStatus() == VehicleStatus.STOPPED_AT_SIGNAL) {
                            vehicle.setStatus(VehicleStatus.MOVING);
                        }
                    }
                }
            }

            // 3. Intersection Clearance Lock: Prevent entering an intersection when another vehicle is currently crossing it
            if (toNode != null && distToIntersection <= STOP_LINE_OFFSET + 4.0 && targetSpeed > 0.0) {
                double junctionRadius = 30.0;
                boolean junctionOccupied = false;
                for (Vehicle other : vehicles) {
                    if (other == vehicle || other.getStatus() == VehicleStatus.COMPLETED) continue;
                    // Check if other vehicle is currently inside toNode
                    double distToCenter = Math.hypot(other.getX() - toNode.getX(), other.getY() - toNode.getY());
                    if (distToCenter < junctionRadius) {
                        // If other is on the same road behind us, ignore
                        if (currentRoad.equals(other.getCurrentRoad()) && other.getDistanceAlongRoad() < vehicle.getDistanceAlongRoad()) {
                            continue;
                        }
                        junctionOccupied = true;
                        break;
                    }
                }
                if (junctionOccupied) {
                    targetSpeed = 0.0;
                    if (vehicle.getStatus() != VehicleStatus.STOPPED_AT_SIGNAL) {
                        vehicle.setStatus(VehicleStatus.WAITING);
                    }
                    if (vehicle.getDistanceAlongRoad() > roadLen - STOP_LINE_OFFSET) {
                        vehicle.setDistanceAlongRoad(roadLen - STOP_LINE_OFFSET);
                    }
                }
            }

            // 4. Next-Road Entry Clearance: Prevent entering next road if its entrance is blocked
            if (!isLastSegment && distToIntersection <= STOP_LINE_OFFSET + 2.0 && targetSpeed > 0.0) {
                int nextIdx = vehicle.getCurrentRouteIndex() + 1;
                Road nextRoad = vehicle.getRoute().getRoads().get(nextIdx);
                Intersection nextFrom = vehicle.getRoute().getPath().get(nextIdx);
                for (Vehicle other : vehicles) {
                    if (other == vehicle || other.getStatus() == VehicleStatus.COMPLETED) continue;
                    if (nextRoad.equals(other.getCurrentRoad()) && nextFrom.equals(other.getCurrentFromIntersection())) {
                        if (other.getDistanceAlongRoad() < other.getType().getLength() + MIN_CAR_GAP) {
                            targetSpeed = 0.0;
                            if (vehicle.getStatus() != VehicleStatus.STOPPED_AT_SIGNAL) {
                                vehicle.setStatus(VehicleStatus.WAITING);
                            }
                            if (vehicle.getDistanceAlongRoad() > roadLen - STOP_LINE_OFFSET) {
                                vehicle.setDistanceAlongRoad(roadLen - STOP_LINE_OFFSET);
                            }
                            break;
                        }
                    }
                }
            }

            // 5. Car-Following and Anti-Overlap Spacing on the same road
            for (Vehicle other : vehicles) {
                if (other == vehicle || other.getStatus() == VehicleStatus.COMPLETED) continue;

                if (currentRoad.equals(other.getCurrentRoad())) {
                    Intersection fromNode = vehicle.getCurrentFromIntersection();
                    Intersection otherFrom = other.getCurrentFromIntersection();

                    // Same travel direction on current road
                    if (fromNode != null && fromNode.equals(otherFrom)) {
                        double distA = other.getDistanceAlongRoad();
                        double distB = vehicle.getDistanceAlongRoad();
                        double safeGap = other.getType().getLength() + MIN_CAR_GAP;

                        boolean otherIsAhead = (distA > distB) || (distA == distB && other.getId().compareTo(vehicle.getId()) < 0);

                        if (otherIsAhead) {
                            double gap = distA - distB - other.getType().getLength();
                            if (gap < MIN_CAR_GAP) {
                                targetSpeed = Math.min(targetSpeed, other.getCurrentSpeed());
                                if (gap <= 8.0) {
                                    targetSpeed = 0.0;
                                }
                                if (vehicle.getStatus() != VehicleStatus.STOPPED_AT_SIGNAL) {
                                    vehicle.setStatus(VehicleStatus.WAITING);
                                }
                                double maxAllowedDist = Math.max(0.0, distA - safeGap);
                                if (vehicle.getDistanceAlongRoad() > maxAllowedDist) {
                                    vehicle.setDistanceAlongRoad(maxAllowedDist);
                                }
                                break;
                            }
                        }
                    }
                }
            }

            // 6. Global 2D Proximity Anti-Overlap Guard
            for (Vehicle other : vehicles) {
                if (other == vehicle || other.getStatus() == VehicleStatus.COMPLETED) continue;
                double dist2D = Math.hypot(vehicle.getX() - other.getX(), vehicle.getY() - other.getY());
                double minCenterDist = (vehicle.getType().getLength() + other.getType().getLength()) / 2.0 + 6.0;
                if (dist2D < minCenterDist) {
                    if (other.getId().compareTo(vehicle.getId()) < 0) {
                        targetSpeed = 0.0;
                        if (vehicle.getStatus() != VehicleStatus.STOPPED_AT_SIGNAL) {
                            vehicle.setStatus(VehicleStatus.WAITING);
                        }
                        break;
                    }
                }
            }

            // 7. Kinematic Advancement
            if (targetSpeed > 0.0) {
                vehicle.setStatus(VehicleStatus.MOVING);
                vehicle.setCurrentSpeed(targetSpeed);
                double moveDist = targetSpeed * deltaSeconds;
                double nextDist = vehicle.getDistanceAlongRoad() + moveDist;

                if (nextDist >= roadLen) {
                    int nextIndex = vehicle.getCurrentRouteIndex() + 1;
                    if (nextIndex >= vehicle.getRoute().getRoads().size()) {
                        vehicle.setCurrentRouteIndex(nextIndex);
                        vehicle.setDistanceAlongRoad(0.0);
                        vehicle.setStatus(VehicleStatus.COMPLETED);
                        vehicle.setCurrentSpeed(0.0);
                    } else {
                        double overflow = nextDist - roadLen;
                        vehicle.setCurrentRouteIndex(nextIndex);
                        vehicle.setDistanceAlongRoad(overflow);
                    }
                } else {
                    vehicle.setDistanceAlongRoad(nextDist);
                }
            } else {
                vehicle.setCurrentSpeed(0.0);
            }
        }
    }
}
