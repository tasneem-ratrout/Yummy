import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../core/providers/like_provider.dart';
import '../../core/providers/follow_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import 'personal_details_screen.dart';
import 'followers_following_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String? viewedUserId;
  final String? viewedUserName;
  final String? viewedUserImageUrl;

  const UserProfileScreen({
    super.key,
    this.viewedUserId,
    this.viewedUserName,
    this.viewedUserImageUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  int _followers = 0;
  int _following = 0;
  bool _isLoadingMyPosts = false;
  bool _isUploadingImage = false;
  File? _selectedImageFile;
  String? _lastLoadedForUser;
  final ImagePicker _picker = ImagePicker();

  final List<_ProfileMediaItem> _posts = [];
  bool _showGrid = false;
  bool _isFollowingViewedUser = false;
  String? _sessionUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sessionUserId = await _authService.getUserId();
    });
  }

  String _currentUserId() {
    final user = context.read<UserProvider>().user;
    return (user?['_id']?.toString() ??
            user?['id']?.toString() ??
            user?['userId']?.toString() ??
            _sessionUserId ??
            '')
        .trim();
  }

  String _currentUserName() {
    final user = context.read<UserProvider>().user;
    return (user?['name']?.toString() ?? '').trim();
  }

  bool get _isViewingOtherUser {
    final currentUserId = _currentUserId();
    final currentUserName = _currentUserName().toLowerCase();
    final userId = widget.viewedUserId?.trim() ?? '';
    final name = widget.viewedUserName?.trim() ?? '';

    if (userId.isNotEmpty &&
        currentUserId.isNotEmpty &&
        userId == currentUserId) {
      return false;
    }

    if (name.isNotEmpty &&
        currentUserName.isNotEmpty &&
        name.toLowerCase() == currentUserName) {
      return false;
    }

    return userId.isNotEmpty || name.isNotEmpty;
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    final y = value.year;
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$d/$m/$y  $h:$min';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<UserProvider>().user;
    final viewedUserId = (widget.viewedUserId ?? '').trim();
    final viewedName = (widget.viewedUserName ?? '').trim();
    if (viewedUserId.isNotEmpty || viewedName.isNotEmpty) {
      final identityKey = viewedUserId.isNotEmpty
          ? 'id:$viewedUserId'
          : 'name:$viewedName';
      if (_lastLoadedForUser != identityKey) {
        _lastLoadedForUser = identityKey;
        _loadMyPosts(userId: viewedUserId, fullName: viewedName);
        _loadFollowStats(viewedUserId);
      }
      return;
    }

    // Prefer same resolution as the rest of the screen (handles `id` from `/auth/me`).
    final userId = _currentUserId();
    final fullName = (user?['name']?.toString() ?? '').trim();
    final identityKey = userId.isNotEmpty
        ? 'id:$userId'
        : (fullName.isNotEmpty ? 'name:$fullName' : '');

    if (identityKey.isNotEmpty && _lastLoadedForUser != identityKey) {
      _lastLoadedForUser = identityKey;
      _loadMyPosts(userId: userId, fullName: fullName);
      _loadFollowStats(userId);
      try {
        context.read<LikeProvider>().addListener(_syncLikesFromProvider);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    try {
      context.read<LikeProvider>().removeListener(_syncLikesFromProvider);
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadFollowStats(String userId) async {
    if (userId.isEmpty) {
      print('❌ _loadFollowStats: userId is empty');
      return;
    }
    if (!mounted) return;

    print('📊 Loading follow stats for userId: $userId');
    final followProvider = context.read<FollowProvider>();

    try {
      await followProvider.fetchUserStats(userId: userId);
      print('✅ fetchUserStats completed');
    } catch (e) {
      print('❌ Error fetching user stats: $e');
    }

    try {
      await followProvider.checkFollowStatus(targetUserId: userId);
      print('✅ checkFollowStatus completed');
    } catch (e) {
      print('❌ Error checking follow status: $e');
    }

    if (!mounted) return;
    final followers = followProvider.getFollowerCount(userId);
    final following = followProvider.getFollowingCount(userId);
    final isFollowing = followProvider.isFollowing(userId);

    print(
      '📈 Stats updated: followers=$followers, following=$following, isFollowing=$isFollowing',
    );

    setState(() {
      _followers = followers;
      _following = following;
      _isFollowingViewedUser = isFollowing;
    });
  }

  Future<void> _refreshProfile() async {
    if (!mounted) return;

    final userProvider = context.read<UserProvider>();

    if (!_isViewingOtherUser) {
      await userProvider.fetchUser();
    }

    final user = userProvider.user;
    final targetUserId = _isViewingOtherUser
        ? (widget.viewedUserId ?? '').trim()
        : (user?['_id']?.toString() ??
                  user?['id']?.toString() ??
                  user?['userId']?.toString() ??
                  _sessionUserId ??
                  '')
              .trim();
    final targetUserName = _isViewingOtherUser
        ? (widget.viewedUserName ?? '').trim()
        : (user?['name']?.toString() ?? '').trim();

    if (!mounted) return;

    if (targetUserId.isNotEmpty || targetUserName.isNotEmpty) {
      await _loadMyPosts(userId: targetUserId, fullName: targetUserName);
    }

    if (targetUserId.isNotEmpty) {
      await _loadFollowStats(targetUserId);
    }
  }

  Future<void> _loadMyPosts({
    required String userId,
    required String fullName,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoadingMyPosts = true;
    });

    final response = await _authService.getPosts();
    final postsRaw = response['posts'] as List<dynamic>? ?? [];

    final normalizedName = fullName.toLowerCase();
    final normalizedUserId = userId.toLowerCase();
    final myPosts = postsRaw
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((post) {
          final postAuthorId =
              (post['authorId']?.toString().trim().toLowerCase() ?? '');
          if (normalizedUserId.isNotEmpty && postAuthorId.isNotEmpty) {
            return postAuthorId == normalizedUserId;
          }

          // Fallback for old posts that don't have authorId yet.
          return (post['authorName']?.toString().trim().toLowerCase() ?? '') ==
              normalizedName;
        })
        .map((post) {
          final commentsRaw = (post['comments'] as List<dynamic>? ?? []);
          final comments = commentsRaw
              .map((item) => Map<String, dynamic>.from(item as Map))
              .map(
                (c) => _ProfileComment(
                  authorName: c['authorName']?.toString() ?? 'User',
                  authorImageUrl: _resolveImageUrl(c['authorImageUrl']),
                  text: c['text']?.toString() ?? '',
                  createdAt:
                      DateTime.tryParse(c['createdAt']?.toString() ?? '') ??
                      DateTime.now(),
                ),
              )
              .toList();

          return _ProfileMediaItem(
            id:
                post['_id']?.toString() ??
                DateTime.now().microsecondsSinceEpoch.toString(),
            imageUrl: _resolveImageUrl(post['imagePath']) ?? '',
            caption: post['text']?.toString() ?? '',
            likeCount: (post['likedByUsers'] as List<dynamic>?)?.length ?? 0,
            likes:
                (post['likedByUsers'] as List<dynamic>?)
                    ?.map(
                      (item) => _LikeItem(
                        id: item.toString(),
                        name: 'User',
                        imageUrl: null,
                      ),
                    )
                    .toList() ??
                <_LikeItem>[],
            likedByUsers:
                (post['likedByUsers'] as List<dynamic>?)
                    ?.map((item) => item.toString())
                    .toSet() ??
                <String>{},
            likedByDetails: const [],
            comments: comments,
            publishedAt:
                DateTime.tryParse(post['publishedAt']?.toString() ?? '') ??
                DateTime.now(),
            isVideo: false,
            calories: (post['calories'] as num?)?.toDouble(),
            fat: (post['fat'] as num?)?.toDouble(),
            carbs: (post['carbs'] as num?)?.toDouble(),
            protein: (post['protein'] as num?)?.toDouble(),
          );
        })
        // Include posts even if they don't have an image; we'll show a
        // profile-only placeholder for those without images.
        .toList();

    if (!mounted) return;
    setState(() {
      _posts
        ..clear()
        ..addAll(myPosts);
      _isLoadingMyPosts = false;
    });
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return '${parts.first.characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }

  String? _resolveImageUrl(dynamic value) {
    final raw = (value?.toString() ?? '').trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    final baseUri = Uri.tryParse(AppConfig.baseUrl);
    if (baseUri == null) return raw;

    final authority = baseUri.hasPort
        ? '${baseUri.host}:${baseUri.port}'
        : baseUri.host;
    final origin = '${baseUri.scheme}://$authority';

    if (raw.startsWith('/')) {
      return '$origin$raw';
    }

    return '$origin/$raw';
  }

  String? _extractUserImageUrl(Map<String, dynamic>? user) {
    final profile = user?['profile'] as Map<String, dynamic>?;
    final rawImageValue =
        profile?['image_url'] ??
        profile?['image'] ??
        profile?['imageUrl'] ??
        user?['image_url'] ??
        user?['image'] ??
        user?['imageUrl'];

    return _resolveImageUrl(rawImageValue);
  }

  List<String> _listFromDynamic(dynamic value) {
    if (value is! List) return [];
    return value.map((item) => item.toString()).toList();
  }

  int _intFromDynamic(dynamic value, {required int fallback}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _doubleFromDynamic(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _showImageSourceSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choose Profile Picture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _imageOption(
                        icon: Icons.photo_library_rounded,
                        title: 'Gallery',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _imageOption(
                        icon: Icons.camera_alt_rounded,
                        title: 'Camera',
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (pickedFile == null) return;

      if (!mounted) return;

      final imageFile = File(pickedFile.path);
      setState(() {
        _selectedImageFile = imageFile;
      });

      await _uploadProfileImage(imageFile);
    } catch (_) {
      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not pick image')));
      }
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    final profile = user['profile'] as Map<String, dynamic>? ?? {};
    final height = profile['height'] as Map<String, dynamic>? ?? {};
    final weight = profile['weight'] as Map<String, dynamic>? ?? {};

    setState(() {
      _isUploadingImage = true;
    });

    final response = await userProvider.saveProfile(
      name: (user['name']?.toString() ?? '').trim(),
      email: user['email']?.toString(),
      imageFile: imageFile,
      goal: profile['goal']?.toString() ?? 'stay_healthy',
      gender: profile['gender']?.toString() ?? 'male',
      dateOfBirth:
          profile['date_of_birth']?.toString() ??
          DateTime(2000, 1, 1).toIso8601String(),
      heightValue: _intFromDynamic(height['value'], fallback: 170),
      heightUnit: height['unit']?.toString() ?? 'cm',
      weightValue: _doubleFromDynamic(weight['value'], fallback: 70),
      weightUnit: weight['unit']?.toString() ?? 'kg',
      activityLevel: profile['activity_level']?.toString() ?? 'sedentary',
      allergies: _listFromDynamic(profile['allergies']),
      medicalConditions: _listFromDynamic(profile['medical_conditions']),
    );

    if (!mounted) return;

    setState(() {
      _isUploadingImage = false;
    });

    if (!mounted) return;

    if (response['error'] == true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ?? 'Failed to update image',
            ),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile image updated')));
    }
  }

  Widget _imageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDFE8F3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: AppColors.deepBlue),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.deepBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final fullName =
        (widget.viewedUserName ?? user?['name']?.toString() ?? 'yummy user')
            .trim();
    final username = _isViewingOtherUser
        ? fullName.replaceAll(' ', '').toLowerCase()
        : (user?['email']?.toString() ?? 'yummy.user')
              .split('@')
              .first
              .replaceAll(' ', '')
              .toLowerCase();
    final bio = '';
    final userImageUrl =
        _resolveImageUrl(widget.viewedUserImageUrl) ??
        _extractUserImageUrl(user);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0.5,
              titleSpacing: 0,
              title: Row(
                children: [
                  const SizedBox(width: 2),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              actions: [
                if (_isViewingOtherUser)
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.blueGray,
                    ),
                    onSelected: (value) async {
                      if (value == 'hide') {
                        final hidden = await _hideViewedUser();
                        if (hidden && mounted) {
                          Navigator.pop(context, true);
                        }
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'hide',
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.orange),
                            SizedBox(width: 10),
                            Text('Hide User'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            SliverToBoxAdapter(
              child: _buildHeader(
                context: context,
                fullName: fullName,
                bio: bio,
                avatarUrl: userImageUrl,
              ),
            ),
            SliverToBoxAdapter(child: _buildViewToggle()),
            if (_isLoadingMyPosts)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.deepBlue),
                ),
              )
            else if (_posts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'No posts yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8F8F8F),
                    ),
                  ),
                ),
              )
            else
              _showGrid
                  ? SliverPadding(
                      padding: const EdgeInsets.only(top: 1),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 1,
                              mainAxisSpacing: 1,
                              childAspectRatio: 1,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = _posts[index];
                          return _buildPostTile(item);
                        }, childCount: _posts.length),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = _posts[index];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: _buildPostListItem(
                            item,
                            userName: fullName,
                            userImageUrl: userImageUrl,
                          ),
                        );
                      }, childCount: _posts.length),
                    ),
          ],
        ),
      ),
    );
  }

  Future<bool> _hideViewedUser() async {
    final viewedUserId = (widget.viewedUserId ?? '').trim();
    final viewedUserName = (widget.viewedUserName ?? 'User').trim();
    final viewedUserImageUrl = (widget.viewedUserImageUrl ?? '').trim();

    if (viewedUserId.isEmpty) return false;

    await _authService.hideUser(
      userId: viewedUserId,
      name: viewedUserName,
      imageUrl: viewedUserImageUrl,
    );
    return true;
  }

  Widget _buildHeader({
    required BuildContext context,
    required String fullName,
    required String bio,
    required String? avatarUrl,
  }) {
    final avatarProvider = _selectedImageFile != null
        ? FileImage(_selectedImageFile!) as ImageProvider
        : (avatarUrl != null ? NetworkImage(avatarUrl) : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _isViewingOtherUser ? null : _showImageSourceSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 43,
                      backgroundColor: const Color(0xFFEFEFEF),
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? Text(
                              _getInitials(fullName),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepBlue,
                              ),
                            )
                          : null,
                    ),
                    if (!_isViewingOtherUser)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: GestureDetector(
                          onTap: _showImageSourceSheet,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.deepBlue,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _isUploadingImage
                                ? const Padding(
                                    padding: EdgeInsets.all(7),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      label: 'Posts',
                      value: _formatCount(_posts.length),
                    ),
                    GestureDetector(
                      onTap: !_isViewingOtherUser && _currentUserId().isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowersFollowingScreen(
                                    userId: _currentUserId(),
                                    userName: _currentUserName().isNotEmpty
                                        ? _currentUserName()
                                        : 'User',
                                    initialIndex: 0,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: _StatItem(
                        label: 'Followers',
                        value: _formatCount(_followers),
                      ),
                    ),
                    GestureDetector(
                      onTap: !_isViewingOtherUser && _currentUserId().isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FollowersFollowingScreen(
                                    userId: _currentUserId(),
                                    userName: _currentUserName().isNotEmpty
                                        ? _currentUserName()
                                        : 'User',
                                    initialIndex: 1,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: _StatItem(
                        label: 'Following',
                        value: _formatCount(_following),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            fullName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bio,
            style: const TextStyle(
              fontSize: 13,
              height: 1.25,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: _isViewingOtherUser
                      ? FilledButton(
                          onPressed: () async {
                            print('🔍 Follow button pressed');
                            print('👤 viewedUserId: ${widget.viewedUserId}');
                            print(
                              '📛 viewedUserName: ${widget.viewedUserName}',
                            );
                            print(
                              '🔍 isViewingOtherUser: $_isViewingOtherUser',
                            );

                            if (widget.viewedUserId == null ||
                                widget.viewedUserId!.isEmpty) {
                              print('❌ viewedUserId is null or empty!');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('User ID not found'),
                                ),
                              );
                              return;
                            }

                            try {
                              final followProvider = context
                                  .read<FollowProvider>();
                              print(
                                '👉 Calling toggleFollow with: ${widget.viewedUserId}',
                              );

                              final response = await followProvider
                                  .toggleFollow(
                                    targetUserId: widget.viewedUserId!,
                                  );

                              print('✅ toggleFollow completed');

                              if (response['error'] == true) {
                                throw Exception(
                                  response['message'] ??
                                      'Follow request failed',
                                );
                              }

                              await _refreshProfile();
                            } catch (e) {
                              print('❌ Error: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: _isFollowingViewedUser
                                ? AppColors.blueGray
                                : AppColors.deepBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            _isFollowingViewedUser ? 'Unfollow' : 'Follow',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PersonalDetailsScreen(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFDCDCDC)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPostTile(_ProfileMediaItem item) {
    return InkWell(
      onTap: () => _showPostDetailsSheet(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.imageUrl.isNotEmpty)
            Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: Colors.grey.shade300,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                );
              },
            )
          else
            // Profile-only placeholder for posts without an image.
            Image.asset('assets/icons/noimage.png', fit: BoxFit.cover),
          if (item.isVideo)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.play_arrow_rounded,
                size: 17,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.transparent),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => setState(() => _showGrid = true),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 22,
                      color: _showGrid ? AppColors.navy : AppColors.blueGray,
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: _showGrid ? 50 : 0,
                      decoration: BoxDecoration(
                        color: _showGrid ? AppColors.navy : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
              GestureDetector(
                onTap: () => setState(() => _showGrid = false),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.view_agenda_rounded,
                      size: 22,
                      color: !_showGrid ? AppColors.navy : AppColors.blueGray,
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 3,
                      width: !_showGrid ? 50 : 0,
                      decoration: BoxDecoration(
                        color: !_showGrid ? AppColors.navy : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postMetricChip({required String label, required double? value}) {
    if (value == null) return const SizedBox.shrink();
    Color bg = const Color(0xFFF2F7FE);
    Color fg = AppColors.deepBlue;

    final key = label.toLowerCase();
    if (key.startsWith('cal')) {
      bg = AppColors.caloriesBg;
      fg = AppColors.caloriesPurple;
    } else if (key.startsWith('prot') || key == 'protein') {
      bg = AppColors.proteinBg;
      fg = AppColors.proteinBlue;
    } else if (key.startsWith('fat')) {
      bg = AppColors.fatBg;
      fg = AppColors.fatOrange;
    } else if (key.startsWith('carb')) {
      bg = AppColors.carbsBg;
      fg = AppColors.carbsGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildPostListItem(
    _ProfileMediaItem item, {
    required String userName,
    required String? userImageUrl,
  }) {
    final likesCount = item.likeCount;
    final currentUserId = _getCurrentUserId();
    final userInitial = _getInitials(userName).substring(0, 1);
    final userAvatarProvider = userImageUrl != null && userImageUrl.isNotEmpty
        ? NetworkImage(userImageUrl) as ImageProvider
        : null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDEE9F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.babyBlueLight,
                  backgroundImage: userAvatarProvider,
                  child: userAvatarProvider == null
                      ? Text(
                          userInitial,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppColors.deepBlue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      Text(
                        _formatDate(item.publishedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.blueGray,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isViewingOtherUser)
                  IconButton(
                    onPressed: () => _showPostMenu(context, item),
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppColors.blueGray,
                      size: 20,
                    ),
                  )
                else
                  const SizedBox(width: 40),
              ],
            ),
          ),
          if (item.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                item.caption,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  color: Color(0xFF1F2C3B),
                ),
              ),
            ),
          if (item.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Image.network(
                item.imageUrl,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _postMetricChip(label: 'Cal', value: item.calories),
                _postMetricChip(label: 'Fat', value: item.fat),
                _postMetricChip(label: 'Carb', value: item.carbs),
                _postMetricChip(label: 'Protein', value: item.protein),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: Row(
              children: [
                Text(
                  '$likesCount likes',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _showCommentsSheet(item),
                  child: Text(
                    '${item.comments.length} comments',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _togglePostLike(item),
                  icon: Icon(
                    item.likedByUsers.contains(currentUserId)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 18,
                    color: item.likedByUsers.contains(currentUserId)
                        ? Colors.red
                        : AppColors.deepBlue,
                  ),
                  label: const Text('Like'),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showCommentsSheet(item),
                  icon: const Icon(
                    Icons.mode_comment_outlined,
                    size: 18,
                    color: AppColors.deepBlue,
                  ),
                  label: const Text('Comment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUserActionsSheet(String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: AppColors.deepBlue,
                  ),
                  title: const Text('View Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to user profile
                    // For now just close
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: Colors.orange),
                  title: const Text('Hide User'),
                  onTap: () async {
                    Navigator.pop(context);
                    final viewedUserId = (widget.viewedUserId ?? '').trim();
                    final viewedUserName = (widget.viewedUserName ?? 'User')
                        .trim();
                    final viewedUserImageUrl = (widget.viewedUserImageUrl ?? '')
                        .trim();

                    if (viewedUserId.isEmpty) return;

                    await _authService.hideUser(
                      userId: viewedUserId,
                      name: viewedUserName,
                      imageUrl: viewedUserImageUrl,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCommentsSheet(_ProfileMediaItem post) {
    final controller = TextEditingController();

    Future<void> submitComment(
      BuildContext sheetContext,
      StateSetter refreshSheet,
    ) async {
      final commentText = controller.text.trim();
      if (commentText.isEmpty) return;

      final authorName = _getCurrentUserName();
      final authorImageUrl = _extractUserImageUrl(
        context.read<UserProvider>().user,
      );

      final resp = await _authService.addPostComment(
        postId: post.id,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        text: commentText,
      );

      if (resp['error'] == true) {
        if (!mounted) return;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add comment: ${resp['message']}'),
            ),
          );
        }
        return;
      }

      setState(() {
        post.comments.add(
          _ProfileComment(
            authorName: authorName,
            authorImageUrl: authorImageUrl,
            text: commentText,
            createdAt: DateTime.now(),
          ),
        );
      });

      refreshSheet(() {});
      controller.clear();
      FocusScope.of(sheetContext).unfocus();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 220,
                        child: post.comments.isEmpty
                            ? const Center(
                                child: Text(
                                  'No comments yet',
                                  style: TextStyle(
                                    color: AppColors.blueGray,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: post.comments.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 14),
                                itemBuilder: (_, index) {
                                  final comment = post.comments[index];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor:
                                            AppColors.babyBlueLight,
                                        backgroundImage:
                                            comment.authorImageUrl != null &&
                                                comment
                                                    .authorImageUrl!
                                                    .isNotEmpty
                                            ? NetworkImage(
                                                comment.authorImageUrl!,
                                              )
                                            : null,
                                        child:
                                            (comment.authorImageUrl == null ||
                                                comment.authorImageUrl!.isEmpty)
                                            ? Text(
                                                _getInitials(
                                                  comment.authorName,
                                                ).substring(0, 1),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.deepBlue,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    comment.authorName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${comment.createdAt.hour.toString().padLeft(2, '0')}:${comment.createdAt.minute.toString().padLeft(2, '0')}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.blueGray,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(comment.text),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controller,
                        maxLines: 2,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) =>
                            submitComment(sheetContext, setSheetState),
                        decoration: InputDecoration(
                          hintText: 'Write a comment',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                submitComment(sheetContext, setSheetState),
                            icon: const Icon(
                              Icons.send_rounded,
                              color: AppColors.deepBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPostMenu(BuildContext context, _ProfileMediaItem post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                if (!_isViewingOtherUser) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.edit_rounded,
                      color: AppColors.deepBlue,
                    ),
                    title: const Text('Edit Post'),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditPostSheet(post);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete Post',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deletePost(post);
                    },
                  ),
                ] else ...[
                  const ListTile(
                    leading: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.blueGray,
                    ),
                    title: Text('This post belongs to another profile'),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditPostSheet(_ProfileMediaItem post) {
    final captionController = TextEditingController(text: post.caption);
    final caloriesController = TextEditingController(
      text: post.calories != null ? post.calories.toString() : '',
    );
    final fatController = TextEditingController(
      text: post.fat != null ? post.fat.toString() : '',
    );
    final carbsController = TextEditingController(
      text: post.carbs != null ? post.carbs.toString() : '',
    );
    final proteinController = TextEditingController(
      text: post.protein != null ? post.protein.toString() : '',
    );
    File? selectedImageFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Edit Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Image editing section
                      const Text(
                        'Post Image',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () async {
                          final pickedFile = await _picker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 90,
                          );
                          if (pickedFile != null) {
                            setSheetState(() {
                              selectedImageFile = File(pickedFile.path);
                            });
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDEE9F6)),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (selectedImageFile != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    selectedImageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else if (post.imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    post.imageUrl,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Container(
                                  color: const Color(0xFFF7FAFE),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 32,
                                        color: AppColors.deepBlue,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to change image',
                                        style: TextStyle(
                                          color: AppColors.deepBlue,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (selectedImageFile != null)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setSheetState(() {
                                        selectedImageFile = null;
                                      });
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: captionController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          hintText: 'Edit caption',
                          filled: true,
                          fillColor: const Color(0xFFF7FAFE),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nutrition Info',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _nutritionFieldEdit(
                              'Calories',
                              caloriesController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _nutritionFieldEdit('Fat', fatController),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _nutritionFieldEdit(
                              'Carbs',
                              carbsController,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _nutritionFieldEdit(
                              'Protein',
                              proteinController,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.deepBlue,
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: AppColors.deepBlue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _savePostChanges(
                                sheetContext,
                                post,
                                captionController.text,
                                caloriesController.text,
                                fatController.text,
                                carbsController.text,
                                proteinController.text,
                                selectedImageFile,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.deepBlue,
                              ),
                              child: const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _nutritionFieldEdit(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        isDense: true,
        hintText: label,
        hintStyle: const TextStyle(fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8FBFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _savePostChanges(
    BuildContext sheetContext,
    _ProfileMediaItem post,
    String caption,
    String calories,
    String fat,
    String carbs,
    String protein,
    File? newImageFile,
  ) async {
    final caloriesValue = double.tryParse(calories);
    final fatValue = double.tryParse(fat);
    final carbsValue = double.tryParse(carbs);
    final proteinValue = double.tryParse(protein);

    if (caption.isEmpty) {
      return;
    }

    // Determine the image URL for the updated post
    String updatedImageUrl = post.imageUrl;
    if (newImageFile != null) {
      // If a new image was selected, we'll use local file path for now
      // TODO: Upload image to backend and get URL
      updatedImageUrl = newImageFile.path;
    }

    // Update locally
    final updatedPost = _ProfileMediaItem(
      id: post.id,
      imageUrl: updatedImageUrl,
      caption: caption,
      likes: post.likes,
      likedByUsers: post.likedByUsers,
      comments: post.comments,
      publishedAt: post.publishedAt,
      isVideo: post.isVideo,
      calories: caloriesValue,
      fat: fatValue,
      carbs: carbsValue,
      protein: proteinValue,
    );

    if (!mounted) return;

    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        _posts[index] = updatedPost;
      }
    });

    Navigator.pop(sheetContext);
  }

  Future<void> _deletePost(_ProfileMediaItem post) async {
    final response = await _authService.deletePost(postId: post.id);
    if (!mounted) return;

    if (response['error'] == true) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _posts.removeWhere((item) => item.id == post.id);
    });
  }

  String _getCurrentUserId() {
    final user = context.read<UserProvider>().user;
    return (user?['_id']?.toString() ??
            user?['userId']?.toString() ??
            _sessionUserId ??
            '')
        .trim();
  }

  String _getCurrentUserName() {
    final user = context.read<UserProvider>().user;
    return (user?['name']?.toString() ?? 'User').trim();
  }

  Future<void> _togglePostLike(_ProfileMediaItem post) async {
    final userId = _getCurrentUserId();
    final userName = _getCurrentUserName();
    if (userId.isEmpty || userName.isEmpty) return;
    // Optimistic UI update: toggle locally first
    final prevLiked = Set<String>.from(post.likedByUsers);
    final prevLikesList = List<_LikeItem>.from(post.likes);
    final prevCount = post.likeCount;

    final hadLiked = post.likedByUsers.contains(userId);
    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        if (hadLiked) {
          _posts[index].likedByUsers.remove(userId);
          _posts[index].likes.removeWhere((l) => l.id == userId);
          _posts[index].likeCount = (_posts[index].likeCount - 1).clamp(
            0,
            1 << 30,
          );
        } else {
          _posts[index].likedByUsers.add(userId);
          _posts[index].likes.add(
            _LikeItem(id: userId, name: userName, imageUrl: null),
          );
          _posts[index].likeCount = _posts[index].likeCount + 1;
        }
      }
    });

    final success = await context.read<LikeProvider>().toggleLike(
      postId: post.id,
      userId: userId,
    );

    if (!success) {
      // revert optimistic update
      if (!mounted) return;
      setState(() {
        final index = _posts.indexWhere((item) => item.id == post.id);
        if (index != -1) {
          _posts[index].likedByUsers
            ..clear()
            ..addAll(prevLiked);
          _posts[index].likes
            ..clear()
            ..addAll(prevLikesList);
          _posts[index].likeCount = prevCount;
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update like')));
      }
      return;
    }

    // On success, sync final state from provider
    final lp = context.read<LikeProvider>();
    final liked = lp.likedByUsersFor(post.id);
    final count = lp.likeCountFor(post.id);
    if (!mounted) return;
    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        _posts[index].likedByUsers
          ..clear()
          ..addAll(liked);
        _posts[index].likes
          ..clear()
          ..addAll(
            liked
                .map((id) => _LikeItem(id: id, name: 'User', imageUrl: null))
                .toList(),
          );
        _posts[index].likeCount = count;
      }
    });
  }

  void _syncLikesFromProvider() {
    final lp = context.read<LikeProvider>();
    final userId = _getCurrentUserId();
    bool changed = false;
    for (var i = 0; i < _posts.length; i++) {
      final p = _posts[i];
      if (!lp.hasDataFor(p.id)) continue;
      final liked = lp.likedByUsersFor(p.id);
      final count = lp.likeCountFor(p.id);
      if (!setEquals(p.likedByUsers, liked) || p.likeCount != count) {
        p.likedByUsers
          ..clear()
          ..addAll(liked);
        p.likes
          ..clear()
          ..addAll(
            liked
                .map((id) => _LikeItem(id: id, name: 'User', imageUrl: null))
                .toList(),
          );
        p.likeCount = count;
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  void _showAddCommentSheet(_ProfileMediaItem post) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Comment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepBlue,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: commentController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your comment...',
                      filled: true,
                      fillColor: const Color(0xFFF7FAFE),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.deepBlue),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.deepBlue),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _addPostComment(
                            sheetContext,
                            post,
                            commentController.text,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.deepBlue,
                          ),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPostComment(
    BuildContext sheetContext,
    _ProfileMediaItem post,
    String commentText,
  ) async {
    final text = commentText.trim();
    if (text.isEmpty) return;

    final userName = _getCurrentUserName();
    final userImageUrl = _extractUserImageUrl(
      context.read<UserProvider>().user,
    );

    // Optimistically add comment locally while saving to backend
    setState(() {
      final index = _posts.indexWhere((item) => item.id == post.id);
      if (index != -1) {
        _posts[index].comments.add(
          _ProfileComment(
            authorName: userName,
            authorImageUrl: userImageUrl,
            text: text,
            createdAt: DateTime.now(),
          ),
        );
      }
    });

    Navigator.pop(sheetContext);

    // Save to backend
    final resp = await _authService.addPostComment(
      postId: post.id,
      authorName: userName,
      authorImageUrl: userImageUrl,
      text: text,
    );

    if (resp['error'] == true) {
      // remove optimistic comment if save failed
      if (!mounted) return;
      setState(() {
        final index = _posts.indexWhere((item) => item.id == post.id);
        if (index != -1) {
          final comments = _posts[index].comments;
          if (comments.isNotEmpty && comments.last.text == text) {
            comments.removeLast();
          }
        }
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add comment: ${resp['message'] ?? ''}'),
          ),
        );
      }
      return;
    }
  }

  void _showPostDetailsSheet(_ProfileMediaItem post) {
    final currentUser = context.read<UserProvider>().user;
    final userName = _getCurrentUserName();
    final userImageUrl = _extractUserImageUrl(currentUser);
    final userInitial = _getInitials(userName).substring(0, 1);
    final userAvatarProvider = userImageUrl != null && userImageUrl.isNotEmpty
        ? NetworkImage(userImageUrl) as ImageProvider
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Post Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const Spacer(),
                      if (!_isViewingOtherUser)
                        IconButton(
                          onPressed: () => _deletePost(post),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.babyBlueLight,
                        backgroundImage: userAvatarProvider,
                        child: userAvatarProvider == null
                            ? Text(
                                userInitial,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.deepBlue,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatDate(post.publishedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.blueGray,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (post.caption.trim().isNotEmpty) ...[
                    Text(post.caption),
                    const SizedBox(height: 10),
                  ],
                  if (post.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(post.imageUrl, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _showCommentsSheet(post),
                    child: Text('${post.comments.length} comments'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.black)),
      ],
    );
  }
}

class _ProfileMediaItem {
  final String id;
  final String imageUrl;
  final String caption;
  final List<_LikeItem> likes;
  final Set<String> likedByUsers;
  final List<_LikeItem> likedByDetails;
  int likeCount;
  final List<_ProfileComment> comments;
  final DateTime publishedAt;
  final bool isVideo;
  final double? calories;
  final double? fat;
  final double? carbs;
  final double? protein;

  _ProfileMediaItem({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    Set<String>? likedByUsers,
    List<_LikeItem>? likedByDetails,
    this.likeCount = 0,
    required this.comments,
    required this.publishedAt,
    required this.isVideo,
    this.calories,
    this.fat,
    this.carbs,
    this.protein,
  }) : likedByUsers = likedByUsers ?? <String>{},
       likedByDetails = likedByDetails ?? <_LikeItem>[];
}

class _ProfileComment {
  final String authorName;
  final String? authorImageUrl;
  final String text;
  final DateTime createdAt;

  const _ProfileComment({
    required this.authorName,
    required this.text,
    this.authorImageUrl,
    required this.createdAt,
  });
}

class _LikeItem {
  final String id;
  final String name;
  final String? imageUrl;

  _LikeItem({required this.id, required this.name, this.imageUrl});
}
