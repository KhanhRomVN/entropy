package entropy.desktop;

import com.badlogic.gdx.backends.lwjgl3.Lwjgl3Application;
import com.badlogic.gdx.backends.lwjgl3.Lwjgl3ApplicationConfiguration;
import entropy.EntropyGame;

public class DesktopLauncher {
    public static void main(String[] args) {
        Lwjgl3ApplicationConfiguration config = new Lwjgl3ApplicationConfiguration();
        config.setTitle("Entropy");
        config.setWindowedMode(800, 600);
        config.setForegroundFPS(60);
        new Lwjgl3Application(new EntropyGame(), config);
    }
}