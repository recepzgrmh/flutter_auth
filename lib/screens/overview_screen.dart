// lib/screens/overview_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:login_page/services/openai_service.dart';

class OverviewScreen extends StatefulWidget {
  final String uid;
  final String complaintId;
  final Map<String, String> inputs;
  final List<String> questions;

  const OverviewScreen({
    super.key,
    required this.uid,
    required this.complaintId,
    required this.inputs,
    required this.questions,
  });

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late final OpenAI _openAI;
  final OpenAIService _service = OpenAIService();
  late final String _apiKey;

  bool _emojiShowing = false;
  String _gptState = 'Çevrimiçi';

  final ChatUser _currentUser = ChatUser(id: '1', firstName: 'Sen');
  final ChatUser _gptChatUser = ChatUser(
    id: '2',
    firstName: 'ChatGPT',
    profileImage: "assets/images/avatar.png",
  );

  late final CollectionReference<Map<String, dynamic>> _messagesRef;

  // Takip soruları için
  int _currentQIndex = 0;
  final List<String> _answers = [];
  bool _flowComplete = false;

  @override
  void initState() {
    super.initState();

    // burayı uygulama yayınlanırken kaldırmayı unutma
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'API anahtarı bulunamadı! .env dosyasını kontrol edin.',
            ),
          ),
        );
      });
    }

    _openAI = OpenAI.instance.build(
      token: _apiKey,
      baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 10)),
      enableLog: true,
    );

    _messagesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .collection('complaints')
        .doc(widget.complaintId)
        .collection('messages');
  }

  Future<void> _onSendMessage(ChatMessage userMsg) async {
    setState(() => _gptState = '...yazıyor');

    // 1. Kullanıcı cevabını kaydet
    await _messagesRef.add({
      'text': userMsg.text,
      'senderId': _currentUser.id,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // 2. Eğer sorular akışı bitmediyse
    if (!_flowComplete && _currentQIndex < widget.questions.length) {
      // Gelen cevabı listeye ekle
      _answers.add(userMsg.text.trim());

      // a) Daha soru varsa → bir sonraki soruyu ekle
      if (_currentQIndex + 1 < widget.questions.length) {
        final nextQ = widget.questions[_currentQIndex + 1];
        await _messagesRef.add({
          'text': nextQ,
          'senderId': _gptChatUser.id,
          'sentAt': FieldValue.serverTimestamp(),
        });
        setState(() => _currentQIndex++);
      }
      // b) Son soruya da cevap verildiyse → nihai değerlendirmeyi al ve göster
      else {
        final report = await _service.getFinalEvaluation(
          widget.inputs,
          _answers,
        );
        await _messagesRef.add({
          'text': report,
          'senderId': _gptChatUser.id,
          'sentAt': FieldValue.serverTimestamp(),
        });
        setState(() => _flowComplete = true);
      }
    }
    // 3. Eğer takip akışı tamamlandıysa, klasik ChatGPT sohbetine dön
    else {
      final historySnapshot = await _messagesRef.orderBy('sentAt').get();
      final openAIHistory =
          historySnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'role':
                  data['senderId'] == _currentUser.id ? 'user' : 'assistant',
              'content': data['text'] ?? '',
            };
          }).toList();

      final request = ChatCompleteText(
        model: Gpt4oMiniChatModel(),
        messages: openAIHistory,
        maxToken: 1000,
      );

      try {
        final resp = await _openAI.onChatCompletion(request: request);
        final aiContent = resp?.choices.first.message?.content.trim() ?? '';
        if (aiContent.isNotEmpty) {
          await _messagesRef.add({
            'text': aiContent,
            'senderId': _gptChatUser.id,
            'sentAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('❌ OpenAI error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OpenAI ile iletişim kurulamadı')),
        );
      }
    }

    setState(() => _gptState = 'Çevrimiçi');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 70,
        elevation: 4,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundImage: AssetImage('assets/images/avatar.png'),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ChatGPT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.lightGreenAccent.shade200,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _gptState,
                          style: TextStyle(
                            color: Colors.lightGreenAccent.shade200,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.teal.shade50,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _messagesRef.orderBy('sentAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snapshot.data?.docs ?? [];
            final messages =
                docs.map((doc) {
                  final data = doc.data();
                  final raw = data['sentAt'];
                  final createdAt =
                      raw is Timestamp ? raw.toDate() : DateTime.now();
                  return ChatMessage(
                    user:
                        data['senderId'] == _currentUser.id
                            ? _currentUser
                            : _gptChatUser,
                    createdAt: createdAt,
                    text: data['text'] ?? '',
                  );
                }).toList();

            return DashChat(
              messages: messages,
              currentUser: _currentUser,
              onSend: _onSendMessage,
              inputOptions: InputOptions(
                sendOnEnter: false,
                sendButtonBuilder:
                    (send) => IconButton(
                      onPressed: send,
                      icon: const Icon(Icons.send),
                    ),
                inputDecoration: InputDecoration(
                  fillColor: Colors.white,
                  hintText: 'Mesajınızı yazın...',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                leading: [
                  IconButton(
                    onPressed:
                        () => setState(() => _emojiShowing = !_emojiShowing),
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Colors.teal,
                      size: 30,
                    ),
                  ),
                ],
                trailing: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.attach_file,
                      color: Colors.teal,
                      size: 30,
                    ),
                  ),
                ],
              ),
              messageOptions: MessageOptions(
                messageDecorationBuilder: (message, prev, next) {
                  final isMe = message.user.id == _currentUser.id;
                  return BoxDecoration(
                    color: isMe ? Colors.teal : Colors.grey.shade300,
                    boxShadow: const [
                      BoxShadow(offset: Offset(1, 1), blurRadius: 2),
                    ],
                    border: Border.all(
                      width: 2,
                      color: isMe ? Colors.teal : Colors.white,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
