package com.traffic.desktop.renderer;

import com.traffic.core.model.CityMap;
import com.traffic.core.model.Intersection;
import com.traffic.core.model.Landmark;
import com.traffic.core.model.Road;
import com.traffic.core.model.RoadCondition;
import com.traffic.core.model.RoadType;
import com.traffic.core.model.SignalColor;
import com.traffic.core.model.TrafficSignal;
import com.traffic.core.routing.Route;
import com.traffic.core.vehicle.Vehicle;
import com.traffic.core.vehicle.VehicleStatus;
import com.traffic.core.vehicle.VehicleType;
import com.traffic.desktop.GhostVehicle;
import java.util.List;
import javafx.geometry.VPos;
import javafx.scene.canvas.GraphicsContext;
import javafx.scene.paint.Color;
import javafx.scene.shape.StrokeLineCap;
import javafx.scene.shape.StrokeLineJoin;
import javafx.scene.text.Font;
import javafx.scene.text.FontWeight;
import javafx.scene.text.TextAlignment;

/**
 * High-detail top-down 2D JavaFX Canvas renderer for the Irregular City Network.
 * Features:
 * - Asphalt roadways with curbs, directional arrows, and dashed center lines.
 * - Intersection junction boxes adapted for 3-way and 4-way junctions.
 * - Prominent landmark badges with custom colors and labels (Hospital, Station, Mall, University, City Center).
 * - Distinguishable styling for diagonal connector roads.
 * - Real-time traffic condition color cues (Normal, Congested, Closed).
 */
public class MapCanvasRenderer {

    private static final double ROAD_WIDTH = 42.0;
    private static final double LANE_WIDTH = 21.0;
    private static final double JUNCTION_SIZE = 54.0;

    // Premium Color Palette
    private static final Color COLOR_BACKGROUND = Color.web("#090d16");
    private static final Color COLOR_GRID_LINE = Color.web("#172033", 0.4);
    private static final Color COLOR_ROAD_ASPHALT = Color.web("#2c384a");
    private static final Color COLOR_ROAD_BORDER = Color.web("#5a6b82");
    private static final Color COLOR_ROAD_DIAGONAL = Color.web("#36475d");
    private static final Color COLOR_LANE_DIVIDER = Color.web("#f59e0b");
    private static final Color COLOR_STOP_LINE = Color.web("#f8fafc");
    private static final Color COLOR_ARROW = Color.web("#cbd5e1", 0.75);

    private static final Color COLOR_JUNCTION_BOX = Color.web("#1e293b");
    private static final Color COLOR_JUNCTION_BORDER = Color.web("#78889e");

    public void render(GraphicsContext gc, CityMap cityMap, double width, double height) {
        render(gc, cityMap, null, null, null, width, height);
    }

    public void render(GraphicsContext gc, CityMap cityMap, List<Vehicle> vehicles, Vehicle selectedVehicle, Route previewRoute, double width, double height) {
        renderCore(gc, cityMap, vehicles, null, selectedVehicle, null, previewRoute, width, height);
    }

    /**
     * Render with GhostVehicles from the backend (connected mode).
     * selectedGhostId highlights that ghost vehicle.
     */
    public void renderWithGhosts(GraphicsContext gc, CityMap cityMap, List<GhostVehicle> ghosts,
                                  String selectedGhostId, Route previewRoute, double width, double height) {
        renderCore(gc, cityMap, null, ghosts, null, selectedGhostId, previewRoute, width, height);
    }

