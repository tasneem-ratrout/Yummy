import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/custom_bottom_nav.dart';

class _UserStreakItem {
  final String name;
  final String imageUrl;
  final int streak;

  const _UserStreakItem({
    required this.name,
    required this.imageUrl,
    required this.streak,
  });

  factory _UserStreakItem.fromJson(Map<String, dynamic> json) {
    return _UserStreakItem(
      name: (json['name'] ?? 'User').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      streak: (json['streak_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final AuthService _authService = AuthService();

  List<_UserStreakItem> _users = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    final response = await _authService.getUsersStreaks();
    final usersRaw = response['users'] as List<dynamic>? ?? [];

    if (!mounted) return;
    setState(() {
      _users = usersRaw
          .map(
            (item) => _UserStreakItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      _isLoadingUsers = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 20, right: 16),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 108,
              child: _isLoadingUsers
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.navy,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      scrollDirection: Axis.horizontal,
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return SizedBox(
                          width: 74,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.white,
                                backgroundImage: user.imageUrl.isNotEmpty
                                    ? NetworkImage(user.imageUrl)
                                    : null,
                                child: user.imageUrl.isEmpty
                                    ? const Icon(
                                        Icons.person_rounded,
                                        color: AppColors.blueGray,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 7),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 14,
                                    color: AppColors.fatOrange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${user.streak}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.deepBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Post Screen',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 4),
    );
  }
}
