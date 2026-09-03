import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:genesis_picking/features/administration/domain/administration_service.dart';
import 'package:genesis_picking/features/auth/auth_providers.dart';
import 'package:genesis_picking/features/courier/courier_providers.dart';
import 'package:genesis_picking/features/tours/tours_providers.dart';

final administrationServiceProvider = Provider<AdministrationService>((ref) {
  return AdministrationService(
    tourRepository: ref.watch(tourRepositoryProvider),
    courierRepository: ref.watch(courierRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});
