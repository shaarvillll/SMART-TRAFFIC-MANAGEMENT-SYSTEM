package com.traffic.desktop;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Landmark;
import com.traffic.core.model.Road;
import com.traffic.core.model.RoadCondition;
import com.traffic.core.routing.Route;
import com.traffic.core.routing.RouteFinder;
import com.traffic.core.signal.TrafficSignalController;
import com.traffic.core.vehicle.Vehicle;
import com.traffic.core.vehicle.VehicleManager;
import com.traffic.core.vehicle.VehicleStatus;
import com.traffic.core.vehicle.VehicleType;
import com.traffic.desktop.renderer.MapCanvasRenderer;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import javafx.scene.Scene;
import javafx.scene.canvas.Canvas;
import javafx.scene.control.Button;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.ProgressBar;
import javafx.scene.control.ScrollPane;
import javafx.scene.control.Separator;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.Priority;
import javafx.scene.layout.VBox;
import javafx.scene.paint.Color;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.stage.Stage;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Intelligent Traffic Desktop Simulator:
 * Irregular City Road Network Prototype featuring:
 * - Deterministic Fixed-Time Traffic Signals (curbside 3-aspect heads).
 * - Dijkstra Shortest-Path Dynamic Routing.
 * - Multi-Vehicle Movement & Anti-Collision Car Following.
 * - Interactive Trip Dispatcher & Live Vehicle Fleet HUD.
 *
 * BACKEND INTEGRATION (v2):
 * When connected to the deployed backend, the desktop acts as a second client
 * of the same simulation that Flutter uses. Vehicle positions, signals, and road
 * states all come from the backend WebSocket (/ws/live). Spawning a vehicle POSTs
 * to /api/spawn and the vehicle immediately appears in both the desktop AND Flutter.
 * When the backend is unreachable, falls back to the original local simulation.
 */
public class TrafficDesktopApp extends Application {

    // ─── Backend integration ────────────────────────────────────────────────────
    /** Override via -DBACKEND_URL=... JVM arg or BACKEND_URL system property. */
    private BackendClient backendClient;
    private volatile boolean isConnectedToBackend = false;
    // Ghost vehicles from backend WS (connected mode)
    private volatile List<GhostVehicle> ghostVehicles = new ArrayList<>();
    private volatile String selectedGhostId = null;

    // ─── Local simulation (offline fallback) ───────────────────────────────────
    private CityMap cityMap;
    private TrafficSignalController signalController;
    private RouteFinder routeFinder;
    private VehicleManager vehicleManager;
    private MapCanvasRenderer renderer;
    private Canvas canvas;
    private javafx.animation.AnimationTimer animationTimer;

    // Simulation Clock state
    private boolean isPaused = false;
    private double timeSpeed = 1.0;
    private Label clockLabel;

    // Vehicle trip selection state (used in both modes)
    private Vehicle selectedVehicle = null;
    private Route previewRoute = null;

    // UI Controls for Add Vehicle panel
    private ComboBox<VehicleType> vehicleTypeCombo;
    private ComboBox<String> sourceCombo;
    private ComboBox<String> destinationCombo;
    private Label routePreviewLabel;
    private Label routeDistanceLabel;
    private Label routeStatusLabel;
    private Button startTripBtn;
    private VBox vehicleListContainer;
    private long lastUiUpdateNano = 0L;

    // Connection status label in header
    private Label connectionStatusLabel;