    private void renderCore(GraphicsContext gc, CityMap cityMap,
                            List<Vehicle> vehicles, List<GhostVehicle> ghosts,
                            Vehicle selectedVehicle, String selectedGhostId,
                            Route previewRoute, double width, double height) {
        // 1. Dark City Background
        gc.setFill(COLOR_BACKGROUND);
        gc.fillRect(0, 0, width, height);

        if (width <= 0 || height <= 0) return;

        // Base network coordinate design bounds
        double baseWidth = 1040.0;
        double baseHeight = 840.0;

        // Calculate aspect-ratio preserving scale factor and centering offsets
        double scale = Math.min(width / baseWidth, height / baseHeight);
        double offsetX = (width - baseWidth * scale) / 2.0;
        double offsetY = (height - baseHeight * scale) / 2.0;

        // 2. Subtle background grid
        drawSubtleGrid(gc, width, height);

        // 3. Save transform and apply dynamic scale & center offset
        gc.save();
        gc.translate(offsetX, offsetY);
        gc.scale(scale, scale);

        // Render Roads
        for (Road road : cityMap.getRoads()) {
            drawRoad(gc, road);
        }

        // Render Route Preview / Selected Vehicle Highlight
        Route activeRoute = previewRoute;
        if (activeRoute == null && selectedVehicle != null) {
            activeRoute = selectedVehicle.getRoute();
        }
        if (activeRoute != null && activeRoute.isValid()) {
            drawRouteHighlight(gc, activeRoute);
        }

        // Render Intersections
        for (Intersection intersection : cityMap.getIntersections().values()) {
            drawIntersection(gc, intersection);
        }

        // Render local Vehicles (offline/demo mode)
        if (vehicles != null) {
            for (Vehicle vehicle : vehicles) {
                if (vehicle.getStatus() != VehicleStatus.COMPLETED) {
                    boolean isSelected = (selectedVehicle != null && selectedVehicle.equals(vehicle));
                    drawVehicle(gc, vehicle, isSelected);
                }
            }
        }

        // Render GhostVehicles from backend (connected mode)
        if (ghosts != null) {
            for (GhostVehicle ghost : ghosts) {
                if (ghost.getStatus() != VehicleStatus.COMPLETED) {
                    boolean isSelected = (selectedGhostId != null && selectedGhostId.equals(ghost.getId()));
                    drawGhostVehicle(gc, ghost, isSelected);
                }
            }
        }

        // Render Landmarks
        for (Landmark landmark : cityMap.getLandmarks().values()) {
            Intersection node = cityMap.getIntersection(landmark.getIntersectionId());
            if (node != null) {
                drawLandmarkBadge(gc, landmark, node.getX(), node.getY());
            }
        }

        gc.restore();
    }

    private void drawRouteHighlight(GraphicsContext gc, Route route) {
        if (route == null || route.isEmpty() || route.getPath().size() < 2) return;

        gc.save();
        // Glowing cyan underlay ribbon
        gc.setStroke(Color.web("#0ea5e9", 0.35));
        gc.setLineWidth(16.0);
        gc.setLineCap(StrokeLineCap.ROUND);
        gc.setLineJoin(StrokeLineJoin.ROUND);

        for (int i = 0; i < route.getPath().size() - 1; i++) {
            Intersection u = route.getPath().get(i);
            Intersection v = route.getPath().get(i + 1);
            gc.strokeLine(u.getX(), u.getY(), v.getX(), v.getY());
        }

        // Crisp dashed neon core trajectory
        gc.setStroke(Color.web("#38bdf8", 0.95));
        gc.setLineWidth(3.5);
        gc.setLineDashes(10.0, 6.0);

        for (int i = 0; i < route.getPath().size() - 1; i++) {
            Intersection u = route.getPath().get(i);
            Intersection v = route.getPath().get(i + 1);
            gc.strokeLine(u.getX(), u.getY(), v.getX(), v.getY());
        }

        // Origin and Destination markers
        Intersection start = route.getSource();
        Intersection end = route.getDestination();
        if (start != null) {
            gc.setFill(Color.web("#10b981"));
            gc.fillOval(start.getX() - 8.0, start.getY() - 8.0, 16.0, 16.0);
            gc.setStroke(Color.WHITE);
            gc.setLineWidth(2.0);
            gc.strokeOval(start.getX() - 8.0, start.getY() - 8.0, 16.0, 16.0);
        }
        if (end != null) {
            gc.setFill(Color.web("#f43f5e"));
            gc.fillOval(end.getX() - 8.0, end.getY() - 8.0, 16.0, 16.0);
            gc.setStroke(Color.WHITE);
            gc.setLineWidth(2.0);
            gc.strokeOval(end.getX() - 8.0, end.getY() - 8.0, 16.0, 16.0);
        }

        gc.restore();
    }

