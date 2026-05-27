import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _bg = Color(0xFF0F172A);
const Color _card = Color(0xFF1E293B);
const Color _border = Color(0xFF334155);
const Color _accent = Color(0xFF818CF8);
const Color _green = Color(0xFF34D399);
const Color _sub = Color(0xFF94A3B8);

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
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

    List<Map<String, dynamic>> friendsList = [];
    for (var f in friendships) {
      String friendId = (f['requester_id'] == myId) ? f['addressee_id'] : f['requester_id'];
      final profile = await supabase.from('profiles').select().eq('id', friendId).maybeSingle();
      if (profile != null) friendsList.add(profile);
    }

    setState(() {
      _allFriends = friendsList;
      _filteredFriends = friendsList;
    });
  }

  void _filterFriends(String query) {
    setState(() {
      _filteredFriends = query.isEmpty
          ? _allFriends
          : _allFriends.where((f) => f['username']!.toString().toLowerCase().contains(query.toLowerCase())).toList();
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
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _filterFriends('');
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _card,
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                  ),
                  child: Icon(_isSearching ? Icons.close : Icons.search, size: 22, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              if (_isSearching)
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterFriends,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Find friend...',
                      hintStyle: TextStyle(color: _sub),
                      border: InputBorder.none,
                    ),
                  ),
                )
              else ...[
                const Spacer(),
                _iconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen())).then((_) => _fetchMyFriends()),
                ),
                const SizedBox(width: 10),
                _iconButton(
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFriendScreen())).then((_) => _fetchMyFriends()),
                ),
              ],
            ],
          ),
        ),
        const Divider(color: _border, height: 1),
        Expanded(
          child: _filteredFriends.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 56, color: _sub.withAlpha(100)),
                      const SizedBox(height: 12),
                      const Text(
                        'No friends yet',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _sub),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add someone to get started',
                        style: TextStyle(fontSize: 14, color: _sub),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = _filteredFriends[index];
                    final double totalSaved = (friend['total_saved'] ?? 0.0).toDouble();
                    final isCigarette = (friend['habit'] ?? '').toString().toLowerCase().contains('cigarette');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _border, width: 1),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _accent.withAlpha(40),
                            child: Text(
                              (friend['username'] ?? '?')[0].toString().toUpperCase(),
                              style: const TextStyle(color: _accent, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  friend['username'] ?? 'Unknown',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Quitting ${friend['habit'] ?? 'a bad habit'}',
                                  style: const TextStyle(color: _sub, fontSize: 13),
                                ),
                                if (isCigarette) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Saved ₺${(totalSaved < 0 ? 0.0 : totalSaved).toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _green),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _card,
          shape: BoxShape.circle,
          border: Border.all(color: _border),
        ),
        child: Icon(icon, size: 22, color: Colors.white),
      ),
    );
  }
}

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});
  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchRequests() async {
    final myId = supabase.auth.currentUser?.id;
    final friendships = await supabase.from('friendships').select().eq('addressee_id', myId ?? '').eq('status', 'PENDING');
    List<Map<String, dynamic>> requests = [];
    for (var f in friendships) {
      final profile = await supabase.from('profiles').select().eq('id', f['requester_id']).maybeSingle();
      if (profile != null) {
        requests.add({'friendship_id': f['id'], 'username': profile['username'], 'habit': profile['habit']});
      }
    }
    return requests;
  }

  Future<void> _acceptRequest(String friendshipId) async {
    await supabase.from('friendships').update({'status': 'ACCEPTED'}).eq('id', friendshipId);
    setState(() {});
  }

  Future<void> _rejectRequest(String friendshipId) async {
    await supabase.from('friendships').delete().eq('id', friendshipId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Friend Requests',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          final requests = snapshot.data;
          if (requests == null || requests.isEmpty) {
            return const Center(
              child: Text(
                'No pending requests.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _sub),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border, width: 1),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _accent.withAlpha(40),
                      child: Text(
                        (req['username'] ?? '?')[0].toString().toUpperCase(),
                        style: const TextStyle(color: _accent, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('Quitting ${req['habit'] ?? 'a bad habit'}', style: const TextStyle(color: _sub, fontSize: 13)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _acceptRequest(req['friendship_id']),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _green.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_rounded, color: _green, size: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _rejectRequest(req['friendship_id']),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 22),
                          ),
                        ),
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
}

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});
  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final myId = supabase.auth.currentUser?.id;
    final users = await supabase.from('profiles').select().neq('id', myId ?? '');
    final friendships = await supabase.from('friendships').select().or('requester_id.eq.$myId,addressee_id.eq.$myId');

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Discover People',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          final users = snapshot.data;
          if (users == null || users.isEmpty) {
            return const Center(
              child: Text('No other users found yet.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _sub)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) => DiscoverUserTile(user: users[index]),
          );
        },
      ),
    );
  }
}

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
      await supabase.from('friendships').insert({'requester_id': myId, 'addressee_id': widget.user['id']});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Request sent to ${widget.user['username']}!"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      setState(() => _status = 'NONE');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _accent.withAlpha(40),
            child: Text(
              (widget.user['username'] ?? '?')[0].toString().toUpperCase(),
              style: const TextStyle(color: _accent, fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user['username'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Quitting ${widget.user['habit'] ?? 'a bad habit'}', style: const TextStyle(color: _sub, fontSize: 13)),
              ],
            ),
          ),
          if (_status == 'NONE')
            GestureDetector(
              onTap: _sendRequest,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _accent.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: _accent, size: 22),
              ),
            )
          else if (_status == 'PENDING')
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.schedule_rounded, color: _sub, size: 22),
            )
          else if (_status == 'ACCEPTED')
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _green.withAlpha(30), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.people_rounded, color: _green, size: 22),
            ),
        ],
      ),
    );
  }
}