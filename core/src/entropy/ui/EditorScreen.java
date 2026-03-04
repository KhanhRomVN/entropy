package entropy.ui;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.utils.viewport.ScreenViewport;
import entropy.Vars;

public class EditorScreen extends ScreenAdapter {
    private Stage stage;
    private String mapName;

    public EditorScreen(String mapName) {
        this.mapName = mapName;
    }

    @Override
    public void show() {
        stage = new Stage(new ScreenViewport());
        Gdx.input.setInputProcessor(stage);

        // UI chính của Editor
        Table root = new Table();
        root.setFillParent(true);
        stage.addActor(root);

        // Toolbar phía trên
        Table toolbar = new Table();
        toolbar.setBackground(Vars.skin.newDrawable("white", 0.2f, 0.2f, 0.2f, 1));
        
        TextButton terrainBtn = new TextButton("Terrain", Vars.skin);
        TextButton blocksBtn = new TextButton("Blocks", Vars.skin);
        TextButton lightBtn = new TextButton("Lighting", Vars.skin);
        TextButton saveBtn = new TextButton("Save", Vars.skin);

        toolbar.add(terrainBtn).pad(5);
        toolbar.add(blocksBtn).pad(5);
        toolbar.add(lightBtn).pad(5);
        toolbar.add(new Label("Editing: " + mapName, Vars.skin)).pad(20).expandX();
        toolbar.add(saveBtn).pad(5);

        root.top();
        root.add(toolbar).fillX().row();
        
        // Khu vực vẽ map (tạm thời để trống)
        root.add(new Label("Map Area", Vars.skin)).expand().center();
    }

    @Override
    public void render(float delta) {
        Gdx.gl.glClearColor(0.2f, 0.2f, 0.2f, 1);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);
        stage.act(delta);
        stage.draw();
    }

    @Override
    public void resize(int width, int height) {
        stage.getViewport().update(width, height, true);
    }

    @Override
    public void dispose() {
        stage.dispose();
    }
}