    private void drawVehicle(GraphicsContext gc, Vehicle vehicle, boolean isSelected) {
        double x = vehicle.getX();
        double y = vehicle.getY();
        double angle = vehicle.getHeadingAngle();
        VehicleType type = vehicle.getType();
        double len = type.getLength();
        double w = type.getWidth();
        Color bodyColor = Color.web(type.getColorHex());

        gc.save();
        gc.translate(x, y);
        gc.rotate(Math.toDegrees(angle));

        // Selection ring
        if (isSelected) {
            gc.setStroke(Color.web("#38bdf8", 0.9));
            gc.setLineWidth(2.5);
            gc.strokeRoundRect(-len / 2.0 - 4.0, -w / 2.0 - 4.0, len + 8.0, w + 8.0, 5, 5);
        }

        // Soft vehicle shadow
        gc.setFill(Color.web("#000000", 0.5));
        gc.fillRoundRect(-len / 2.0 + 1.0, -w / 2.0 + 1.5, len, w, 3.5, 3.5);

        // Vehicle body
        gc.setFill(bodyColor);
        gc.fillRoundRect(-len / 2.0, -w / 2.0, len, w, 3.5, 3.5);

        // Chassis stroke
        gc.setStroke(Color.web("#020617", 0.9));
        gc.setLineWidth(1.0);
        gc.strokeRoundRect(-len / 2.0, -w / 2.0, len, w, 3.5, 3.5);

        // Windshield (dark glass near front third)
        gc.setFill(Color.web("#020617", 0.8));
        double windshieldW = w * 0.72;
        double windshieldL = len * 0.30;
        gc.fillRoundRect(0.0, -windshieldW / 2.0, windshieldL, windshieldW, 2, 2);

        // Headlights (warm white dots at front bumper)
        gc.setFill(Color.web("#fef08a"));
        gc.fillOval(len / 2.0 - 2.5, -w / 2.0 + 1.0, 2.2, 2.2);
        gc.fillOval(len / 2.0 - 2.5, w / 2.0 - 3.2, 2.2, 2.2);

        // Taillights (red dots at rear bumper)
        gc.setFill(Color.web("#ef4444"));
        gc.fillOval(-len / 2.0, -w / 2.0 + 1.0, 2.0, 2.0);
        gc.fillOval(-len / 2.0, w / 2.0 - 3.0, 2.0, 2.0);

        gc.restore();

        // Compact ID label tag
        gc.setFill(Color.web("#0b1329", 0.88));
        gc.fillRoundRect(x - 13.0, y - w / 2.0 - 15.0, 26.0, 11.0, 3, 3);
        gc.setStroke(bodyColor);
        gc.setLineWidth(0.8);
        gc.strokeRoundRect(x - 13.0, y - w / 2.0 - 15.0, 26.0, 11.0, 3, 3);

        gc.setFill(Color.WHITE);
        gc.setFont(Font.font("Segoe UI", FontWeight.BOLD, 8.0));
        gc.setTextAlign(TextAlignment.CENTER);
        gc.setTextBaseline(VPos.CENTER);
        gc.fillText(vehicle.getId(), x, y - w / 2.0 - 9.5);
    }

