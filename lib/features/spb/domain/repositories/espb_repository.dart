import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../data/models/espb_form_model.dart';

abstract class EspbRepository {
  /// Saves an ESPB form to local storage and attempts to sync with server if online
  /// Returns true if synced with server, false if only saved locally
  Future<Either<Failure, bool>> saveEspbForm(EspbFormModel formData);
  
  /// Gets an ESPB form from local storage
  Future<Either<Failure, EspbFormModel?>> getEspbForm(String noSpb);
  
  /// Syncs a specific ESPB form with the server
  Future<Either<Failure, bool>> syncEspbForm(String noSpb);
  
  /// Syncs all pending ESPB forms with the server
  /// Returns the number of successfully synced forms
  Future<Either<Failure, int>> syncAllPendingEspbForms();
  
  /// Migrates ESPB forms from SharedPreferences to SQLite
  Future<Either<Failure, void>> migrateEspbFormsFromSharedPreferences();
}