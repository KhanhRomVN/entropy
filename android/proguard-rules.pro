# Keep all LibGDX classes
-keep class com.badlogic.gdx.** { *; }
-keep class com.badlogic.gdx.backends.android.** { *; }

# Keep our game classes
-keep class entropy.** { *; }

# Optimizations
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify

# Remove debug logs
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}