    /**
     * Draws a GhostVehicle (position received from backend WebSocket).
     * Identical visual style to drawVehicle — same renderer, different data source.
     */
    private void drawGhostVehicle(GraphicsContext gc, GhostVehicle ghost, boolean isSelected) {
        double x = ghost.getX();
        double y = ghost.getY();
        double angle = ghost.getHeadingAngle();
        VehicleType type = ghost.getType();
        double len = type.getLength();
        double w   = type.getWidth();
        Color bodyColor = Color.web(type.getColorHex());

        gc.save();
        gc.translate(x, y);
        gc.rotate(Math.toDegrees(angle));

        if (isSelected) {
            gc.setStroke(Color.web("#38bdf8", 0.9));
            gc.setLineWidth(2.5);
            gc.strokeRoundRect(-len / 2.0 - 4.0, -w / 2.0 - 4.0, len + 8.0, w + 8.0, 5, 5);
        }

        gc.setFill(Color.web("#000000", 0.5));
        gc.fillRoundRect(-len / 2.0 + 1.0, -w / 2.0 + 1.5, len, w, 3.5, 3.5);

        gc.setFill(bodyColor);
        gc.fillRoundRect(-len / 2.0, -w / 2.0, len, w, 3.5, 3.5);

        gc.setStroke(Color.web("#020617", 0.9));
        gc.setLineWidth(1.0);
        gc.strokeRoundRect(-len / 2.0, -w / 2.0, len, w, 3.5, 3.5);

        gc.setFill(Color.web("#020617", 0.8));
        double windshieldW = w * 0.72;
        double windshieldL = len * 0.30;
        gc.fillRoundRect(0.0, -windshieldW / 2.0, windshieldL, windshieldW, 2, 2);

        gc.setFill(Color.web("#fef08a"));
        gc.fillOval(len / 2.0 - 2.5, -w / 2.0 + 1.0, 2.2, 2.2);
        gc.fillOval(len / 2.0 - 2.5, w / 2.0 - 3.2, 2.2, 2.2);

        gc.setFill(Color.web("#ef4444"));
        gc.fillOval(-len / 2.0, -w / 2.0 + 1.0, 2.0, 2.0);
        gc.fillOval(-len / 2.0, w / 2.0 - 3.0, 2.0, 2.0);

        gc.restore();

        // ID label tag
        gc.setFill(Color.web("#0b1329", 0.88));
        gc.fillRoundRect(x - 13.0, y - w / 2.0 - 15.0, 26.0, 11.0, 3, 3);
        gc.setStroke(bodyColor);
        gc.setLineWidth(0.8);
        gc.strokeRoundRect(x - 13.0, y - w / 2.0 - 15.0, 26.0, 11.0, 3, 3);
        gc.setFill(Color.WHITE);
        gc.setFont(Font.font("Segoe UI", FontWeight.BOLD, 8.0));
        gc.setTextAlign(TextAlignment.CENTER);
        gc.setTextBaseline(VPos.CENTER);
        gc.fillText(ghost.getId(), x, y - w / 2.0 - 9.5);
    }

    private void drawSubtleGrid(GraphicsContext gc, double width, double height) {
        gc.setStroke(COLOR_GRID_LINE);
        gc.setLineWidth(1.0);
        double step = 40.0;
        for (double x = 0; x < width; x += step) {
            gc.strokeLine(x, 0, x, height);
        }
        for (double y = 0; y < height; y += step) {
            gc.strokeLine(0, y, width, y);
        }
    }

    private void drawRoad(GraphicsContext gc, Road road) {
        Intersection a = road.getIntersectionA();
        Intersection b = road.getIntersectionB();

        double x1 = a.getX();
        double y1 = a.getY();
        double x2 = b.getX();
        double y2 = b.getY();

        double dx = x2 - x1;
        double dy = y2 - y1;
        double dist = Math.hypot(dx, dy);
        if (dist == 0) return;

        double nx = -dy / dist;
        double ny = dx / dist;

        Color asphaltColor = (road.getRoadType() == RoadType.DIAGONAL) ? COLOR_ROAD_DIAGONAL : COLOR_ROAD_ASPHALT;
        if (road.getCondition() == RoadCondition.CONGESTED) {
            asphaltColor = Color.web("#b45309"); // Congested Amber
        } else if (road.getCondition() == RoadCondition.CLOSED) {
            asphaltColor = Color.web("#7f1d1d"); // Closed Red
        }

        double halfW = ROAD_WIDTH / 2.0;

        double[] xPoints = { x1 + nx * halfW, x2 + nx * halfW, x2 - nx * halfW, x1 - nx * halfW };
        double[] yPoints = { y1 + ny * halfW, y2 + ny * halfW, y2 - ny * halfW, y1 - ny * halfW };

        // Road surface
        gc.setFill(asphaltColor);
        gc.fillPolygon(xPoints, yPoints, 4);

        // Curb borders
        gc.setStroke(COLOR_ROAD_BORDER);
        gc.setLineWidth(1.5);
        gc.strokeLine(x1 + nx * halfW, y1 + ny * halfW, x2 + nx * halfW, y2 + ny * halfW);
        gc.strokeLine(x1 - nx * halfW, y1 - ny * halfW, x2 - nx * halfW, y2 - ny * halfW);

        // Center dashed line
        gc.setStroke(COLOR_LANE_DIVIDER);
        gc.setLineWidth(1.8);
        gc.setLineDashes(9.0, 7.0);
        gc.strokeLine(x1, y1, x2, y2);
        gc.setLineDashes(null);

        // Direction Arrows
        drawLaneArrow(gc, x1, y1, x2, y2, nx, ny, 0.40, +1);
        drawLaneArrow(gc, x2, y2, x1, y1, nx, ny, 0.40, -1);
    }