    @Override
    public void start(Stage primaryStage) {
        cityMap = new CityMap();
        signalController = new TrafficSignalController(cityMap, 15.0, 3.0, 1.0);
        routeFinder = new RouteFinder();
        vehicleManager = new VehicleManager(cityMap);
        renderer = new MapCanvasRenderer();

        BorderPane root = new BorderPane();
        root.setStyle("-fx-background-color: #0b0f19;");

        // Top Header
        VBox topHeader = createHeader();
        root.setTop(topHeader);

        // Center: Responsive Canvas container that resizes with window
        javafx.scene.layout.Pane canvasContainer = new javafx.scene.layout.Pane();
        canvasContainer.setStyle("-fx-background-color: #090d16;");
        canvas = new Canvas(1020, 860);
        canvasContainer.getChildren().add(canvas);

        // Bind canvas size to parent container size
        canvas.widthProperty().bind(canvasContainer.widthProperty());
        canvas.heightProperty().bind(canvasContainer.heightProperty());

        // Re-render automatically on window resize
        canvas.widthProperty().addListener((obs, oldVal, newVal) -> redraw());
        canvas.heightProperty().addListener((obs, oldVal, newVal) -> redraw());

        root.setCenter(canvasContainer);

        // Right: Information & Control Sidebar
        VBox sidebar = createSidebar();
        ScrollPane sidebarScroll = new ScrollPane(sidebar);
        sidebarScroll.setFitToWidth(true);
        sidebarScroll.setStyle("-fx-background: #111827; -fx-border-color: #1f2937; -fx-background-color: transparent;");
        root.setRight(sidebarScroll);

        Scene scene = new Scene(root, 1420, 960);
        primaryStage.setTitle("Intelligent Traffic Simulator — Connected to Live Backend");
        primaryStage.setScene(scene);
        primaryStage.setResizable(true);
        primaryStage.setMinWidth(960);
        primaryStage.setMinHeight(680);

        primaryStage.setOnCloseRequest(e -> {
            if (animationTimer != null) animationTimer.stop();
            if (backendClient != null) backendClient.disconnect();
        });

        primaryStage.show();

        // Initialize default route preview (e.g. J1 to J10)
        onRouteSelectionChanged();

        // Start the local AnimationTimer for rendering (always runs; vehicles come from backend or local)
        startRenderLoop();

        // Export screenshot for preview
        exportMapImage();

        // Try to connect to the backend (async, non-blocking)
        connectToBackend();
    }

    // ─── Backend connection ─────────────────────────────────────────────────────

    private void connectToBackend() {
        String url = BackendClient.DEFAULT_BACKEND_URL;
        setConnectionStatus("Connecting to backend…", "#f59e0b");
        backendClient = new BackendClient(url);

        backendClient.setOnStatusChange(status -> Platform.runLater(() -> {
            switch (status) {
                case CONNECTED -> setConnectionStatus("● Live Backend Connected", "#10b981");
                case CONNECTING -> setConnectionStatus("◌ Connecting…", "#f59e0b");
                case DISCONNECTED -> {
                    setConnectionStatus("○ Backend Disconnected (local mode)", "#ef4444");
                    isConnectedToBackend = false;
                    ghostVehicles = new ArrayList<>();
                }
                case ERROR -> {
                    setConnectionStatus("✗ Backend Error (local mode)", "#ef4444");
                    isConnectedToBackend = false;
                }
            }
        }));

        backendClient.setOnLiveUpdate(snap -> {
            // Apply signals to local CityMap (for rendering)
            backendClient.applySignals(cityMap, snap.signals());
            // Apply road conditions
            backendClient.applyRoadConditions(cityMap, snap.roads());
            // Convert remote vehicles to ghost vehicles
            List<GhostVehicle> newGhosts = backendClient.toGhostVehicles(cityMap, snap.vehicles());
            ghostVehicles = newGhosts;
            // Update clock label from backend simulation time
            Platform.runLater(() -> {
                if (clockLabel != null) {
                    double t = snap.simulationTime();
                    int mins = (int) (t / 60);
                    double secs = t % 60;
                    clockLabel.setText(String.format("Clock: %02d:%04.1fs [Backend]", mins, secs));
                }
                // Throttle UI list update
                updateGhostVehicleListUI();
            });
        });

        backendClient.connect().thenAccept(ok -> {
            if (ok) {
                isConnectedToBackend = true;
                Platform.runLater(() -> setConnectionStatus("● Live Backend Connected", "#10b981"));
                System.out.println("[Desktop] Connected to backend: " + url);
                // Pause local simulation engine (signals/vehicles handled by backend now)
                isPaused = true;
            } else {
                System.out.println("[Desktop] Backend unreachable → running in local mode");
                Platform.runLater(() -> setConnectionStatus("○ Local Simulation (Backend Offline)", "#64748b"));
                // Local simulation remains active
                isPaused = false;
            }
        });
    }

    private void setConnectionStatus(String text, String colorHex) {
        if (connectionStatusLabel != null) {
            connectionStatusLabel.setText(text);
            connectionStatusLabel.setTextFill(Color.web(colorHex));
        }
    }

    // ─── Render loop ────────────────────────────────────────────────────────────

