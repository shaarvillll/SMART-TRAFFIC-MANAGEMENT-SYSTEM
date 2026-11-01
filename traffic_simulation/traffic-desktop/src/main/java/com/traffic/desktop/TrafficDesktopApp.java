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

import java.util.List;

/**
 * Intelligent Traffic Desktop Simulator:
 * Irregular City Road Network Prototype featuring:
 * - Deterministic Fixed-Time Traffic Signals (curbside 3-aspect heads).
 * - Dijkstra Shortest-Path Dynamic Routing.
 * - Multi-Vehicle Movement & Anti-Collision Car Following.
 * - Interactive Trip Dispatcher & Live Vehicle Fleet HUD.
 */
public class TrafficDesktopApp extends Application {

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

    // Vehicle trip selection state
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
        primaryStage.setTitle("Intelligent Traffic Simulator - Signals, Dijkstra Routing & Vehicles");
        primaryStage.setScene(scene);
        primaryStage.setResizable(true);
        primaryStage.setMinWidth(960);
        primaryStage.setMinHeight(680);

        primaryStage.setOnCloseRequest(e -> {
            if (animationTimer != null) animationTimer.stop();
        });

        primaryStage.show();

        // Initialize default route preview (e.g. J1 to J10)
        onRouteSelectionChanged();

        // Start deterministic simulation clock loop
        startSimulationClock();

