package entropy;

import com.badlogic.gdx.scenes.scene2d.ui.Skin;
import entropy.content.ContentLoader;
import entropy.content.Blocks;
import entropy.content.Planets;

public class Vars {
    public static final String appName = "Entropy";
    public static Skin skin;
    public static ContentLoader content;

    public static void init() {
        content = new ContentLoader();
        content.load();
        
        // Sẽ nạp skin UI sau
    }
}
