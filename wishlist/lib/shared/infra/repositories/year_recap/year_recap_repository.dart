import 'package:wishlist/shared/models/year_recap/year_recap.dart';

abstract class YearRecapRepository {
  /// The figures and the profile of the current user for [year]
  /// (`get_my_year_recap`).
  Future<YearRecapData> getMyYearRecap(int year);

  /// Public URL of an illustration of the bucket `year-recap-illustrations`.
  String illustrationUrl(String path);
}
