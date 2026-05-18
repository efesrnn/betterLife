import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Aynı slug eşlemesi home_screen.dart'taki ile bilinçli olarak çoğaltıldı —
// bu parça (i18n) çok yer dokunmasın diye. Sonraki parçada paylaşılan
// yardımcıya taşınacak.
const _kKnownHabitSlugs = <String>{
  'cigarettes',
  'vapes',
  'alcohol',
  'junk_food',
  'screen_time',
};

String _habitSlug(String raw) {
  final h = raw.toLowerCase().trim();
  if (h.isEmpty) return '';
  if (_kKnownHabitSlugs.contains(h)) return h;
  if (h.contains('cigarette')) return 'cigarettes';
  if (h.contains('vape')) return 'vapes';
  if (h.contains('alcohol')) return 'alcohol';
  if (h.contains('junk')) return 'junk_food';
  if (h.contains('screen')) return 'screen_time';
  return '';
}

/// "Quitting cigarettes" gibi metni çeviri ile döndürür; slug yoksa ham metni
/// argüman olarak geçer.
String _quittingLabel(String habitRaw) {
  final slug = _habitSlug(habitRaw);
  final habitText = slug.isNotEmpty
      ? 'habit_setup.habits.$slug'.tr()
      : habitRaw;
  return 'friends.quitting'.tr(namedArgs: {'habit': habitText});
}

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Demo verisi — gerçek arkadaş çekimi sonraki parçada gelecek.
  final List<Map<String, String>> _allFriends = [
    {'name': 'Mertcan', 'habit': 'cigarettes', 'days': '12'},
    {'name': 'Ahmet', 'habit': 'alcohol', 'days': '5'},
  ];

  List<Map<String, String>> _filteredFriends = [];

  @override
  void initState() {
    super.initState();
    _filteredFriends = _allFriends;
  }

  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _allFriends;
      } else {
        _filteredFriends = _allFriends
            .where((friend) => friend['name']!.toLowerCase().contains(query.toLowerCase()))
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
                          decoration: InputDecoration(hintText: 'friends.search_hint'.tr(), border: InputBorder.none),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_isSearching)
                Row(
                  children: [
                    // YENİ: Gelen İstekler (Zil) Butonu
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendRequestsScreen()));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 2)),
                        child: const Icon(Icons.notifications_none, size: 28, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Arkadaş Ekle (Keşfet) Butonu
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const AddFriendScreen()));
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
              ? Center(
                  child: Text(
                    'friends.no_friends_found'.tr(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54),
                  ),
                )
              : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _filteredFriends.length,
            itemBuilder: (context, index) {
              final friend = _filteredFriends[index];
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
                          Text(friend['name']!, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(_quittingLabel(friend['habit'] ?? ''), style: const TextStyle(fontSize: 16, color: Colors.black54)),
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

// ---------------------------------------------------------
// YENİ: GELEN İSTEKLER SAYFASI (Zil İkonuna Basınca Açılır)
// ---------------------------------------------------------
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchRequests() async {
    final myId = supabase.auth.currentUser?.id;
    // Bize gelen (addressee biziz) ve hala PENDING (bekleyen) istekleri çekiyoruz
    final friendships = await supabase.from('friendships').select().eq('addressee_id', myId ?? '').eq('status', 'PENDING');

    List<Map<String, dynamic>> requests = [];
    for (var f in friendships) {
      // İstek atan kişinin profil bilgilerini çekiyoruz
      final profile = await supabase.from('profiles').select().eq('id', f['requester_id']).maybeSingle();
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

  Future<void> _acceptRequest(String friendshipId) async {
    await supabase.from('friendships').update({'status': 'ACCEPTED'}).eq('id', friendshipId);
    setState(() {}); // Ekranı yenile
  }

  Future<void> _rejectRequest(String friendshipId) async {
    // Reddedilirse veritabanından siliyoruz. Böylece karşı tarafın "Discover" ekranında tik tekrar "+" işaretine dönecek!
    await supabase.from('friendships').delete().eq('id', friendshipId);
    setState(() {}); // Ekranı yenile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text('friends.requests_title'.tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));

          final requests = snapshot.data;
          if (requests == null || requests.isEmpty) {
            return Center(
              child: Text(
                'friends.no_requests'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            );
          }

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
                          Text(req['username'] ?? 'common.unknown'.tr(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(_quittingLabel((req['habit'] as String?) ?? ''), style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        ],
                      ),
                    ),
                    // Kabul ve Red Butonları
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 35),
                          onPressed: () => _acceptRequest(req['friendship_id'].toString()),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red, size: 35),
                          onPressed: () => _rejectRequest(req['friendship_id'].toString()),
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

// ---------------------------------------------------------
// DİSCOVER PEOPLE SAYFASI (+ Kişi İkonuna Basınca Açılır)
// ---------------------------------------------------------
class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final myId = supabase.auth.currentUser?.id;

    // 1. Herkesi çek (Ben hariç)
    final users = await supabase.from('profiles').select().neq('id', myId ?? '');
    // 2. Benim gönderdiğim veya bana gelen tüm arkadaşlık bağlantılarını çek
    final friendships = await supabase.from('friendships').select().or('requester_id.eq.$myId,addressee_id.eq.$myId');

    List<Map<String, dynamic>> result = [];
    for (var user in users) {
      String status = 'NONE'; // Varsayılan: İstek atılmamış

      // Bu kullanıcıyla bir bağlantımız var mı kontrol edelim
      for (var f in friendships) {
        if (f['requester_id'] == user['id'] || f['addressee_id'] == user['id']) {
          status = f['status']; // PENDING veya ACCEPTED
          break;
        }
      }

      result.add({
        ...user,
        'friendship_status': status,
      });
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
        title: Text('friends.discover_title'.tr(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.black));

          final users = snapshot.data;
          if (users == null || users.isEmpty) {
            return Center(
              child: Text(
                'friends.no_users'.tr(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return DiscoverUserTile(user: user); // İşlemler için ayrı bir Widget yaptık (Tik olma mantığı için)
            },
          );
        },
      ),
    );
  }
}

// İstek atınca Tik olmasını sağlayan özel kart tasarımı
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
    setState(() => _status = 'PENDING'); // Anında ekranda TİK yapıyoruz

    try {
      await supabase.from('friendships').insert({
        'requester_id': myId,
        'addressee_id': widget.user['id'],
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('friends.request_sent_to'.tr(namedArgs: {'name': widget.user['username'] ?? ''})),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _status = 'NONE'); // Hata olursa eski haline döner
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
                Text(widget.user['username'] ?? 'common.unknown'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(_quittingLabel((widget.user['habit'] as String?) ?? ''), style: const TextStyle(fontSize: 16, color: Colors.black54)),
              ],
            ),
          ),

          // DİNAMİK İKON MANTIĞI: Duruma göre İkon değişir
          if (_status == 'NONE')
            IconButton(
              iconSize: 32,
              icon: const Icon(Icons.person_add_alt_1),
              color: Colors.black,
              onPressed: _sendRequest, // İstek Gönder
            )
          else if (_status == 'PENDING')
            const Padding(
              padding: EdgeInsets.only(right: 15.0),
              child: Icon(Icons.check, size: 32, color: Colors.black54), // Gönderildi (TİK)
            )
          else if (_status == 'ACCEPTED')
              const Padding(
                padding: EdgeInsets.only(right: 15.0),
                child: Icon(Icons.people, size: 32, color: Colors.green), // Arkadaş olundu
              )
        ],
      ),
    );
  }
}
