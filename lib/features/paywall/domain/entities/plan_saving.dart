/// How much the yearly plan saves against paying monthly for twelve months,
/// as a whole percent. Null when either price is missing or the yearly plan
/// is not cheaper, so the screen never claims a saving the store prices do not
/// show. Both prices must be in the same currency, which they are because they
/// come from the same store offering.
int? yearlySavingPercent({
  required double? monthlyPrice,
  required double? yearlyPrice,
}) {
  if (monthlyPrice == null || yearlyPrice == null) return null;
  if (monthlyPrice <= 0 || yearlyPrice <= 0) return null;
  final percent = ((1 - yearlyPrice / (monthlyPrice * 12)) * 100).round();
  return percent > 0 ? percent : null;
}
