/// [a] to [b] by [x], landing exactly on [b] from 1 up. The two outro
/// timelines use it so a finished move rests on its target and not a
/// rounding step beside it.
double outroLerp(double a, double b, double x) => x >= 1 ? b : a + (b - a) * x;