    private void drawLaneArrow(GraphicsContext gc, double x1, double y1, double x2, double y2,
                               double nx, double ny, double fraction, int side) {
        double px = x1 + (x2 - x1) * fraction;
        double py = y1 + (y2 - y1) * fraction;

        double laneOffset = (LANE_WIDTH / 2.0) * side;
        px += nx * laneOffset;
        py += ny * laneOffset;

        double angle = Math.atan2(y2 - y1, x2 - x1);

        gc.save();
        gc.translate(px, py);
        gc.rotate(Math.toDegrees(angle));

        gc.setStroke(COLOR_ARROW);
        gc.setLineWidth(2.0);
        gc.strokeLine(-5, -4, 4, 0);
        gc.strokeLine(-5, 4, 4, 0);

        gc.restore();
    }

    private void drawIntersection(GraphicsContext gc, Intersection intersection) {
        double cx = intersection.getX();
        double cy = intersection.getY();
        double half = JUNCTION_SIZE / 2.0;

        // Junction box
        gc.setFill(COLOR_JUNCTION_BOX);
        gc.fillRoundRect(cx - half, cy - half, JUNCTION_SIZE, JUNCTION_SIZE, 12, 12);

        gc.setStroke(COLOR_JUNCTION_BORDER);
        gc.setLineWidth(2.0);
        gc.strokeRoundRect(cx - half, cy - half, JUNCTION_SIZE, JUNCTION_SIZE, 12, 12);

        // Draw stop lines & 3-aspect signal heads for each incoming road
        drawApproachSignals(gc, intersection);

        // Central ID badge
        gc.setFill(Color.web("#0a0f1d", 0.90));
        gc.fillOval(cx - 14, cy - 14, 28, 28);
        gc.setStroke(Color.web("#38bdf8"));
        gc.setLineWidth(1.5);
        gc.strokeOval(cx - 14, cy - 14, 28, 28);

        gc.setFill(Color.web("#f8fafc"));
        gc.setFont(Font.font("Segoe UI", FontWeight.BOLD, 11));
        gc.setTextAlign(TextAlignment.CENTER);
        gc.setTextBaseline(VPos.CENTER);
        gc.fillText(intersection.getId(), cx, cy);
    }

