package entropy;

import com.badlogic.gdx.Game;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import entropy.ui.MainScreen;

public class EntropyGame extends Game {
    public static SpriteBatch batch;

    @Override
    public void create() {
        batch = new SpriteBatch();
        Vars.init();
        
        // Khởi tạo màn hình chính
        setScreen(new MainScreen());
    }

    @Override
    public void dispose() {
        super.dispose();
        batch.dispose();
    }
}