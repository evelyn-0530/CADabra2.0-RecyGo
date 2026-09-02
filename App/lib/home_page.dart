import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_state.dart';
import 'splash_screen.dart';
import 'missions_page.dart';
import 'qr_scanner_screen.dart';
import 'services/firestore_service.dart';

class _PointsNotificationOverlay extends StatelessWidget {
  final int pointsGained;

  const _PointsNotificationOverlay({required this.pointsGained});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '🎉 You made our space cleaner today. Enjoy your +$pointsGained points!',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadUserPoints();
  }

  Future<void> _loadUserPoints() async {
    final appState = context.read<AppState>();
    await appState.loadUserPoints('test_user_001');
    appState.listenToUserPoints('test_user_001');
    appState.listenToWasteEvents('test_user_001');
  }

  void _showPointsNotification(int pointsGained) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) =>
          _PointsNotificationOverlay(pointsGained: pointsGained),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });

    final appState = context.read<AppState>();
    appState.clearPointIncrease();
  }

  Future<void> testRewardFlow(BuildContext context) async {
    final firestore = RecyGoFirestoreService();
    final appState = Provider.of<AppState>(context, listen: false);

    const userId = 'test_user_001';

    await firestore.awardPointsForAcceptedWaste(
      userId: userId,
      binId: 'BIN_001',
      binTarget: 'plastic',
      wasteType: 'plastic',
      arduinoCommand: 'PLASTIC',
      confidence: 0.91,
    );

    final userDoc = await firestore.users.doc(userId).get();
    final updatedPoints = userDoc.data()?['points'] ?? 0;

    appState.updatePointsFromFirestore(updatedPoints);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reward flow complete. Points updated to $updatedPoints.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _showRedeemDialog(
    BuildContext context,
    String rewardName,
    int rewardCost,
  ) async {
    final appState = Provider.of<AppState>(context, listen: false);

    if (!appState.canRedeemReward(rewardCost)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not enough points to redeem this reward.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Redeem voucher?'),
        content: Text(
          'Are you sure you want to redeem $rewardName for $rewardCost points?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      appState.redeemReward(rewardCost);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$rewardName redeemed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final activeMission = appState.activeMission;

    if (appState.lastPointIncrease != null && appState.lastPointIncrease! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPointsNotification(appState.lastPointIncrease!);
      });
    }
    bool isMissionComplete =
        activeMission.currentProgress >= activeMission.target;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'RecyGo',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black54),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SplashScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 10.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. MY POINTS
                const Text(
                  'My Points',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.amber,
                      child: Text(
                        '\$',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${appState.points}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep recycling, keep earning!',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),

                if (appState.connectedBin.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_tethering,
                          color: Colors.green,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connected to ${appState.connectedBin}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // BADGES & RANK
                const Text(
                  'Badges',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BadgeItem(
                      icon: Icons.eco,
                      label: 'Eco Starter',
                      color: Colors.blueAccent,
                    ),
                    _BadgeItem(
                      icon: Icons.autorenew,
                      label: 'Recycler',
                      color: Colors.green,
                    ),
                    _BadgeItem(
                      icon: Icons.star,
                      label: 'Green Hero',
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ACTIVE MISSION SECTION
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Mission',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // VIEW ALL
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MissionsPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'View all',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Card(
                  elevation: 0,
                  color: Colors.grey.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                activeMission.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '+${activeMission.pointsReward} pts  ',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                // CLAIM BUTTON (MISSION)
                                GestureDetector(
                                  onTap: () {
                                    if (isMissionComplete) {
                                      appState.claimActiveMission();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '🎉 Claim Successful! Points Added & New Mission Unlocked!',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMissionComplete
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Claim',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value:
                              (activeMission.currentProgress /
                                      activeMission.target)
                                  .clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          color: Colors.purple,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${activeMission.currentProgress}/${activeMission.target} Times',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // REWARD CARDS
                const Text(
                  'Reward Cards',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RewardCard(
                        title: 'Coffee\nRM5 Voucher',
                        pts: 100,
                        color: Colors.orange.shade200,
                        icon: Icons.local_cafe,
                        onTap: () =>
                            _showRedeemDialog(context, 'Coffee Voucher', 100),
                      ),
                      const SizedBox(width: 12),
                      _RewardCard(
                        title: 'Book\nRM5 Voucher',
                        pts: 100,
                        color: Colors.purple.shade200,
                        icon: Icons.menu_book,
                        onTap: () =>
                            _showRedeemDialog(context, 'Book Voucher', 100),
                      ),
                      const SizedBox(width: 12),
                      _RewardCard(
                        title: 'Transport\nRM5 Voucher',
                        pts: 100,
                        color: Colors.teal.shade200,
                        icon: Icons.directions_bus,
                        onTap: () => _showRedeemDialog(
                          context,
                          'Transport Voucher',
                          100,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),

          // SCAN BIN QR
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                label: const Text(
                  'Scan Bin QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QRScannerScreen(),
                    ),
                  );

                  if (result != null && context.mounted) {
                    final detectedType = appState.normalizeBinType(
                      result.toString(),
                    );
                    appState.scanBinQR(binType: detectedType);

                    final binName = appState.getFriendlyBinName(detectedType);
                    appState.setConnectedBin(binName);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Successfully connected to $binName'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _BadgeItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String title;
  final int pts;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _RewardCard({
    required this.title,
    required this.pts,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Colors.black87),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '($pts pts)',
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