    private void startRenderLoop() {
        final long[] lastNano = { System.nanoTime() };

        animationTimer = new javafx.animation.AnimationTimer() {
            @Override
            public void handle(long now) {
                long elapsedNano = now - lastNano[0];
                lastNano[0] = now;

                if (!isPaused && !isConnectedToBackend) {
                    // Local simulation mode: advance physics locally
                    double deltaSec = (elapsedNano / 1_000_000_000.0) * timeSpeed;
                    if (deltaSec > 0.2) deltaSec = 0.2;

                    signalController.step(deltaSec);
                    vehicleManager.step(deltaSec, signalController);

                    updateClockDisplay();

                    // Throttle UI list updates (5 times per second)
                    if (now - lastUiUpdateNano > 200_000_000L) {
                        lastUiUpdateNano = now;
                        updateVehicleListUI();
                    }
                }

                // Always redraw (backend mode: ghosts are updated via WS callback)
                redraw();
            }
        };
        animationTimer.start();
    }

    private void updateClockDisplay() {
        if (clockLabel != null && !isConnectedToBackend) {
            double t = signalController.getSimulationTime();
            int mins = (int) (t / 60);
            double secs = t % 60;
            clockLabel.setText(String.format("Clock: %02d:%04.1fs", mins, secs));
        }
    }

    private void exportMapImage() {
        Platform.runLater(() -> {
            try {
                javafx.scene.image.WritableImage image = canvas.snapshot(null, null);
                java.io.File file = new java.io.File("map_preview.png");
                javafx.embed.swing.SwingFXUtils.fromFXImage(image, null);
                javax.imageio.ImageIO.write(javafx.embed.swing.SwingFXUtils.fromFXImage(image, null), "png", file);
                System.out.println("MAP_EXPORTED_SUCCESSFULLY: " + file.getAbsolutePath());
            } catch (Exception ex) {
                System.err.println("Failed to export image: " + ex.getMessage());
            }
        });
    }

    // ─── Redraw ─────────────────────────────────────────────────────────────────

    private void redraw() {
        if (isConnectedToBackend) {
            // Connected mode: render ghost vehicles from backend
            renderer.renderWithGhosts(canvas.getGraphicsContext2D(), cityMap,
                    ghostVehicles, selectedGhostId, previewRoute,
                    canvas.getWidth(), canvas.getHeight());
        } else {
            // Local mode: render local Vehicle objects
            renderer.render(canvas.getGraphicsContext2D(), cityMap,
                    vehicleManager.getVehicles(), selectedVehicle, previewRoute,
                    canvas.getWidth(), canvas.getHeight());
        }
    }

    // ─── Header ─────────────────────────────────────────────────────────────────

    private VBox createHeader() {
        VBox header = new VBox(4);
        header.setPadding(new Insets(14, 20, 14, 20));
        header.setStyle("-fx-background-color: #111827; -fx-border-color: #1f2937; -fx-border-width: 0 0 1 0;");

        Label title = new Label("INTELLIGENT TRAFFIC MANAGEMENT SYSTEM");
        title.setFont(Font.font("Segoe UI", FontWeight.BOLD, 18));
        title.setTextFill(Color.web("#38bdf8"));

        Label subtitle = new Label("Fixed-Time Signals • Dijkstra Shortest Path Routing • Autonomous Vehicle Kinematics • Anti-Collision Car-Following");
        subtitle.setFont(Font.font("Segoe UI", 12));
        subtitle.setTextFill(Color.web("#94a3b8"));

        connectionStatusLabel = new Label("◌ Initialising…");
        connectionStatusLabel.setFont(Font.font("Segoe UI", FontWeight.BOLD, 11));
        connectionStatusLabel.setTextFill(Color.web("#94a3b8"));

        header.getChildren().addAll(title, subtitle, connectionStatusLabel);
        return header;
    }

    // ─── Sidebar ────────────────────────────────────────────────────────────────

    private VBox createSidebar() {
        VBox sidebar = new VBox(14);
        sidebar.setPadding(new Insets(16));
        sidebar.setPrefWidth(340);
        sidebar.setStyle("-fx-background-color: #111827;");

        VBox simBox = createSimulationControlsBox();
        VBox addVehicleBox = createAddVehicleBox();
        VBox activeVehiclesBox = createActiveVehiclesBox();
        VBox specsBox = createSpecsAndLegendBox();

        sidebar.getChildren().addAll(simBox, createSeparator(), addVehicleBox, createSeparator(), activeVehiclesBox);
        return sidebar;
    }

