import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/errors.dart';
import '../models/account_models.dart';
import '../models/catalog_models.dart';
import 'catalog_repository.dart' show providerSelect;

/// Private business contact (`public.provider_private`, owner + admin only).
class ProviderPrivate {
  const ProviderPrivate({this.phone, this.whatsapp, this.email});
  final String? phone;
  final String? whatsapp;
  final String? email;
}

/// Everything a provider account manages. RLS scopes every call to the
/// caller's own business; the guard trigger owns status/ownership columns.
class ProviderPortalRepository {
  ProviderPortalRepository(this._client);

  final SupabaseClient? _client;
  SupabaseClient get _c => _client ?? (throw const BackendUnavailable());

  static const mediaBucket = 'provider-media';

  bool get isAvailable => _client != null;

  // ── Business listing ──────────────────────────────────────────────────
  Future<SawaProvider?> fetchMyProvider(String userId) async {
    final row = await _c.from('providers').select(providerSelect).eq('user_id', userId).maybeSingle();
    return row == null ? null : SawaProvider.fromJson(row);
  }

  /// Creates the business as a draft. `user_id`, `source` and timestamps
  /// are enforced server-side regardless of what is sent.
  Future<String> createProvider(String userId, Map<String, dynamic> fields) async {
    final row =
        await _c.from('providers').insert({...fields, 'user_id': userId, 'status': 'draft'}).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateProvider(String providerId, Map<String, dynamic> fields) =>
      _c.from('providers').update(fields).eq('id', providerId);

  /// draft → pending (submit for SAWA review) or pending → draft (withdraw).
  Future<void> setStatus(String providerId, ListingStatus status) =>
      _c.from('providers').update({'status': status.dbValue}).eq('id', providerId);

  Future<ProviderPrivate> fetchPrivate(String providerId) async {
    final row =
        await _c.from('provider_private').select('phone, whatsapp, email').eq('provider_id', providerId).maybeSingle();
    return ProviderPrivate(
      phone: row?['phone'] as String?,
      whatsapp: row?['whatsapp'] as String?,
      email: row?['email'] as String?,
    );
  }

  Future<void> savePrivate(String providerId, ProviderPrivate p) => _c.from('provider_private').upsert({
        'provider_id': providerId,
        'phone': p.phone,
        'whatsapp': p.whatsapp,
        'email': p.email,
      });

  // ── Services ──────────────────────────────────────────────────────────
  Future<void> saveService(String providerId, Map<String, dynamic> fields, {String? id}) => id == null
      ? _c.from('services').insert({...fields, 'provider_id': providerId})
      : _c.from('services').update(fields).eq('id', id);

  Future<void> deleteService(String id) => _c.from('services').delete().eq('id', id);

  // ── Packages & offers ─────────────────────────────────────────────────
  Future<void> savePackage(String providerId, Map<String, dynamic> fields, {String? id}) => id == null
      ? _c.from('provider_packages').insert({...fields, 'provider_id': providerId})
      : _c.from('provider_packages').update(fields).eq('id', id);

  Future<void> deletePackage(String id) => _c.from('provider_packages').delete().eq('id', id);

  // ── Gallery (Storage: provider-media/<provider_id>/...) ──────────────
  Future<void> uploadImage({
    required String providerId,
    required Uint8List bytes,
    required String extension,
    required bool asCover,
    required int sortOrder,
  }) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '$providerId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _c.storage.from(mediaBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    final url = _c.storage.from(mediaBucket).getPublicUrl(path);
    if (asCover) {
      await _c.from('provider_images').update({'kind': 'gallery'}).eq('provider_id', providerId).eq('kind', 'cover');
    }
    await _c.from('provider_images').insert({
      'provider_id': providerId,
      'url': url,
      'storage_path': path,
      'kind': asCover ? 'cover' : 'gallery',
      'sort_order': sortOrder,
      'source': 'upload',
    });
    if (asCover) await updateProvider(providerId, {'cover_image_url': url});
  }

  Future<void> setCover(String providerId, ProviderImage image) async {
    await _c.from('provider_images').update({'kind': 'gallery'}).eq('provider_id', providerId).eq('kind', 'cover');
    await _c.from('provider_images').update({'kind': 'cover'}).eq('id', image.id);
    await updateProvider(providerId, {'cover_image_url': image.url});
  }

  Future<void> deleteImage(String providerId, ProviderImage image) async {
    if (image.storagePath != null) {
      await _c.storage.from(mediaBucket).remove([image.storagePath!]);
    }
    await _c.from('provider_images').delete().eq('id', image.id);
    if (image.kind == ImageKind.cover) {
      await updateProvider(providerId, {'cover_image_url': null});
    }
  }

  // ── Real analytics + forwarded requests ───────────────────────────────
  Future<ProviderStats> fetchStats(String providerId) async {
    final data = await _c.rpc('get_provider_stats', params: {'p_provider_id': providerId});
    return ProviderStats.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// RLS returns only requests SAWA has forwarded to this business.
  Future<List<ContactRequestRecord>> fetchForwardedRequests(String providerId) async {
    final data = await _c
        .from('contact_requests')
        .select('id, reference_code, status, user_name, user_contact, note, created_at, '
            'provider_uuid, provider_id, forwarded_to_provider_at')
        .eq('provider_uuid', providerId)
        .not('forwarded_to_provider_at', 'is', null)
        .order('forwarded_to_provider_at', ascending: false);
    return data.map(ContactRequestRecord.fromJson).toList();
  }

  Future<void> updateRequestStatus(int id, RequestStatus status) =>
      _c.from('contact_requests').update({'status': status.dbValue}).eq('id', id);
}
