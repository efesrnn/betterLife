import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // YENİ: Supabase'den sadece Kabul Edilmiş (ACCEPTED) arkadaşlarımızı çekiyoruz
  Future<void> _fetchMyFriends() async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    final friendships = await supabase.from('friendships')
        .select()
        .eq('status', 'ACCEPTED')
        .or('requester_id.eq.$myId,addressee_id.eq.$myId');

    List<Map<String, dynamic>> friendsList = [];

    for (var f in friendships) {
      String friendId = (f['requester_id'] == myId) ? f['addressee_id'] : f['requester_id'];
      final profile = await supabase.from('profiles').select().eq('id', friendId).maybeSingle();

      if (profile != null) {
        friendsList.add(profile);
      }
    }

    setState(() {
      _allFriends = friendsList;
      _filteredFriends = friendsList;
    });
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends
            .where((friend) => friend['username']!.toString().toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
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
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                        child: Icon(_isSearching ? Icons.close : Icons.search, size: 28, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_isSearching)
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _filterFriends,
                          autofocus: true,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          decoration: const InputDecoration(hintText: 'Find friend...', border: InputBorder.none),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_isSearching)
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendRequestsScreen())).then((_) => _fetchMyFriends());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                        child: const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AddFriendScreen())).then((_) => _fetchMyFriends());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                        child: const Icon(Icons.person_add_alt_1, size: 28, color: Colors.black),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(color: Colors.black, thickness: 2, height: 1),
        Expanded(
          child: _filteredFriends.isEmpty
              ? const Center(child: Text('No friends found.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54)))
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _filteredFriends.length,
            itemBuilder: (context, index) {
              final friend = _filteredFriends[index];
              final double totalSaved = (friend['total_saved'] ?? 0.0).toDouble();
              final isCigarette = (friend['habit'] ?? '').toString().toLowerCase().contains('cigarette');

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2)),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, size: 50, color: Colors.black87),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(friend['username'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('Quitting ${friend['habit'] ?? 'a bad habit'}', style: const TextStyle(fontSize: 16, color: Colors.black54)),
                          // Arkadaşın kâr durumu burada gösteriliyor
                          if (isCigarette)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Saved ₺${(totalSaved < 0 ? 0.0 : totalSaved).toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.green),
                              ),
                            ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Friend Requests', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
          final requests = snapshot.data;
          if (requests == null || requests.isEmpty) return const Center(child: Text('No new requests.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)));
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2)),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, size: 50, color: Colors.black87),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['username'] ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Quitting ${req['habit'] ?? 'a bad habit'}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 35), onPressed: () => _acceptRequest(req['friendship_id'])),
                        IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 35), onPressed: () => _rejectRequest(req['friendship_id'])),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Discover People', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));
          final users = snapshot.data;
          if (users == null || users.isEmpty) return const Center(child: Text('No other users found yet.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              return DiscoverUserTile(user: users[index]);
            },
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request sent to ${widget.user['username']}!"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _status = 'NONE');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.black, width: 2)),
      child: Row(
        children: [
          const Icon(Icons.account_circle, size: 50, color: Colors.black87),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user['username'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Quitting ${widget.user['habit'] ?? 'a bad habit'}', style: const TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          ),
          if (_status == 'NONE') IconButton(iconSize: 32, icon: const Icon(Icons.person_add_alt_1), color: Colors.black, onPressed: _sendRequest)
          else if (_status == 'PENDING') const Padding(padding: EdgeInsets.only(right: 15.0), child: Icon(Icons.check, size: 32, color: Colors.black54))
          else if (_status == 'ACCEPTED') const Padding(padding: EdgeInsets.only(right: 15.0), child: Icon(Icons.people, size: 32, color: Colors.green))
        ],
      ),
    );
  }
}