    private void drawApproachSignals(GraphicsContext gc, Intersection intersection) {
        List<Road> roads = intersection.getConnectedRoads();
        int roadCount = roads.size();

        // Remove traffic lights at 2-junction (2-way) roads - only multi-way junctions require signal control
        if (roadCount <= 2) {
            return;
        }

        double cx = intersection.getX();
        double cy = intersection.getY();

        for (int i = 0; i < roadCount; i++) {
            Road road = roads.get(i);
            Intersection other = road.getOtherEnd(intersection);
            if (other == null) continue;

            double dx = other.getX() - cx;
            double dy = other.getY() - cy;
            double dist = Math.hypot(dx, dy);
            if (dist == 0) continue;

            // Unit vector pointing towards the oncoming road approach
            double ux = dx / dist;
            double uy = dy / dist;

            // In right-hand traffic, approaching vector is (-ux, -uy).
            // Vector perpendicular to oncoming road pointing to incoming lane curb is (uy, -ux).
            double curbX = uy;
            double curbY = -ux;

            // Position signal head on incoming lane curb side near stop line
            double headDist = (JUNCTION_SIZE / 2.0) + 12.0;
            double lateralOffset = (ROAD_WIDTH / 2.0) + 7.0;

            double headX = cx + ux * headDist + curbX * lateralOffset;
            double headY = cy + uy * headDist + curbY * lateralOffset;

            // Road orientation angle in radians (so signal head aligns parallel to its road)
            double roadAngle = Math.atan2(dy, dx);

            // Get approach signal state
            TrafficSignal sig = intersection.getApproachSignal(road.getId());
            SignalColor activeColor = (sig != null) ? sig.getState() : SignalColor.RED;

            // Draw white stop line across the incoming lane only
            drawStopLine(gc, cx, cy, ux, uy, curbX, curbY);

            // Draw 3-aspect vertical traffic signal head aligned parallel to road
            drawThreeAspectSignalHead(gc, headX, headY, roadAngle, activeColor);
        }
    }

    private void drawStopLine(GraphicsContext gc, double cx, double cy, double ux, double uy, double curbX, double curbY) {
        double stopLineDist = (JUNCTION_SIZE / 2.0) + 2.0;
        double stopCenterX = cx + ux * stopLineDist;
        double stopCenterY = cy + uy * stopLineDist;

        // Lane width segment across incoming lane (from lane divider to curb)
        double p1x = stopCenterX + curbX * 1.5;
        double p1y = stopCenterY + curbY * 1.5;
        double p2x = stopCenterX + curbX * (ROAD_WIDTH / 2.0);
        double p2y = stopCenterY + curbY * (ROAD_WIDTH / 2.0);

        gc.setStroke(COLOR_STOP_LINE);
        gc.setLineWidth(3.0);
        gc.strokeLine(p1x, p1y, p2x, p2y);
    }

    private void drawThreeAspectSignalHead(GraphicsContext gc, double x, double y, double angle, SignalColor active) {
        double headW = 10.0;
        double headH = 26.0;
        double r = 2.8;

        gc.save();
        // Translate to signal position and rotate parallel to the road approach
        gc.translate(x, y);
        gc.rotate(Math.toDegrees(angle) + 90.0); // Aligns the vertical aspect parallel along the road direction

        // Housing body (dark protective rounded box)
        gc.setFill(Color.web("#090d16"));
        gc.fillRoundRect(-headW / 2.0, -headH / 2.0, headW, headH, 5, 5);

        gc.setStroke(Color.web("#475569"));
        gc.setLineWidth(1.0);
        gc.strokeRoundRect(-headW / 2.0, -headH / 2.0, headW, headH, 5, 5);

        // 3 Vertically stacked lamps: Red (top), Yellow (middle), Green (bottom)
        double redY = -7.5;
        double yellowY = 0.0;
        double greenY = 7.5;

        // 🔴 Red Lamp
        if (active == SignalColor.RED) {
            gc.setFill(Color.web("#ef4444", 0.35));
            gc.fillOval(-r - 2.5, redY - r - 2.5, (r + 2.5) * 2, (r + 2.5) * 2);
            gc.setFill(Color.web("#ff2222"));
            gc.fillOval(-r, redY - r, r * 2, r * 2);
        } else {
            gc.setFill(Color.web("#450a0a"));
            gc.fillOval(-r, redY - r, r * 2, r * 2);
        }

        // 🟡 Yellow Lamp
        if (active == SignalColor.YELLOW) {
            gc.setFill(Color.web("#f59e0b", 0.35));
            gc.fillOval(-r - 2.5, yellowY - r - 2.5, (r + 2.5) * 2, (r + 2.5) * 2);
            gc.setFill(Color.web("#ffcc00"));
            gc.fillOval(-r, yellowY - r, r * 2, r * 2);
        } else {
            gc.setFill(Color.web("#451a03"));
            gc.fillOval(-r, yellowY - r, r * 2, r * 2);
        }

        // 🟢 Green Lamp
        if (active == SignalColor.GREEN) {
            gc.setFill(Color.web("#10b981", 0.35));
            gc.fillOval(-r - 2.5, greenY - r - 2.5, (r + 2.5) * 2, (r + 2.5) * 2);
            gc.setFill(Color.web("#10e784"));
            gc.fillOval(-r, greenY - r, r * 2, r * 2);
        } else {
            gc.setFill(Color.web("#064e3b"));
            gc.fillOval(-r, greenY - r, r * 2, r * 2);
        }

        gc.restore();
    }

