import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_notifier.dart';
import '../data/service_model.dart';

class ServicesState {
  const ServicesState({
    this.services = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ServiceModel> services;
  final bool isLoading;
  final String? error;

  bool get hasError => error != null;

  ServicesState copyWith({
    List<ServiceModel>? services,
    bool? isLoading,
    String? error,
  }) {
    return ServicesState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ServicesNotifier extends Notifier<ServicesState> {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  ServicesState build() {
    final userId = ref.watch(authNotifierProvider).user?.id;
    if (userId != null) {
      Future.microtask(() => fetchServices(userId));
    }
    return const ServicesState();
  }

  Future<void> fetchServices(String providerId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _client
          .from('services')
          .select()
          .eq('provider_id', providerId)
          .order('created_at', ascending: false);

      final services = (rows as List)
          .map((r) => ServiceModel.fromJson(r as Map<String, dynamic>))
          .toList();
      state = state.copyWith(services: services, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addService({
    required String title,
    required String description,
    String? priceText,
  }) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _client.from('services').insert({
        'provider_id': userId,
        'title': title,
        'description': description,
        if (priceText != null && priceText.isNotEmpty) 'price_text': priceText,
        'is_active': true,
      });
      await fetchServices(userId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteService(String serviceId) async {
    final userId = ref.read(authNotifierProvider).user?.id;
    if (userId == null) return;

    try {
      await _client.from('services').delete().eq('id', serviceId);
      await fetchServices(userId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final servicesNotifierProvider =
    NotifierProvider<ServicesNotifier, ServicesState>(ServicesNotifier.new);