    private VBox createSimulationControlsBox() {
        VBox box = new VBox(8);

        Label simTitle = new Label("SIMULATION CLOCK & CONTROLS");
        simTitle.setFont(Font.font("Segoe UI", FontWeight.BOLD, 13));
        simTitle.setTextFill(Color.web("#e2e8f0"));

        clockLabel = new Label("Clock: 00:00.0s");
        clockLabel.setFont(Font.font("Segoe UI", FontWeight.BOLD, 15));
        clockLabel.setTextFill(Color.web("#38bdf8"));

        HBox buttonBar = new HBox(8);
        Button pauseBtn = new Button("Pause");
        pauseBtn.setStyle("-fx-background-color: #334155; -fx-text-fill: white; -fx-cursor: hand; -fx-font-weight: bold;");
        pauseBtn.setOnAction(e -> {
            if (isConnectedToBackend) {
                // Toggle pause state on backend
                boolean newPaused = !isPaused;
                isPaused = newPaused;
                pauseBtn.setText(newPaused ? "Resume" : "Pause");
                backendClient.sendControl(newPaused ? "pause" : "resume");
            } else {
                isPaused = !isPaused;
                pauseBtn.setText(isPaused ? "Resume" : "Pause");
            }
        });

        Button speedBtn = new Button("Speed: 1x");
        speedBtn.setStyle("-fx-background-color: #334155; -fx-text-fill: white; -fx-cursor: hand;");
        speedBtn.setOnAction(e -> {
            if (timeSpeed == 1.0) {
                timeSpeed = 2.0;
                speedBtn.setText("Speed: 2x");
            } else if (timeSpeed == 2.0) {
                timeSpeed = 4.0;
                speedBtn.setText("Speed: 4x");
            } else {
                timeSpeed = 1.0;
                speedBtn.setText("Speed: 1x");
            }
            if (isConnectedToBackend) {
                backendClient.sendControl("speed", timeSpeed);
            }
        });

        Button resetBtn = new Button("Reset");
        resetBtn.setStyle("-fx-background-color: #ef4444; -fx-text-fill: white; -fx-cursor: hand; -fx-font-weight: bold;");
        resetBtn.setOnAction(e -> {
            if (isConnectedToBackend) {
                backendClient.sendControl("reset");
                ghostVehicles = new ArrayList<>();
                selectedGhostId = null;
                updateGhostVehicleListUI();
            } else {
                signalController.reset();
                vehicleManager.clearVehicles();
                selectedVehicle = null;
                updateClockDisplay();
                updateVehicleListUI();
            }
            redraw();
        });

        buttonBar.getChildren().addAll(pauseBtn, speedBtn, resetBtn);
        box.getChildren().addAll(simTitle, clockLabel, buttonBar);
        return box;
    }

    private VBox createAddVehicleBox() {
        VBox box = new VBox(8);

        Label title = new Label("ADD VEHICLE (DIJKSTRA ROUTING)");
        title.setFont(Font.font("Segoe UI", FontWeight.BOLD, 13));
        title.setTextFill(Color.web("#e2e8f0"));

        Label typeLbl = new Label("Vehicle Type:");
        typeLbl.setFont(Font.font("Segoe UI", 11));
        typeLbl.setTextFill(Color.web("#94a3b8"));

        vehicleTypeCombo = new ComboBox<>();
        vehicleTypeCombo.getItems().addAll(VehicleType.values());
        vehicleTypeCombo.setValue(VehicleType.CAR);
        vehicleTypeCombo.setMaxWidth(Double.MAX_VALUE);
        vehicleTypeCombo.setStyle("-fx-background-color: #1e293b; -fx-text-fill: white;");

        Label srcLbl = new Label("Source Intersection:");
        srcLbl.setFont(Font.font("Segoe UI", 11));
        srcLbl.setTextFill(Color.web("#94a3b8"));

        sourceCombo = new ComboBox<>();
        populateJunctionCombo(sourceCombo);
        sourceCombo.setValue(formatJunctionItem("J1"));
        sourceCombo.setMaxWidth(Double.MAX_VALUE);
        sourceCombo.setStyle("-fx-background-color: #1e293b; -fx-text-fill: white;");

        Label destLbl = new Label("Destination Intersection:");
        destLbl.setFont(Font.font("Segoe UI", 11));
        destLbl.setTextFill(Color.web("#94a3b8"));

        destinationCombo = new ComboBox<>();
        populateJunctionCombo(destinationCombo);
        destinationCombo.setValue(formatJunctionItem("J10"));
        destinationCombo.setMaxWidth(Double.MAX_VALUE);
        destinationCombo.setStyle("-fx-background-color: #1e293b; -fx-text-fill: white;");

        sourceCombo.valueProperty().addListener((obs, oldVal, newVal) -> onRouteSelectionChanged());
        destinationCombo.valueProperty().addListener((obs, oldVal, newVal) -> onRouteSelectionChanged());

        VBox previewCard = new VBox(4);
        previewCard.setPadding(new Insets(8));
        previewCard.setStyle("-fx-background-color: #0f172a; -fx-border-color: #1e293b; -fx-border-radius: 4; -fx-background-radius: 4;");

        routePreviewLabel = new Label("Route: Calculating...");
        routePreviewLabel.setWrapText(true);
        routePreviewLabel.setFont(Font.font("Segoe UI", FontWeight.BOLD, 11));
        routePreviewLabel.setTextFill(Color.web("#38bdf8"));

        routeDistanceLabel = new Label("Distance: --");
        routeDistanceLabel.setFont(Font.font("Segoe UI", 11));
        routeDistanceLabel.setTextFill(Color.web("#cbd5e1"));

        routeStatusLabel = new Label("Ready");
        routeStatusLabel.setFont(Font.font("Segoe UI", 10.5));
        routeStatusLabel.setTextFill(Color.web("#10b981"));

        previewCard.getChildren().addAll(routePreviewLabel, routeDistanceLabel, routeStatusLabel);

        startTripBtn = new Button("🚀 Start Trip");
        startTripBtn.setMaxWidth(Double.MAX_VALUE);
        startTripBtn.setStyle("-fx-background-color: #0ea5e9; -fx-text-fill: white; -fx-font-weight: bold; -fx-cursor: hand; -fx-padding: 8;");
        startTripBtn.setOnAction(e -> onStartTripClicked());

        box.getChildren().addAll(title, typeLbl, vehicleTypeCombo, srcLbl, sourceCombo, destLbl, destinationCombo, previewCard, startTripBtn);
        return box;
    }

