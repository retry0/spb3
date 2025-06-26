import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository repository;

  LogoutUseCase(this.repository);

  Future<Either<Failure, void>> call({int maxRetries = 3}) async {
    int attempts = 0;
    Either<Failure, void> result;

    do {
      attempts++;
      result = await repository.logout();
      
      // If successful or reached max retries, break the loop
      if (result.isRight() || attempts >= maxRetries) {
        break;
      }
      
      // Wait before retrying (exponential backoff)
      await Future.delayed(Duration(milliseconds: 500 * attempts));
    } while (attempts < maxRetries);

    return result;
  }
}