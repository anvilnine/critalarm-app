package app.critalarm.taps

/**
 * The extras Flutter's own activity turns into engine start options.
 *
 * FlutterFragmentActivity reads them off the intent that started it, on a
 * cold start (FlutterShellArgs.fromIntent), and any app can set them: they
 * switch the renderer, clear caches, write traces and pass Dart flags. A
 * build that is not debuggable has no use for them, so [TapGate.admit] takes
 * them off every intent. A debuggable build keeps them, because `flutter run`
 * sends its own through the same door.
 *
 * Pure, so a JVM test can reach it.
 */
object FlutterShellExtras {
    /** The extra names of FlutterShellArgs, one per start option. */
    val NAMES: List<String> = listOf(
        "trace-startup",
        "start-paused",
        "disable-service-auth-codes",
        "endless-trace-buffer",
        "use-test-fonts",
        "enable-dart-profiling",
        "profile-startup",
        "enable-software-rendering",
        "skia-deterministic-rendering",
        "trace-skia",
        "trace-skia-allowlist",
        "trace-systrace",
        "trace-to-file",
        "profile-microtasks",
        "enable-impeller",
        "enable-vulkan-validation",
        "enable-hcpp-and-surface-control",
        "dump-skp-on-shader-compilation",
        "cache-sksl",
        "purge-persistent-cache",
        "verbose-logging",
        "vm-service-port",
        "dart-flags",
        // Read by FlutterFragmentActivity itself (engine lifetime, entrypoint args).
        "destroy_engine_with_activity",
        "dart_entrypoint_args",
    )
}
