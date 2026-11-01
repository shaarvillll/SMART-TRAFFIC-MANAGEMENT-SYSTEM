package com.traffic.desktop;

/**
 * Launcher class without extending Application directly.
 * This circumvents the JavaFX 11+ runtime check when launched from standard classpath/cmd.
 */
public class Launcher {
    public static void main(String[] args) {
        TrafficDesktopApp.main(args);
    }
}
