package entropy.content;

import entropy.world.Block;

public class Blocks {
    public static Block stone;

    public static void load() {
        stone = new Block("stone");
    }
}