    private VBox createActiveVehiclesBox() {
        VBox box = new VBox(8);

        HBox header = new HBox();
        header.setAlignment(Pos.CENTER_LEFT);
        Label title = new Label("ACTIVE FLEET & TRIPS");
        title.setFont(Font.font("Segoe UI", FontWeight.BOLD, 13));
        title.setTextFill(Color.web("#e2e8f0"));
        HBox.setHgrow(title, Priority.ALWAYS);

        Button clearBtn = new Button("Clear All");
        clearBtn.setStyle("-fx-background-color: #334155; -fx-text-fill: #cbd5e1; -fx-font-size: 10px; -fx-cursor: hand;");
        clearBtn.setOnAction(e -> {
            if (isConnectedToBackend) {
                backendClient.sendControl("reset");
                ghostVehicles = new ArrayList<>();
                selectedGhostId = null;
                updateGhostVehicleListUI();
            } else {
                vehicleManager.clearVehicles();
                selectedVehicle = null;
                updateVehicleListUI();
            }
            redraw();
        });

        header.getChildren().addAll(title, clearBtn);

        vehicleListContainer = new VBox(6);
        updateVehicleListUI();

        box.getChildren().addAll(header, vehicleListContainer);
        return box;
    }

    // ─── Vehicle list UI ────────────────────────────────────────────────────────

    private void updateVehicleListUI() {
        if (vehicleListContainer == null) return;
        List<Vehicle> list = vehicleManager.getVehicles();

        if (list.isEmpty()) {
            vehicleListContainer.getChildren().clear();
            Label emptyLbl = new Label("No vehicles active.\nSelect a route above and click Start Trip.");
            emptyLbl.setWrapText(true);
            emptyLbl.setFont(Font.font("Segoe UI", 11));
            emptyLbl.setTextFill(Color.web("#64748b"));
            vehicleListContainer.getChildren().add(emptyLbl);
            return;
        }

        vehicleListContainer.getChildren().clear();
        for (Vehicle v : list) {
            VBox card = createLocalVehicleCard(v);
            vehicleListContainer.getChildren().add(card);
        }
    }

    /** Update the vehicle list UI from ghost vehicles (backend connected mode). */
    private void updateGhostVehicleListUI() {
        if (vehicleListContainer == null) return;
        List<GhostVehicle> list = ghostVehicles;

        vehicleListContainer.getChildren().clear();
        if (list.isEmpty()) {
            Label emptyLbl = new Label("No vehicles active.\nSpawn one below — it will appear here and in the Flutter app.");
            emptyLbl.setWrapText(true);
            emptyLbl.setFont(Font.font("Segoe UI", 11));
            emptyLbl.setTextFill(Color.web("#64748b"));
            vehicleListContainer.getChildren().add(emptyLbl);
            return;
        }

        for (GhostVehicle gv : list) {
            VBox card = createGhostVehicleCard(gv);
            vehicleListContainer.getChildren().add(card);
        }
    }