        // Export screenshot so it can be previewed directly
        exportMapImage();
    }

    private void startSimulationClock() {
        final long[] lastNano = { System.nanoTime() };

        animationTimer = new javafx.animation.AnimationTimer() {
            @Override
            public void handle(long now) {
                long elapsedNano = now - lastNano[0];
                lastNano[0] = now;

                if (!isPaused) {
                    double deltaSec = (elapsedNano / 1_000_000_000.0) * timeSpeed;
                    if (deltaSec > 0.2) deltaSec = 0.2;

                    // Advance traffic signals and vehicle positions along the shared clock
                    signalController.step(deltaSec);
                    vehicleManager.step(deltaSec, signalController);

                    redraw();
                    updateClockDisplay();

                    // Throttle UI list updates (5 times per second)
                    if (now - lastUiUpdateNano > 200_000_000L) {
                        lastUiUpdateNano = now;
                        updateVehicleListUI();
                    }
                }
            }
        };
        animationTimer.start();
    }

    private void updateClockDisplay() {
        if (clockLabel != null) {
            double t = signalController.getSimulationTime();
            int mins = (int) (t / 60);
            double secs = t % 60;
            clockLabel.setText(String.format("Clock: %02d:%04.1fs", mins, secs));
        }
    }

    private void exportMapImage() {
        javafx.application.Platform.runLater(() -> {
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

        header.getChildren().addAll(title, subtitle);
        return header;
    }

    private VBox createSidebar() {
        VBox sidebar = new VBox(14);
        sidebar.setPadding(new Insets(16));
        sidebar.setPrefWidth(340);
        sidebar.setStyle("-fx-background-color: #111827;");

        // 1. Simulation Controls
        VBox simBox = createSimulationControlsBox();

        // 2. Add Vehicle Trip (Dijkstra Routing)
        VBox addVehicleBox = createAddVehicleBox();

        // 3. Active Vehicles & Trips List
        VBox activeVehiclesBox = createActiveVehiclesBox();

        // 4. Network Specifications & Legend
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
            isPaused = !isPaused;
            pauseBtn.setText(isPaused ? "Resume" : "Pause");
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
        });

        Button resetBtn = new Button("Reset");
        resetBtn.setStyle("-fx-background-color: #ef4444; -fx-text-fill: white; -fx-cursor: hand; -fx-font-weight: bold;");
        resetBtn.setOnAction(e -> {
            signalController.reset();
            vehicleManager.clearVehicles();
            selectedVehicle = null;
            updateClockDisplay();
            updateVehicleListUI();
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

        // Vehicle Type Selector
        Label typeLbl = new Label("Vehicle Type:");
        typeLbl.setFont(Font.font("Segoe UI", 11));
        typeLbl.setTextFill(Color.web("#94a3b8"));

        vehicleTypeCombo = new ComboBox<>();
        vehicleTypeCombo.getItems().addAll(VehicleType.values());
        vehicleTypeCombo.setValue(VehicleType.CAR);
        vehicleTypeCombo.setMaxWidth(Double.MAX_VALUE);
        vehicleTypeCombo.setStyle("-fx-background-color: #1e293b; -fx-text-fill: white;");

        // Source Junction Selector
        Label srcLbl = new Label("Source Intersection:");
        srcLbl.setFont(Font.font("Segoe UI", 11));
        srcLbl.setTextFill(Color.web("#94a3b8"));

        sourceCombo = new ComboBox<>();
        populateJunctionCombo(sourceCombo);
        sourceCombo.setValue(formatJunctionItem("J1"));
        sourceCombo.setMaxWidth(Double.MAX_VALUE);
        sourceCombo.setStyle("-fx-background-color: #1e293b; -fx-text-fill: white;");

        // Destination Junction Selector
        Label destLbl = new Label("Destination Intersection:");
        destLbl.setFont(Font.font("Segoe UI", 11));
        destLbl.setTextFill(Color.web("#94a3b8"));

        destinationCombo = new ComboBox<>();
        populateJunctionCombo(destinationCombo);
        destinationCombo.setValue(formatJunctionItem("J10"));
        destinationCombo.setMaxWidth(Double.MAX_VALUE);
        destinationCombo.setStyle("-fx-background-color: #1e293b; -fx-text-fill: white;");

        // Listeners for dynamic route calculation and preview
        sourceCombo.valueProperty().addListener((obs, oldVal, newVal) -> onRouteSelectionChanged());
        destinationCombo.valueProperty().addListener((obs, oldVal, newVal) -> onRouteSelectionChanged());

        // Route Preview Card
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

        // Start Trip Button
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
            vehicleManager.clearVehicles();
            selectedVehicle = null;
            updateVehicleListUI();
            redraw();
        });

        header.getChildren().addAll(title, clearBtn);

        vehicleListContainer = new VBox(6);
        updateVehicleListUI();

        box.getChildren().addAll(header, vehicleListContainer);
        return box;
    }

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
            VBox card = createVehicleCard(v);
            vehicleListContainer.getChildren().add(card);
        }
    }

    private VBox createVehicleCard(Vehicle v) {
        VBox card = new VBox(4);
        card.setPadding(new Insets(6, 8, 6, 8));

        boolean isSelected = (selectedVehicle != null && selectedVehicle.equals(v));
        String borderCol = isSelected ? "#38bdf8" : "#334155";
        card.setStyle("-fx-background-color: #1e293b; -fx-border-color: " + borderCol + "; -fx-border-radius: 4; -fx-background-radius: 4; -fx-cursor: hand;");

        // Top Row: ID, Type badge, and Status
        HBox topRow = new HBox(6);
        topRow.setAlignment(Pos.CENTER_LEFT);

        Label idLbl = new Label(v.getId() + " (" + v.getType().getDisplayName() + ")");
        idLbl.setFont(Font.font("Segoe UI", FontWeight.BOLD, 11));
        idLbl.setTextFill(Color.web(v.getType().getColorHex()));
        HBox.setHgrow(idLbl, Priority.ALWAYS);

        String statusColor = "#10b981"; // Green for Moving
        if (v.getStatus() == VehicleStatus.STOPPED_AT_SIGNAL) {
            statusColor = "#ef4444"; // Red for Signal Stop
        } else if (v.getStatus() == VehicleStatus.WAITING) {
            statusColor = "#f59e0b"; // Amber for Spacing Wait
        } else if (v.getStatus() == VehicleStatus.COMPLETED) {
            statusColor = "#64748b"; // Slate for Finished
        }

        Label statusLbl = new Label(v.getStatus().getLabel());
        statusLbl.setFont(Font.font("Segoe UI", FontWeight.BOLD, 9.5));
        statusLbl.setTextFill(Color.web(statusColor));

        topRow.getChildren().addAll(idLbl, statusLbl);

        // Path Label
        Label pathLbl = new Label(v.getSource().getId() + " \u2192 " + v.getDestination().getId() + " • " + String.format("%.0f%%", v.getProgressPercentage()));
        pathLbl.setFont(Font.font("Segoe UI", 10.5));
        pathLbl.setTextFill(Color.web("#94a3b8"));

        // Progress Bar
        ProgressBar pBar = new ProgressBar(v.getProgressPercentage() / 100.0);
        pBar.setMaxWidth(Double.MAX_VALUE);
        pBar.setPrefHeight(4);
        pBar.setStyle("-fx-accent: " + v.getType().getColorHex() + ";");

        card.getChildren().addAll(topRow, pathLbl, pBar);

        card.setOnMouseClicked(e -> {
            selectedVehicle = v;
            previewRoute = null; // Prioritize selected vehicle's route highlight
            updateVehicleListUI();
            redraw();
        });

        return card;
    }

    private void onRouteSelectionChanged() {
        String srcItem = (sourceCombo != null) ? sourceCombo.getValue() : "J1";
        String destItem = (destinationCombo != null) ? destinationCombo.getValue() : "J10";
        if (srcItem == null || destItem == null) return;

        String srcId = extractJunctionId(srcItem);
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
        if (previewRoute == null || !previewRoute.isValid() || previewRoute.isEmpty()) {
            return;
        }

        VehicleType type = vehicleTypeCombo.getValue();
        if (type == null) type = VehicleType.CAR;

        Intersection src = previewRoute.getSource();
        Intersection dest = previewRoute.getDestination();

        Vehicle vehicle = vehicleManager.spawnVehicle(type, src, dest, previewRoute);
        selectedVehicle = vehicle;
        updateVehicleListUI();
        redraw();
    }

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

    private void redraw() {
        renderer.render(canvas.getGraphicsContext2D(), cityMap, vehicleManager.getVehicles(), selectedVehicle, previewRoute, canvas.getWidth(), canvas.getHeight());
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
            case HOSPITAL: hex = "#ef4444"; break;
            case RAILWAY_STATION: hex = "#06b6d4"; break;
            case CITY_CENTER: hex = "#8b5cf6"; break;
            case SHOPPING_MALL: hex = "#f59e0b"; break;
            case UNIVERSITY: hex = "#10b981"; break;
            default: hex = "#64748b"; break;
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
