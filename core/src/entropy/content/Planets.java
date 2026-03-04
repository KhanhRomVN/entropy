package entropy.content;

public class Planets {
    public static Planet earth, moon, mars;

    public static void load() {
        earth = new Planet("earth");
        moon = new Planet("moon");
        mars = new Planet("mars");
    }
}