    private VBox createLocalVehicleCard(Vehicle v) {
        VBox card = new VBox(4);
        card.setPadding(new Insets(6, 8, 6, 8));

        boolean isSelected = (selectedVehicle != null && selectedVehicle.equals(v));
        String borderCol = isSelected ? "#38bdf8" : "#334155";
        card.setStyle("-fx-background-color: #1e293b; -fx-border-color: " + borderCol + "; -fx-border-radius: 4; -fx-background-radius: 4; -fx-cursor: hand;");

        HBox topRow = new HBox(6);
        topRow.setAlignment(Pos.CENTER_LEFT);

        Label idLbl = new Label(v.getId() + " (" + v.getType().getDisplayName() + ")");
        idLbl.setFont(Font.font("Segoe UI", FontWeight.BOLD, 11));
        idLbl.setTextFill(Color.web(v.getType().getColorHex()));
        HBox.setHgrow(idLbl, Priority.ALWAYS);

        String statusColor = "#10b981";
        if (v.getStatus() == VehicleStatus.STOPPED_AT_SIGNAL) {
            statusColor = "#ef4444";
        } else if (v.getStatus() == VehicleStatus.WAITING) {
            statusColor = "#f59e0b";
        } else if (v.getStatus() == VehicleStatus.COMPLETED) {
            statusColor = "#64748b";
        }

        Label statusLbl = new Label(v.getStatus().getLabel());
        statusLbl.setFont(Font.font("Segoe UI", FontWeight.BOLD, 9.5));
        statusLbl.setTextFill(Color.web(statusColor));

        topRow.getChildren().addAll(idLbl, statusLbl);

        Label pathLbl = new Label(v.getSource().getId() + " → " + v.getDestination().getId() + " • " + String.format("%.0f%%", v.getProgressPercentage()));
        pathLbl.setFont(Font.font("Segoe UI", 10.5));
        pathLbl.setTextFill(Color.web("#94a3b8"));

        ProgressBar pBar = new ProgressBar(v.getProgressPercentage() / 100.0);
        pBar.setMaxWidth(Double.MAX_VALUE);
        pBar.setPrefHeight(4);
        pBar.setStyle("-fx-accent: " + v.getType().getColorHex() + ";");

        card.getChildren().addAll(topRow, pathLbl, pBar);

        card.setOnMouseClicked(e -> {
            selectedVehicle = v;
            previewRoute = null;
            updateVehicleListUI();
            redraw();
        });

        return card;
    }

    private VBox createGhostVehicleCard(GhostVehicle gv) {
        VBox card = new VBox(4);
        card.setPadding(new Insets(6, 8, 6, 8));

        boolean isSelected = gv.getId().equals(selectedGhostId);
        String borderCol = isSelected ? "#38bdf8" : "#334155";
        card.setStyle("-fx-background-color: #1e293b; -fx-border-color: " + borderCol + "; -fx-border-radius: 4; -fx-background-radius: 4; -fx-cursor: hand;");

        HBox topRow = new HBox(6);
        topRow.setAlignment(Pos.CENTER_LEFT);

        Label idLbl = new Label(gv.getId() + " (" + gv.getType().getDisplayName() + ")");
        idLbl.setFont(Font.font("Segoe UI", FontWeight.BOLD, 11));
        idLbl.setTextFill(Color.web(gv.getType().getColorHex()));
        HBox.setHgrow(idLbl, Priority.ALWAYS);

        String statusColor;
        String statusText;
        switch (gv.getStatus()) {
            case STOPPED_AT_SIGNAL -> { statusColor = "#ef4444"; statusText = "At Signal"; }
            case COMPLETED         -> { statusColor = "#64748b"; statusText = "Arrived"; }
            case WAITING           -> { statusColor = "#f59e0b"; statusText = "Waiting"; }
            default                -> { statusColor = "#10b981"; statusText = "Moving"; }
        }

        Label statusLbl = new Label(statusText);
        statusLbl.setFont(Font.font("Segoe UI", FontWeight.BOLD, 9.5));
        statusLbl.setTextFill(Color.web(statusColor));

        topRow.getChildren().addAll(idLbl, statusLbl);

        String src  = gv.getSource()      != null ? gv.getSource().getId()      : gv.getRoutePath().isEmpty() ? "?" : gv.getRoutePath().get(0);
        String dest = gv.getDestination() != null ? gv.getDestination().getId() : gv.getRoutePath().isEmpty() ? "?" : gv.getRoutePath().get(gv.getRoutePath().size() - 1);
        Label pathLbl = new Label(src + " → " + dest + " • " + String.format("%.0f%%", gv.getProgressPercent()));
        pathLbl.setFont(Font.font("Segoe UI", 10.5));
        pathLbl.setTextFill(Color.web("#94a3b8"));

        ProgressBar pBar = new ProgressBar(gv.getProgressPercent() / 100.0);
        pBar.setMaxWidth(Double.MAX_VALUE);
        pBar.setPrefHeight(4);
        pBar.setStyle("-fx-accent: " + gv.getType().getColorHex() + ";");

        card.getChildren().addAll(topRow, pathLbl, pBar);

        card.setOnMouseClicked(e -> {
            selectedGhostId = gv.getId();
            updateGhostVehicleListUI();
            redraw();
        });

        return card;
    }

