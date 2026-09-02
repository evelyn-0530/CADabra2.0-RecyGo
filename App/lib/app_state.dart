import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'services/firestore_service.dart';

class Mission {
  final String id;
  final String title;
  final String type; // 'plastic', 'paper', 'general'
  final int target;
  final int pointsReward;
  int currentProgress;
  bool isClaimed;

  Mission({
    required this.id,
    required this.title,
    required this.type,
    required this.target,
    required this.pointsReward,
    this.currentProgress = 0,
    this.isClaimed = false,
  });
}

class AppState extends ChangeNotifier {
  int points = 0;
  int? _lastPointIncrease;
  int? get lastPointIncrease => _lastPointIncrease;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userPointsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _wasteEventsSubscription;
  final Set<String> _processedWasteEventIds = <String>{};

  String _connectedBin = '';
  String get connectedBin => _connectedBin;

  void setConnectedBin(String binName) {
    _connectedBin = binName;
    notifyListeners();
  }

  void updatePointsFromFirestore(int value) {
    if (points == value) return;

    if (value > points) {
      _lastPointIncrease = value - points;
    } else {
      _lastPointIncrease = null;
    }

    points = value;
    notifyListeners();
  }

  void clearPointIncrease() {
    _lastPointIncrease = null;
  }

  void listenToUserPoints(String userId) {
    final firestore = RecyGoFirestoreService();

    _userPointsSubscription?.cancel();

    _userPointsSubscription = firestore.users.doc(userId).snapshots().listen((
      snapshot,
    ) {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      final livePoints = (data?['points'] ?? 0) as int;
      print("🔄 Live update points received: $livePoints");
      updatePointsFromFirestore(livePoints);
    });
  }

  Future<void> loadUserPoints(String userId) async {
    print("🚀 Trying to load points for userId: '$userId'");

    if (userId.isEmpty) {
      print("❌ FAILED: userId is empty!");
      return;
    }

    try {
      final firestore = RecyGoFirestoreService();
      final doc = await firestore.users.doc(userId).get();

      if (doc.exists) {
        final data = doc.data();
        final loadedPoints = (data?['points'] ?? 0) as int;
        print("✅ Successfully read points from database: $loadedPoints");
        updatePointsFromFirestore(loadedPoints);
      } else {
        print("⚠️ Document with ID '$userId' not found in 'users' collection.");
      }
    } catch (e) {
      print("🚨 Error loading points: $e");
    }

    try {
      listenToUserPoints(userId);
      listenToWasteEvents(userId);
    } catch (listenerError) {
      print("🚨 Error starting listeners: $listenerError");
    }
  }

  void listenToWasteEvents(String userId) {
    final firestore = RecyGoFirestoreService();

    _wasteEventsSubscription?.cancel();
    _processedWasteEventIds.clear();

    bool isInitialLoad = true;

    _wasteEventsSubscription = firestore.wasteEvents.snapshots().listen(
      (snapshot) {
        print(
          "🟢 YOLO Triggered! Found ${snapshot.docs.length} total documents.",
        );

        if (isInitialLoad) {
          for (final event in snapshot.docs) {
            _processedWasteEventIds.add(event.id);
          }
          isInitialLoad = false;
          print("⏳Old history ignored, ready for new waste...");
          return;
        }

        var progressChanged = false;

        for (final event in snapshot.docs) {
          if (!_processedWasteEventIds.add(event.id)) continue;

          final data = event.data();
          final eventUserId = data['user_id']?.toString() ?? '';
          if (eventUserId != userId) {
            continue;
          }

          print("🔍 New data received for user $userId: $data");

          final wasteType = normalizeBinType(data['waste_type'] as String?);
          final itemCount = (data['item_count'] ?? 1) as int;

          if (wasteType.isEmpty || itemCount <= 0) continue;

          progressChanged =
              updateMissionProgressForWaste(
                wasteType: wasteType,
                itemCount: itemCount,
              ) ||
              progressChanged;
        }

        if (progressChanged) {
          print("✅Mission successfully updated!");
          notifyListeners();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Error listenToWasteEvents: $error');
      },
    );
  }

  @override
  void dispose() {
    _userPointsSubscription?.cancel();
    _wasteEventsSubscription?.cancel();
    super.dispose();
  }

  List<Mission> missions = [
    Mission(
      id: '1',
      title: 'Recycle Plastic Today',
      type: 'plastic',
      target: 5,
      pointsReward: 5,
    ),
    Mission(
      id: '2',
      title: 'Recycle Paper Today',
      type: 'paper',
      target: 5,
      pointsReward: 5,
    ),
    Mission(
      id: '3',
      title: 'Recycle Metal Today',
      type: 'metal',
      target: 5,
      pointsReward: 5,
    ),
    Mission(
      id: '4',
      title: 'Recycle General Waste Today',
      type: 'general',
      target: 5,
      pointsReward: 5,
    ),
    Mission(
      id: '5',
      title: 'Recycle Plastic Today',
      type: 'plastic',
      target: 20,
      pointsReward: 10,
    ),
    Mission(
      id: '6',
      title: 'Recycle Paper Today',
      type: 'paper',
      target: 20,
      pointsReward: 10,
    ),
    Mission(
      id: '7',
      title: 'Recycle Metal Today',
      type: 'metal',
      target: 20,
      pointsReward: 10,
    ),
    Mission(
      id: '8',
      title: 'Recycle General Waste Today',
      type: 'general',
      target: 20,
      pointsReward: 10,
    ),
  ];

  Mission get activeMission => missions[0];

  List<Mission> get queueMissions => missions.sublist(1);

  String normalizeBinType(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.contains('metal') ||
        normalized.contains('tin') ||
        normalized.contains('can'))
      return 'metal';
    if (normalized.contains('paper') ||
        normalized.contains('kertas') ||
        normalized.contains('cardboard'))
      return 'paper';
    if (normalized.contains('plastic') ||
        normalized.contains('plastik') ||
        normalized.contains('bottle'))
      return 'plastic';
    if (normalized.contains('general') || normalized.contains('mixed'))
      return 'general';
    return '';
  }

  String getFriendlyBinName(String? value) {
    final type = normalizeBinType(value);
    switch (type) {
      case 'metal':
        return 'Metal Bin';
      case 'paper':
        return 'Paper Bin';
      case 'plastic':
        return 'Plastic Bin';
      case 'general':
        return 'General Bin';
      default:
        return 'Bin 1';
    }
  }

  bool updateMissionProgressForWaste({
    required String wasteType,
    int itemCount = 1,
  }) {
    final normalizedType = normalizeBinType(wasteType);
    if (normalizedType.isEmpty || itemCount <= 0) return false;
    if (activeMission.type == normalizedType &&
        activeMission.currentProgress < activeMission.target) {
      final newProgress = activeMission.currentProgress + itemCount;
      activeMission.currentProgress = newProgress.clamp(
        0,
        activeMission.target,
      );
      return true;
    }

    return false;
  }

  void scanBinQR({String? binType}) {
    normalizeBinType(binType);
  }

  void claimActiveMission() {
    if (activeMission.currentProgress >= activeMission.target) {
      points += activeMission.pointsReward;

      final Mission completedMission = missions.removeAt(0);
      completedMission.currentProgress = 0;
      missions.add(completedMission);

      notifyListeners();
    }
  }

  bool canRedeemReward(int rewardCost) {
    return points >= rewardCost;
  }

  void redeemReward(int rewardCost) {
    if (canRedeemReward(rewardCost)) {
      points -= rewardCost;
      notifyListeners();
    }
  }
}
