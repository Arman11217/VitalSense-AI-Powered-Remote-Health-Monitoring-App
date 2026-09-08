import 'package:equatable/equatable.dart';

/// Status of a triggered emergency event.
enum EmergencyStatus { idle, triggered, acknowledged, resolved }

/// Severity tier chosen by the user / clinician.
enum EmergencySeverity {
  low('Low · non-urgent'),
  medium('Medium · needs attention'),
  high('High · urgent'),
  critical('Critical · life-threatening');

  const EmergencySeverity(this.label);
  final String label;
}

/// Emergency contact stored in the user's profile.
class EmergencyContact extends Equatable {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation = 'Contact',
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool isPrimary;

  EmergencyContact copyWith({
    String? name,
    String? phone,
    String? relation,
    bool? isPrimary,
  }) =>
      EmergencyContact(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relation: relation ?? this.relation,
        isPrimary: isPrimary ?? this.isPrimary,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
        'isPrimary': isPrimary,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) => EmergencyContact(
        id: map['id'] as String,
        name: map['name'] as String? ?? 'Unnamed',
        phone: map['phone'] as String? ?? '',
        relation: map['relation'] as String? ?? 'Contact',
        isPrimary: map['isPrimary'] as bool? ?? false,
      );

  @override
  List<Object?> get props => <Object?>[id, name, phone, relation, isPrimary];
}

/// An emergency event recorded in the system.
class EmergencyEvent extends Equatable {
  const EmergencyEvent({
    required this.id,
    required this.triggeredAt,
    required this.severity,
    required this.status,
    required this.lat,
    required this.lng,
    this.note,
  });

  final String id;
  final DateTime triggeredAt;
  final EmergencySeverity severity;
  final EmergencyStatus status;
  final double lat;
  final double lng;
  final String? note;

  EmergencyEvent copyWith({EmergencyStatus? status}) => EmergencyEvent(
        id: id,
        triggeredAt: triggeredAt,
        severity: severity,
        status: status ?? this.status,
        lat: lat,
        lng: lng,
        note: note,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, triggeredAt, severity, status, lat, lng, note];
}