    private void drawLandmarkBadge(GraphicsContext gc, Landmark landmark, double x, double y) {
        double pillW = 148;
        double pillH = 26;
        double pillX;
        double pillY;

        // Smart landmark placement based on junction position so badges never clash with roads, signals, or junctions
        switch (landmark.getIntersectionId()) {
            case "J1": // Railway station at top-left -> place above and to the left
                pillX = x - 10;
                pillY = y - 56;
                break;
            case "J3": // Hospital at top-right -> place above and to the right
                pillX = x - pillW + 10;
                pillY = y - 56;
                break;
            case "J6": // Downtown City Center -> place to the upper-right clear of roads
                pillX = x + 35;
                pillY = y - 48;
                break;
            case "J8": // University at bottom-left -> place below and to the left
                pillX = x - 30;
                pillY = y + 42;
                break;
            case "J10": // Mall at bottom-right -> place below and to the right
                pillX = x - pillW + 25;
                pillY = y + 42;
                break;
            default:
                pillX = x - pillW / 2.0;
                pillY = y - 56;
                break;
        }

        Color badgeColor;
        switch (landmark.getType()) {
            case HOSPITAL:
                badgeColor = Color.web("#ef4444"); // Red Cross
                break;
            case RAILWAY_STATION:
                badgeColor = Color.web("#06b6d4"); // Cyan Station
                break;
            case CITY_CENTER:
                badgeColor = Color.web("#8b5cf6"); // Purple Center
                break;
            case SHOPPING_MALL:
                badgeColor = Color.web("#f59e0b"); // Amber Mall
                break;
            case UNIVERSITY:
                badgeColor = Color.web("#10b981"); // Green University
                break;
            default:
                badgeColor = Color.web("#64748b");
        }

        // Pill background
        gc.setFill(Color.web("#0f172a", 0.95));
        gc.fillRoundRect(pillX, pillY, pillW, pillH, 13, 13);

        gc.setStroke(badgeColor);
        gc.setLineWidth(1.8);
        gc.strokeRoundRect(pillX, pillY, pillW, pillH, 13, 13);

        // Icon dot
        gc.setFill(badgeColor);
        gc.fillOval(pillX + 8, pillY + 6.5, 13, 13);

        // Icon Text / Code
        gc.setFill(Color.WHITE);
        gc.setFont(Font.font("Segoe UI", FontWeight.BOLD, 9));
        gc.setTextAlign(TextAlignment.CENTER);
        gc.setTextBaseline(VPos.CENTER);
        gc.fillText(landmark.getIconCode(), pillX + 14.5, pillY + 13);

        // Label
        gc.setFill(Color.web("#f1f5f9"));
        gc.setFont(Font.font("Segoe UI", FontWeight.SEMI_BOLD, 10.5));
        gc.setTextAlign(TextAlignment.LEFT);
        gc.fillText(landmark.getName(), pillX + 27, pillY + 13);

        // Connector pointer stem to intersection
        gc.setStroke(badgeColor);
        gc.setLineWidth(1.5);
        if (pillY < y) {
            gc.strokeLine(pillX + pillW / 2.0, pillY + pillH, x, y - 28);
        } else {
            gc.strokeLine(pillX + pillW / 2.0, pillY, x, y + 28);
        }
    }
}
