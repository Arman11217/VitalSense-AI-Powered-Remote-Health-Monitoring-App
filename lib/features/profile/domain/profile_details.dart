import 'package:equatable/equatable.dart';

/// User-editable profile fields (stored locally in `shared_preferences`).
class ProfileDetails extends Equatable {
  const ProfileDetails({
    this.fullName = '',
    this.age = '',
    this.bloodGroup = 'Unknown',
    this.heightCm = '',
    this.weightKg = '',
    this.emergencyNotes = '',
    this.photoPath,
  });

  final String fullName;
  final String age;
  final String bloodGroup;
  final String heightCm;
  final String weightKg;
  final String emergencyNotes;
  final String? photoPath;

  ProfileDetails copyWith({
    String? fullName,
    String? age,
    String? bloodGroup,
    String? heightCm,
    String? weightKg,
    String? emergencyNotes,
    String? photoPath,
  }) =>
      ProfileDetails(
        fullName: fullName ?? this.fullName,
        age: age ?? this.age,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        emergencyNotes: emergencyNotes ?? this.emergencyNotes,
        photoPath: photoPath ?? this.photoPath,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fullName': fullName,
        'age': age,
        'bloodGroup': bloodGroup,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'emergencyNotes': emergencyNotes,
        'photoPath': photoPath,
      };

  factory ProfileDetails.fromJson(Map<String, dynamic> json) => ProfileDetails(
        fullName: json['fullName'] as String? ?? '',
        age: json['age'] as String? ?? '',
        bloodGroup: json['bloodGroup'] as String? ?? 'Unknown',
        heightCm: json['heightCm'] as String? ?? '',
        weightKg: json['weightKg'] as String? ?? '',
        emergencyNotes: json['emergencyNotes'] as String? ?? '',
        photoPath: json['photoPath'] as String?,
      );

  @override
  List<Object?> get props => <Object?>[
        fullName,
        age,
        bloodGroup,
        heightCm,
        weightKg,
        emergencyNotes,
        photoPath,
      ];
}