    // ─── Route selection & trip spawning ────────────────────────────────────────

    private void onRouteSelectionChanged() {
        String srcItem  = (sourceCombo      != null) ? sourceCombo.getValue()      : "J1";
        String destItem = (destinationCombo != null) ? destinationCombo.getValue() : "J10";
        if (srcItem == null || destItem == null) return;

        String srcId  = extractJunctionId(srcItem);
        String destId = extractJunctionId(destItem);

        if (srcId.equals(destId)) {
            previewRoute = null;
            if (routePreviewLabel != null) {
                routePreviewLabel.setText("Route: None (Origin equals Destination)");
                routeDistanceLabel.setText("Distance: 0.0m");
                routeStatusLabel.setText("⚠ Source and destination cannot be identical.");
                routeStatusLabel.setTextFill(Color.web("#f43f5e"));
                startTripBtn.setDisable(true);
            }
            redraw();
            return;
        }

        Route route = routeFinder.findShortestRoute(cityMap, srcId, destId);
        if (route != null && route.isValid() && !route.isEmpty()) {
            previewRoute = route;
            if (routePreviewLabel != null) {
                routePreviewLabel.setText("Route: " + route.getRouteDescription());
                routeDistanceLabel.setText(String.format("Distance: %.1fm • Hops: %d", route.getTotalDistance(), route.getHopCount()));
                routeStatusLabel.setText("✓ Shortest path calculated via Dijkstra");
                routeStatusLabel.setTextFill(Color.web("#10b981"));
                startTripBtn.setDisable(false);
            }
        } else {
            previewRoute = null;
            if (routePreviewLabel != null) {
                routePreviewLabel.setText("Route: Unreachable");
                routeDistanceLabel.setText("Distance: N/A");
                routeStatusLabel.setText("❌ No connected route found.");
                routeStatusLabel.setTextFill(Color.web("#f43f5e"));
                startTripBtn.setDisable(true);
            }
        }
        redraw();
    }

    private void onStartTripClicked() {
        String srcId  = extractJunctionId(sourceCombo.getValue());
        String destId = extractJunctionId(destinationCombo.getValue());
        VehicleType type = vehicleTypeCombo.getValue();
        if (type == null) type = VehicleType.CAR;

        if (isConnectedToBackend) {
            // POST to backend — vehicle will appear in both Flutter and this desktop
            final VehicleType finalType = type;
            final String fSrc = srcId, fDest = destId;
            startTripBtn.setDisable(true);
            startTripBtn.setText("Spawning…");
            new Thread(() -> {
                Map<String, Object> result = backendClient.spawnVehicle(finalType.name(), fSrc, fDest);
                Platform.runLater(() -> {
                    startTripBtn.setDisable(false);
                    startTripBtn.setText("🚀 Start Trip");
                    if (result != null) {
                        System.out.println("[Desktop] Vehicle spawned on backend: " + result.get("id"));
                    } else {
                        routeStatusLabel.setText("❌ Spawn failed — check backend.");
                        routeStatusLabel.setTextFill(Color.web("#f43f5e"));
                    }
                });
            }, "spawn-thread").start();
        } else {
            // Local simulation: spawn locally
            if (previewRoute == null || !previewRoute.isValid() || previewRoute.isEmpty()) return;
            Intersection src  = previewRoute.getSource();
            Intersection dest = previewRoute.getDestination();
            Vehicle vehicle = vehicleManager.spawnVehicle(type, src, dest, previewRoute);
            selectedVehicle = vehicle;
            updateVehicleListUI();
            redraw();
        }
    }

