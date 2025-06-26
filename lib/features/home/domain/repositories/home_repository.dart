import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

abstract class HomeRepository {
  Future<Either<Failure, Map<String, dynamic>>> getDashboardMetrics();
  Future<Either<Failure, List<Map<String, dynamic>>>> getActivities();
}