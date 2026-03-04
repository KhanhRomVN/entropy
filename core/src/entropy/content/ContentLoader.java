package entropy.content;

import com.badlogic.gdx.utils.Array;
import entropy.world.Block;

public class ContentLoader {
    private Array<Block> blocks = new Array<>();
    private Array<Planet> planets = new Array<>();

    public void load() {
        Blocks.load();
        Planets.load();
    }

    public void addBlock(Block block) {
        blocks.add(block);
    }

    public void addPlanet(Planet planet) {
        planets.add(planet);
    }
}