    // ─── Helpers ────────────────────────────────────────────────────────────────

    private void populateJunctionCombo(ComboBox<String> combo) {
        for (Intersection node : cityMap.getIntersections().values()) {
            combo.getItems().add(formatJunctionItem(node.getId()));
        }
    }

    private String formatJunctionItem(String jId) {
        Intersection node = cityMap.getIntersection(jId);
        if (node == null) return jId;
        if (node.getLandmark() != null) {
            return node.getId() + " - " + node.getLandmark().getName();
        }
        return node.getId() + " - " + node.getName();
    }

    private String extractJunctionId(String item) {
        if (item == null) return "";
        int dashIdx = item.indexOf(" - ");
        if (dashIdx > 0) {
            return item.substring(0, dashIdx).trim();
        }
        return item.trim();
    }

    private VBox createSpecsAndLegendBox() {
        VBox box = new VBox(8);

        Label statsTitle = new Label("NETWORK SPECIFICATIONS");
        statsTitle.setFont(Font.font("Segoe UI", FontWeight.BOLD, 13));
        statsTitle.setTextFill(Color.web("#e2e8f0"));

        VBox statsBox = new VBox(5);
        statsBox.getChildren().addAll(
            createStatRow("Intersections:", "10 (J1 – J10)"),
            createStatRow("Total Roads:", String.valueOf(cityMap.getRoads().size()) + " Roads (30 Lanes)"),
            createStatRow("Signalized:", "7 Multi-Way Hubs"),
            createStatRow("Uncontrolled:", "3 Pass-Through Hubs (J1,J3,J10)"),
            createStatRow("Max Degree:", "≤ 4 Roads per Junction")
        );

        Separator sep = createSeparator();

        Label lmTitle = new Label("KEY STRATEGIC LANDMARKS");
        lmTitle.setFont(Font.font("Segoe UI", FontWeight.BOLD, 13));
        lmTitle.setTextFill(Color.web("#e2e8f0"));

        VBox lmBox = new VBox(5);
        for (Landmark lm : cityMap.getLandmarks().values()) {
            lmBox.getChildren().add(createLandmarkRow(lm));
        }

        box.getChildren().addAll(statsTitle, statsBox, sep, lmTitle, lmBox);
        return box;
    }

    private Separator createSeparator() {
        Separator sep = new Separator();
        sep.setStyle("-fx-background-color: #1f2937;");
        return sep;
    }

    private HBox createStatRow(String label, String value) {
        HBox row = new HBox();
        row.setAlignment(Pos.CENTER_LEFT);
        Label lbl = new Label(label);
        lbl.setFont(Font.font("Segoe UI", 11));
        lbl.setTextFill(Color.web("#94a3b8"));

        Label val = new Label(value);
        val.setFont(Font.font("Segoe UI", FontWeight.SEMI_BOLD, 11));
        val.setTextFill(Color.web("#38bdf8"));

        HBox.setHgrow(lbl, Priority.ALWAYS);
        lbl.setMaxWidth(Double.MAX_VALUE);
        row.getChildren().addAll(lbl, val);
        return row;
    }

    private HBox createLandmarkRow(Landmark lm) {
        HBox row = new HBox(8);
        row.setAlignment(Pos.CENTER_LEFT);

        String hex;
        switch (lm.getType()) {
            case HOSPITAL:        hex = "#ef4444"; break;
            case RAILWAY_STATION: hex = "#06b6d4"; break;
            case CITY_CENTER:     hex = "#8b5cf6"; break;
            case SHOPPING_MALL:   hex = "#f59e0b"; break;
            case UNIVERSITY:      hex = "#10b981"; break;
            default:              hex = "#64748b"; break;
        }

        javafx.scene.shape.Circle dot = new javafx.scene.shape.Circle(5, Color.web(hex));
        Label lbl = new Label(lm.getName() + " (" + lm.getIntersectionId() + ")");
        lbl.setFont(Font.font("Segoe UI", 11));
        lbl.setTextFill(Color.web("#cbd5e1"));

        row.getChildren().addAll(dot, lbl);
        return row;
    }

    public static void main(String[] args) {
        launch(args);
    }
}
