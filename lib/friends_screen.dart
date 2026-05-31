import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_strings.dart';

// Bir profilin "temiz gün" sayısını (quit_date'ten bugüne) hesaplar.
// Tüm alışkanlıklar için ortak bir rekabet metriğidir.
int streakDaysOf(Map<String, dynamic> profile) {
  final q = profile['quit_date'];
  if (q == null) return 0;
  final quit = DateTime.tryParse(q.toString());
  if (quit == null) return 0;
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(quit.year, quit.month, quit.day))
      .inDays;
  return days < 0 ? 0 : days;
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  int _pendingRequestCount = 0;

  // Leaderboard: kendisi + arkadaşları, streak'e göre sıralı
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
    _fetchPendingCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPendingCount() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    final result = await supabase
        .from('friendships')
        .select('id')
        .eq('addressee_id', myId)
        .eq('status', 'PENDING');
    if (mounted) setState(() => _pendingRequestCount = result.length);
  }

  Future<void> _fetchLeaderboard() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    // Kabul edilmiş arkadaşlıklar
    final friendships = await supabase
        .from('friendships')
        .select()
        .eq('status', 'ACCEPTED')
        .or('requester_id.eq.$myId,addressee_id.eq.$myId');

    final List<Map<String, dynamic>> list = [];

    // Kendi profilini ekle (sıralamada kendini gör)
    final me = await supabase
        .from('profiles')
        .select()
        .eq('id', myId)
        .maybeSingle();
    if (me != null) list.add({...me, '_isMe': true});

    // Arkadaş profillerini ekle
    for (var f in friendships) {
      final friendId =
          (f['requester_id'] == myId) ? f['addressee_id'] : f['requester_id'];
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', friendId)
          .maybeSingle();
      if (profile != null) {
        list.add({...profile, '_isMe': false, '_friendship_id': f['id']});
      }
    }

    // Streak'e (temiz gün) göre azalan sırada sırala
    list.sort((a, b) => streakDaysOf(b).compareTo(streakDaysOf(a)));

    if (!mounted) return;
    setState(() {
      _all = list;
      _filtered = list;
    });
  }

  Future<void> _unfriend(dynamic friendshipId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.removeFriend,
            style:
                TextStyle(color: context.appText, fontWeight: FontWeight.w800)),
        content: Text(AppStrings.removeFriendConfirm(username),
            style: TextStyle(color: context.appSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel,
                style: TextStyle(color: context.appSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.remove,
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await supabase.from('friendships').delete().eq('id', friendshipId);
    _fetchLeaderboard();
  }

  void _filter(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? _all
          : _all
              .where((f) => (f['username'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(query.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              _iconBtn(
                context,
                _isSearching ? Icons.close_rounded : Icons.search_rounded,
                () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _filter('');
                    }
                  });
                },
              ),
              const SizedBox(width: 10),
              if (_isSearching)
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    autofocus: true,
                    cursorColor: context.appAccent,
                    style: TextStyle(
                        color: context.appText, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: AppStrings.findFriend,
                      hintStyle: TextStyle(color: context.appSub),
                      border: InputBorder.none,
                    ),
                  ),
                )
              else ...[
                Text(
                  AppStrings.leaderboard,
                  style: TextStyle(
                      color: context.appText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Stack(
                  children: [
                    _iconBtn(
                      context,
                      Icons.notifications_none_rounded,
                      () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FriendRequestsScreen()))
                          .then((_) {
                        _fetchLeaderboard();
                        _fetchPendingCount();
                      }),
                    ),
                    if (_pendingRequestCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _pendingRequestCount > 9
                                  ? '9+'
                                  : '$_pendingRequestCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                _iconBtn(
                  context,
                  Icons.person_add_alt_1_rounded,
                  () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddFriendScreen()))
                      .then((_) => _fetchLeaderboard()),
                ),
              ],
            ],
          ),
        ),
        Divider(color: context.appBorder, height: 1),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 52, color: context.appSub),
                      const SizedBox(height: 12),
                      Text(AppStrings.noFriendsYet,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.appSub)),
                      const SizedBox(height: 4),
                      Text(AppStrings.addSomeoneToStart,
                          style: TextStyle(
                              fontSize: 13, color: context.appTextDim)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    // Sıra (rank) tüm liste içindeki gerçek konuma göre
                    final entry = _filtered[i];
                    final rank = _all.indexOf(entry) + 1;
                    return _leaderboardTile(context, entry, rank);
                  },
                ),
        ),
      ],
    );
  }

  Widget _leaderboardTile(
      BuildContext context, Map<String, dynamic> entry, int rank) {
    final bool isMe = entry['_isMe'] == true;
    final username = (entry['username'] ?? AppStrings.unknown).toString();
    final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';
    final avatarUrl = entry['avatar_url'] as String?;
    final streak = streakDaysOf(entry);
    final double totalSaved = (entry['total_saved'] ?? 0.0).toDouble();
    final isCigarette =
        (entry['habit'] ?? '').toString().toLowerCase().contains('cigarette');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: context.appAccent, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Rank rozeti
          SizedBox(
            width: 28,
            child: _rankBadge(context, rank),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 22,
            backgroundColor: context.appBorder,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(initials,
                    style: TextStyle(
                        color: context.appText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(isMe ? AppStrings.you : username,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isMe ? context.appAccent : context.appText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(AppStrings.dayStreakShort(streak),
                    style: TextStyle(color: context.appSub, fontSize: 12)),
                if (isCigarette) ...[
                  const SizedBox(height: 2),
                  Text(
                    AppStrings.savedAmount(
                        (totalSaved < 0 ? 0.0 : totalSaved).toStringAsFixed(2)),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.appAccent),
                  ),
                ],
              ],
            ),
          ),
          // Kendisi değilse arkadaşı çıkarma butonu
          if (!isMe && entry['_friendship_id'] != null)
            GestureDetector(
              onTap: () => _unfriend(entry['_friendship_id'], username),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_remove_rounded,
                    color: Colors.redAccent, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rankBadge(BuildContext context, int rank) {
    // İlk üç için renkli, diğerleri için sade numara
    Color color;
    switch (rank) {
      case 1:
        color = const Color(0xFFFFD700); // altın
        break;
      case 2:
        color = const Color(0xFFC0C0C0); // gümüş
        break;
      case 3:
        color = const Color(0xFFCD7F32); // bronz
        break;
      default:
        color = context.appSub;
    }
    return Text(
      '$rank',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color,
        fontSize: rank <= 3 ? 20 : 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: context.appCard,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: context.appText),
      ),
    );
  }
}

