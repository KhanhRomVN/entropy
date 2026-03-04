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

public class MainScreen extends ScreenAdapter {
    private Stage stage;

    @Override
    public void show() {
        stage = new Stage(new ScreenViewport());
        Gdx.input.setInputProcessor(stage);
        
        if (Vars.skin == null) {
            Vars.skin = UIUtils.createBasicSkin();
        }

        Table table = new Table();
        table.setFillParent(true);
        stage.addActor(table);

        // 1. Tên game ở góc trái trên
        Label titleLabel = new Label("Entropy", Vars.skin);
        titleLabel.setFontScale(2.0f);
        
        Table topTable = new Table();
        topTable.top().left();
        topTable.add(titleLabel).pad(20);
        
        stage.addActor(topTable);
        topTable.setFillParent(true);

        // 2. Các button
        TextButton campaignBtn = new TextButton("Campaign", Vars.skin);
        campaignBtn.setDisabled(true);
        
        TextButton modsBtn = new TextButton("Mods", Vars.skin);
        modsBtn.setDisabled(true);
        
        TextButton mapsDevBtn = new TextButton("Maps (Developer)", Vars.skin);
        
        TextButton mapsBtn = new TextButton("Maps", Vars.skin);
        mapsBtn.setDisabled(true);
        
        TextButton settingBtn = new TextButton("Setting", Vars.skin);
        settingBtn.setDisabled(true);

        table.center();
        table.add(campaignBtn).width(200).pad(5).row();
        table.add(modsBtn).width(200).pad(5).row();
        table.add(mapsDevBtn).width(200).pad(5).row();
        table.add(mapsBtn).width(200).pad(5).row();
        table.add(settingBtn).width(200).pad(5).row();

        // Sự kiện click Maps (Dev)
        mapsDevBtn.addListener(new ClickListener() {
            @Override
            public void clicked(InputEvent event, float x, float y) {
                ((EntropyGame) Gdx.app.getApplicationListener()).setScreen(new CampaignMapScreen());
            }
        });
    }

    @Override
    public void render(float delta) {
        Gdx.gl.glClearColor(0.1f, 0.1f, 0.1f, 1);
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
