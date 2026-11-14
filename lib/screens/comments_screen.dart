import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class CommentsScreen extends StatefulWidget {
  final String videoId;
  final int initialCommentsCount;

  const CommentsScreen({
    Key? key,
    required this.videoId,
    required this.initialCommentsCount,
  }) : super(key: key);

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final PocketBaseService _pb = PocketBaseService();
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final records = await _pb.getComments(widget.videoId);
      setState(() {
        _comments = records;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;
    try {
      await _pb.addComment(widget.videoId, _commentController.text.trim());
      _commentController.clear();
      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _pb.isAuthenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('Comentarios')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No hay comentarios aún'))
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final record = _comments[index];
                          final user = record.expand?['user']?.data;
                          final email = user?['email'] ?? 'Usuario';
                          final text = record.data['text'] ?? '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Text(email[0].toUpperCase()),
                            ),
                            title: Text(email),
                            subtitle: Text(text),
                          );
                        },
                      ),
          ),
          if (isLoggedIn)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un comentario...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _postComment,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}