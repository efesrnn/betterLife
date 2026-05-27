import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  bool _isSearching = false;

  List<Map<String, dynamic>> _allFriends = [];
  List<Map<String, dynamic>> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _fetchMyFriends();
  }

  Future<void> _fetchMyFriends() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;
    final friendships = await supabase
        .from('friendships')
        .select()
        .eq('status', 'ACCEPTED')
        .or('requester_id.eq.$myId,addressee_id.eq.$myId');

    List<Map<String, dynamic>> list = [];
    for (var f in friendships) {
      final friendId =
          (f['requester_id'] == myId) ? f['addressee_id'] : f['requester_id'];
      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', friendId)
          .maybeSingle();
      if (profile != null) list.add(profile);
    }
    setState(() {
      _allFriends = list;
      _filteredFriends = list;
    });
  }

  void _filterFriends(String query) {
    setState(() {
      _filteredFriends = query.isEmpty
          ? _allFriends
          : _allFriends
              .where((f) => f['username']!
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
                      _filterFriends('');
                    }
                  });
                },
              ),
              const SizedBox(width: 10),
              if (_isSearching)
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterFriends,
                    autofocus: true,
                    style: TextStyle(
                        color: context.appText, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Find friend...',
                      hintStyle: TextStyle(color: context.appSub),
                      border: InputBorder.none,
                    ),
                  ),
                )
              else ...[
                const Spacer(),
                _iconBtn(
                  context,
                  Icons.notifications_none_rounded,
                  () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FriendRequestsScreen()))
                      .then((_) => _fetchMyFriends()),
                ),
                const SizedBox(width: 10),
                _iconBtn(
                  context,
                  Icons.person_add_alt_1_rounded,
                  () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AddFriendScreen()))
                      .then((_) => _fetchMyFriends()),
                ),
              ],
            ],
          ),
        ),
        Divider(color: context.appBorder, height: 1),
        Expanded(
          child: _filteredFriends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded,
                          size: 52, color: context.appSub),
                      const SizedBox(height: 12),
                      Text('No friends yet',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.appSub)),
                      const SizedBox(height: 4),
                      Text('Add someone to get started',
                          style: TextStyle(
                              fontSize: 13, color: context.appTextDim)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredFriends.length,
                  itemBuilder: (context, i) {
                    final friend = _filteredFriends[i];
                    final double totalSaved =
                        (friend['total_saved'] ?? 0.0).toDouble();
                    final isCigarette = (friend['habit'] ?? '')
                        .toString()
                        .toLowerCase()
                        .contains('cigarette');
                    return _friendTile(context, friend, totalSaved, isCigarette);
                  },
                ),
        ),
      ],
    );
  }

  Widget _friendTile(BuildContext context, Map<String, dynamic> friend,
      double totalSaved, bool isCigarette) {
    final initials =
        (friend['username'] ?? '?')[0].toString().toUpperCase();
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
            radius: 22,
            backgroundColor: context.appBorder,
            child: Text(initials,
                style: TextStyle(
                    color: context.appText,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend['username'] ?? 'Unknown',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Quitting ${friend['habit'] ?? 'a bad habit'}',
                    style: TextStyle(color: context.appSub, fontSize: 12)),
                if (isCigarette) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Saved ₺${(totalSaved < 0 ? 0.0 : totalSaved).toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.appAccent),
                  ),
                ],
              ],
            ),
          ),
        ],
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
        });
      }
    }
    return requests;
  }

  Future<void> _accept(String id) async {
    await supabase.from('friendships').update({'status': 'ACCEPTED'}).eq('id', id);
    setState(() {});
  }

  Future<void> _reject(String id) async {
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
        title: Text('Friend Requests',
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
              child: Text('No pending requests.',
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
              final initials =
                  (req['username'] ?? '?')[0].toString().toUpperCase();
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
                      child: Text(initials,
                          style: TextStyle(
                              color: context.appText,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['username'] ?? 'Unknown',
                              style: TextStyle(
                                  color: context.appText,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text('Quitting ${req['habit'] ?? 'a bad habit'}',
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
        if (f['requester_id'] == user['id'] || f['addressee_id'] == user['id']) {
          status = f['status'];
          break;
        }
      }
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
        title: Text('Discover People',
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
              child: Text('No other users found yet.',
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
          content: Text("Request sent to ${widget.user['username']}!"),
          backgroundColor: context.appAccent,
        ));
      }
    } catch (e) {
      setState(() => _status = 'NONE');
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials =
        (widget.user['username'] ?? '?')[0].toString().toUpperCase();
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
            child: Text(initials,
                style: TextStyle(
                    color: context.appText,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user['username'] ?? 'Unknown',
                    style: TextStyle(
                        color: context.appText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                Text('Quitting ${widget.user['habit'] ?? 'a bad habit'}',
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