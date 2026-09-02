import 'package:cloud_firestore/cloud_firestore.dart';

class RecyGoFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get wasteEvents =>
      _db.collection('waste_events');

  CollectionReference<Map<String, dynamic>> get bins => _db.collection('bins');

  DocumentReference<Map<String, dynamic>> rewardRulesDoc() =>
      _db.collection('settings').doc('reward_rules');

  Future<void> saveUser({
    required String userId,
    required String email,
    int points = 0,
    int highestPoints = 0,
    int activeMissionProgress = 0,
    bool isMissionClaimed = false,
    int missionCount = 0,
    List<Map<String, dynamic>> missionsList = const [],
  }) async {
    await users.doc(userId).set({
      'user_id': userId,
      'email': email,
      'points': points,
      'highestPoints': highestPoints,
      'activeMissionProgress': activeMissionProgress,
      'isMissionClaimed': isMissionClaimed,
      'missionCount': missionCount,
      'missionsList': missionsList,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveWasteEvent({
    required String userId,
    required String binId,
    required String binTarget,
    required String wasteType,
    required String arduinoCommand,
    required double confidence,
    required int points,
    required String status,
    int itemCount = 1,
  }) async {
    await wasteEvents.add({
      'user_id': userId,
      'bin_id': binId,
      'bin_target': binTarget,
      'waste_type': wasteType,
      'arduino_command': arduinoCommand,
      'confidence': confidence,
      'points': points,
      'item_count': itemCount,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> awardPointsForAcceptedWaste({
    required String userId,
    required String binId,
    required String binTarget,
    required String wasteType,
    required String arduinoCommand,
    required double confidence,
    int itemCount = 1,
  }) async {
    final rewardPoints = await getRewardPointsForType(wasteType);
    final earnedPoints = rewardPoints * itemCount;

    final userRef = users.doc(userId);

    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);

      int currentPoints = 0;
      int currentHighest = 0;

      if (userSnap.exists) {
        final data = userSnap.data();
        currentPoints = (data?['points'] ?? 0) as int;
        currentHighest = (data?['highestPoints'] ?? 0) as int;
      }

      final newPoints = currentPoints + earnedPoints;
      final newHighest = newPoints > currentHighest
          ? newPoints
          : currentHighest;

      if (userSnap.exists) {
        transaction.update(userRef, {
          'points': newPoints,
          'highestPoints': newHighest,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(userRef, {
          'user_id': userId,
          'email': '',
          'points': newPoints,
          'highestPoints': newHighest,
          'activeMissionProgress': 0,
          'isMissionClaimed': false,
          'missionCount': 0,
          'missionsList': [],
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });

    await saveWasteEvent(
      userId: userId,
      binId: binId,
      binTarget: binTarget,
      wasteType: wasteType,
      arduinoCommand: arduinoCommand,
      confidence: confidence,
      points: earnedPoints,
      status: 'accepted',
      itemCount: itemCount,
    );
  }

  Future<int> getRewardPointsForType(String wasteType) async {
    final doc = await rewardRulesDoc().get();

    if (!doc.exists) return 1;

    final data = doc.data();
    return (data?[wasteType.toLowerCase()] ?? 1) as int;
  }
}
