package com.traffic.api;

import com.traffic.core.model.CityMap;
import com.traffic.core.routing.RouteFinder;
import com.traffic.core.signal.TrafficSignalController;
import com.traffic.core.vehicle.VehicleManager;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

/**
 * Singleton simulation engine that runs the traffic simulation
 * on a background thread and exposes core components to the API layer.
 */
public class SimulationEngine {

    private static SimulationEngine instance;

    private final CityMap cityMap;
    private final TrafficSignalController signalController;
    private final VehicleManager vehicleManager;
    private final RouteFinder routeFinder;

    private final ScheduledExecutorService scheduler;
    private ScheduledFuture<?> simTask;

    private static final long TICK_MS = 100;
    private volatile double timeScale = 1.0;
    private volatile boolean paused = false;

    private SimulationEngine() {
        cityMap = new CityMap();
        signalController = new TrafficSignalController(cityMap, 5.0, 1.5, 0.5);
        vehicleManager = new VehicleManager(cityMap);
        routeFinder = new RouteFinder();
        scheduler = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "sim-engine");
            t.setDaemon(true);
            return t;
        });
    }

    public static synchronized SimulationEngine getInstance() {
        if (instance == null) instance = new SimulationEngine();
        return instance;
    }

    public void start() {
        simTask = scheduler.scheduleAtFixedRate(() -> {
            if (!paused) {
                double delta = (TICK_MS / 1000.0) * timeScale;
                signalController.step(delta, vehicleManager);
                vehicleManager.step(delta, signalController);
            }
        }, 0, TICK_MS, TimeUnit.MILLISECONDS);
        System.out.println("[SimEngine] Simulation started");
    }

    public void stop() { if (simTask != null) simTask.cancel(false); }

    public CityMap getCityMap() { return cityMap; }
    public TrafficSignalController getSignalController() { return signalController; }
    public VehicleManager getVehicleManager() { return vehicleManager; }
    public RouteFinder getRouteFinder() { return routeFinder; }

    public void setPaused(boolean paused) { this.paused = paused; }
    public boolean isPaused() { return paused; }
    public void setTimeScale(double scale) { this.timeScale = scale; }
    public double getTimeScale() { return timeScale; }

    public void reset() {
        vehicleManager.clearVehicles();
        signalController.reset();
    }
}