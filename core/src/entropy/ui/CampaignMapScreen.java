package entropy.ui;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.ScreenAdapter;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.scenes.scene2d.InputEvent;
import com.badlogic.gdx.scenes.scene2d.Stage;
import com.badlogic.gdx.scenes.scene2d.ui.Label;
import com.badlogic.gdx.scenes.scene2d.ui.Table;
import com.badlogic.gdx.scenes.scene2d.ui.TextButton;
import com.badlogic.gdx.scenes.scene2d.utils.ClickListener;
import com.badlogic.gdx.utils.viewport.ScreenViewport;
import entropy.EntropyGame;
import entropy.Vars;

public class CampaignMapScreen extends ScreenAdapter {
    private Stage stage;

    @Override
    public void show() {
        stage = new Stage(new ScreenViewport());
        Gdx.input.setInputProcessor(stage);

        Table table = new Table();
        table.setFillParent(true);
        stage.addActor(table);

        Label title = new Label("Campaign Maps", Vars.skin);
        table.add(title).padBottom(20).row();

        String[] maps = {"Earth", "Moon", "Mars"};
        for (String mapName : maps) {
            TextButton btn = new TextButton(mapName, Vars.skin);
            table.add(btn).width(200).pad(5).row();
            
            btn.addListener(new ClickListener() {
                @Override
                public void clicked(InputEvent event, float x, float y) {
                    ((EntropyGame) Gdx.app.getApplicationListener()).setScreen(new EditorScreen(mapName));
                }
            });
        }

        TextButton backBtn = new TextButton("Back", Vars.skin);
        table.add(backBtn).padTop(20).row();
        backBtn.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                ((EntropyGame) Gdx.app.getApplicationListener()).setScreen(new MainScreen());
            }
        });
    }

    @Override
    public void render(float delta) {
        Gdx.gl.glClearColor(0.15f, 0.15f, 0.2f, 1);
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
