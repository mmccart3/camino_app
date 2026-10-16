import 'ahead_of_me.dart';

/// First recorded service in walking order; unknown is not evidence of presence.
class NextServices {
  final AheadPlace? cafe, pharmacy, shop;
  const NextServices(this.cafe, this.pharmacy, this.shop);
  factory NextServices.from(List<AheadPlace> ahead) => NextServices(
    ahead.where((p) => p.location.hasBarCafe == true).firstOrNull,
    ahead.where((p) => p.location.hasPharmacy == true).firstOrNull,
    ahead.where((p) => p.location.hasGroceryStore == true).firstOrNull,
  );
  bool get isEmpty => cafe == null && pharmacy == null && shop == null;
}
