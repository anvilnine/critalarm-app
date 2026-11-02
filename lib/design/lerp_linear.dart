/// [a] to [b] by [t], with no clamping: a plain `a + (b - a) * t`. At 1 it can
/// differ from [b] by a rounding step, which is why the paywall outros keep
/// their own `outroLerp`.
double lerpLinear(double a, double b, double t) => a + (b - a) * t;
