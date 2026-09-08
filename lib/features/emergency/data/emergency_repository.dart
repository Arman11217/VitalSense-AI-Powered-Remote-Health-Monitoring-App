import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../domain/emergency_models.dart';

/// Repository contract for emergency contacts and event history.
abstract class EmergencyRepository {
  Future<List<EmergencyContact>> getContacts(String uid);
  Future<void> addContact(String uid, EmergencyContact contact);
  Future<void> removeContact(String uid, String contactId);
  Future<EmergencyEvent> triggerEmergency({
    required String uid,
    required EmergencySeverity severity,
    String? note,
  });
  Stream<EmergencyEvent> latestEvent(String uid);
}

/// In-memory implementation (no Firebase wiring required to use the app).
class InMemoryEmergencyRepository implements EmergencyRepository {
  InMemoryEmergencyRepository() {
    _seedDemo();
  }

  final Map<String, List<EmergencyContact>> _contacts =
      <String, List<EmergencyContact>>{};
  final Map<String, EmergencyEvent> _latest = <String, EmergencyEvent>{};
  final StreamController<EmergencyEvent> _eventCtrl =
      StreamController<EmergencyEvent>.broadcast();
  static const Uuid _uuid = Uuid();

  void _seedDemo() {
    _contacts['demo-patient'] = <EmergencyContact>[
      const EmergencyContact(
        id: 'demo-c-1',
        name: 'Dr. Sarah Khan',
        phone: '+8801711000001',
        relation: 'Cardiologist',
        isPrimary: true,
      ),
      const EmergencyContact(
        id: 'demo-c-2',
        name: 'Imran Hossain',
        phone: '+8801711000002',
        relation: 'Brother',
      ),
    ];
  }

  @override
  Future<List<EmergencyContact>> getContacts(String uid) async {
    return List<EmergencyContact>.unmodifiable(
      _contacts[uid] ?? <EmergencyContact>[...?_contacts['demo-patient']],
    );
  }

  @override
  Future<void> addContact(String uid, EmergencyContact contact) async {
    final list = _contacts.putIfAbsent(uid, () => <EmergencyContact>[]);
    list.add(contact);
  }

  @override
  Future<void> removeContact(String uid, String contactId) async {
    _contacts[uid]?.removeWhere((c) => c.id == contactId);
  }

  @override
  Future<EmergencyEvent> triggerEmergency({
    required String uid,
    required EmergencySeverity severity,
    String? note,
  }) async {
    // Pretend to read a location; in real builds this comes from
    // the `geolocator` package.  Random within a Dhaka-area box.
    final rand = Random();
    final event = EmergencyEvent(
      id: _uuid.v4(),
      triggeredAt: DateTime.now(),
      severity: severity,
      status: EmergencyStatus.triggered,
      lat: 23.78 + rand.nextDouble() * 0.05,
      lng: 90.40 + rand.nextDouble() * 0.05,
      note: note,
    );
    _latest[uid] = event;
    _eventCtrl.add(event);
    return event;
  }

  @override
  Stream<EmergencyEvent> latestEvent(String uid) async* {
    final cached = _latest[uid];
    if (cached != null) yield cached;
    yield* _eventCtrl.stream;
  }
}