// ─── Friend Requests ──────────────────────────────────────────────────────────

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchRequests() async {
    final myId = supabase.auth.currentUser?.id;
    final friendships = await supabase
        .from('friendships')
        .select()
        .eq('addressee_id', myId ?? '')
        .eq('status', 'PENDING');
    List<Map<String, dynamic>> requests = [];
    for (var f in friendships) {
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', f['requester_id'])
          .maybeSingle();
      if (profile != null) {
        requests.add({
          'friendship_id': f['id'],
          'username': profile['username'],
          'habit': profile['habit'],
          'avatar_url': profile['avatar_url'],
        });
      }
    }
    return requests;
  }

  Future<void> _accept(dynamic id) async {
    await supabase
        .from('friendships')
        .update({'status': 'ACCEPTED'}).eq('id', id);
    setState(() {});
  }

  Future<void> _reject(dynamic id) async {
    await supabase.from('friendships').delete().eq('id', id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
        title: Text(AppStrings.friendRequests,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: context.appAccent));
          }
          final requests = snapshot.data;
          if (requests == null || requests.isEmpty) {
            return Center(
              child: Text(AppStrings.noPendingRequests,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.appSub)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final req = requests[i];
              final uname = (req['username'] ?? '?').toString();
              final initials = uname.isNotEmpty ? uname[0].toUpperCase() : '?';
              final avatarUrl = req['avatar_url'] as String?;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: context.appBorder,
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? Text(initials,
                              style: TextStyle(
                                  color: context.appText,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['username'] ?? AppStrings.unknown,
                              style: TextStyle(
                                  color: context.appText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              AppStrings.quittingHabit(
                                  req['habit'] ?? AppStrings.quittingDefault),
                              style: TextStyle(
                                  color: context.appSub, fontSize: 12)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        _actionBtn(context, Icons.check_rounded,
                            context.appAccent, () => _accept(req['friendship_id'])),
                        const SizedBox(width: 8),
                        _actionBtn(context, Icons.close_rounded,
                            Colors.redAccent, () => _reject(req['friendship_id'])),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _actionBtn(BuildContext context, IconData icon, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ─── Add Friend ───────────────────────────────────────────────────────────────

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final myId = supabase.auth.currentUser?.id;
    final users =
        await supabase.from('profiles').select().neq('id', myId ?? '');
    final friendships = await supabase
        .from('friendships')
        .select()
        .or('requester_id.eq.$myId,addressee_id.eq.$myId');

    List<Map<String, dynamic>> result = [];
    for (var user in users) {
      String status = 'NONE';
      for (var f in friendships) {
        if (f['requester_id'] == user['id'] ||
            f['addressee_id'] == user['id']) {
          status = f['status'];
          break;
        }
      }
      if (status == 'ACCEPTED') continue;
      result.add({...user, 'friendship_status': status});
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        iconTheme: IconThemeData(color: context.appText),
        title: Text(AppStrings.discoverPeople,
            style: TextStyle(
                color: context.appText,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: context.appAccent));
          }
          final users = snapshot.data;
          if (users == null || users.isEmpty) {
            return Center(
              child: Text(AppStrings.noOtherUsers,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.appSub)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (_, i) => DiscoverUserTile(user: users[i]),
          );
        },
      ),
    );
  }
}

// ─── Discover User Tile ───────────────────────────────────────────────────────

class DiscoverUserTile extends StatefulWidget {
  final Map<String, dynamic> user;
  const DiscoverUserTile({super.key, required this.user});

  @override
  State<DiscoverUserTile> createState() => _DiscoverUserTileState();
}

class _DiscoverUserTileState extends State<DiscoverUserTile> {
  late String _status;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _status = widget.user['friendship_status'];
  }

  Future<void> _sendRequest() async {
    final myId = supabase.auth.currentUser?.id;
    setState(() => _status = 'PENDING');
    try {
      await supabase.from('friendships').insert(
          {'requester_id': myId, 'addressee_id': widget.user['id']});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.requestSentTo(
              (widget.user['username'] ?? AppStrings.unknown).toString())),
          backgroundColor: context.appAccent,
        ));
      }
    } catch (e) {
      setState(() => _status = 'NONE');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uname = (widget.user['username'] ?? '?').toString();
    final initials = uname.isNotEmpty ? uname[0].toUpperCase() : '?';
    final avatarUrl = widget.user['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: context.appBorder,
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? Text(initials,
                    style: TextStyle(
                        color: context.appText,
                        fontWeight: FontWeight.w800,
                        fontSize: 14))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user['username'] ?? AppStrings.unknown,
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text(
                    AppStrings.quittingHabit(
                        widget.user['habit'] ?? AppStrings.quittingDefault),
                    style: TextStyle(color: context.appSub, fontSize: 12)),
              ],
            ),
          ),
          if (_status == 'NONE')
            GestureDetector(
              onTap: _sendRequest,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.appAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_add_alt_1_rounded,
                    color: context.appAccent, size: 20),
              ),
            )
          else if (_status == 'PENDING')
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.schedule_rounded,
                  color: context.appSub, size: 20),
            )
          else if (_status == 'ACCEPTED')
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.appAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.people_rounded,
                  color: context.appAccent, size: 20),
            ),
        ],
      ),
    );
  }
}
