// lib/screens/senior_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 引入 Supabase

import '../repositories/inventory_repository.dart';
import '../models/food_item.dart';
import '../utils/bsh_toast.dart';

class SeniorHome extends StatefulWidget {
  const SeniorHome({super.key});

  @override
  State<SeniorHome> createState() => _SeniorHomeState();
}

class _SeniorHomeState extends State<SeniorHome> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _feedbackMessage = "Tap mic to speak...";
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  // --- 🎤 Voice Logic ---
  Future<void> _listen() async {
    if (!_isListening) {
      // Check permissions
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) BSHToast.show(context, title: "Microphone permission needed", type: BSHToastType.error);
        return;
      }

      // Initialize Speech to Text
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (mounted) setState(() => _isListening = (val == 'listening'));
        },
        onError: (val) {
          if (mounted) setState(() { _isListening = false; _feedbackMessage = "Sorry, try again."; });
        },
      );

      if (available) {
        setState(() { _isListening = true; _feedbackMessage = "Listening..."; });
        _speech.listen(onResult: (val) {
          if (val.finalResult) {
            _processCommand(val.recognizedWords); 
          }
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // --- 🤖 Command Processing (Smart Backend) ---
  Future<void> _processCommand(String text) async {
    setState(() => _feedbackMessage = "Thinking...");

    try {
      // 🟢 1. Try calling Supabase Edge Function (GPT-4o)
      // If you haven't deployed the function yet, this might fail, so we catch it.
      final response = await Supabase.instance.client.functions.invoke(
        'voice-assistant', 
        body: {'text': text},
      );

      if (response.status == 200) {
        final data = response.data;
        final message = data['message'] ?? 'Done';
        
        if (mounted) {
          setState(() => _feedbackMessage = message);
          BSHToast.show(context, title: "Success", description: message, type: BSHToastType.success);
        }
        return; // Exit if cloud processing succeeded
      }
    } catch (e) {
      debugPrint("Cloud processing failed, falling back to local: $e");
    }

    // 🟡 2. Local Fallback Logic (Regex)
    // Only runs if cloud function is not deployed or fails
    final lower = text.toLowerCase();
    final repo = context.read<InventoryRepository>();
    String response = "";
    
    if (lower.contains('buy') || lower.contains('add') || lower.contains('get')) {
      final item = text.split(' ').last; // Simple extraction
      await repo.addItem(FoodItem(
        id: const Uuid().v4(), 
        name: item, 
        location: StorageLocation.fridge, 
        quantity: 1, 
        unit: 'pcs', 
        purchasedDate: DateTime.now(),
        category: 'General'
      ));
      response = "Added $item to fridge.";
    } else if (lower.contains('eat') || lower.contains('ate')) {
       response = "Marked as eaten locally.";
    } else {
      response = "Sorry, try saying 'Buy Milk'.";
    }

    if (mounted) {
      setState(() => _feedbackMessage = response);
      BSHToast.show(context, title: "Done (Local)", type: BSHToastType.success);
    }
  }

  // --- 💡 Health & Nutrition Logic ---
  String _getHealthTip(List<FoodItem> items) {
    if (items.any((i) => i.name.toLowerCase().contains('milk') || i.name.toLowerCase().contains('yogurt'))) {
      return "Dairy is great for bone health! 🥛";
    }
    if (items.any((i) => i.name.toLowerCase().contains('spinach') || i.name.toLowerCase().contains('broccoli'))) {
      return "Excellent! Green veggies boost immunity. 🥦";
    }
    if (items.any((i) => i.name.toLowerCase().contains('fish'))) {
      return "Fish is great for heart health. 🐟";
    }
    return "Remember to drink water and stay hydrated! 💧";
  }

  Map<String, int> _calculateDailyNutrition(InventoryRepository repo) {
    final today = DateTime.now();
    final todayEvents = repo.impactEvents.where((e) => 
      e.date.year == today.year && e.date.month == today.month && e.date.day == today.day && e.type == ImpactType.eaten
    ).toList();

    int veggies = 0;
    int protein = 0;

    for (var e in todayEvents) {
      final cat = (e.itemCategory ?? '').toLowerCase();
      final name = (e.itemName ?? '').toLowerCase();
      
      // Simple keyword matching for demo
      if (cat.contains('veg') || cat.contains('fruit') || name.contains('apple') || name.contains('banana')) veggies++;
      if (cat.contains('meat') || cat.contains('egg') || cat.contains('fish') || name.contains('chicken')) protein++;
    }
    return {'veggies': veggies, 'protein': protein};
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<InventoryRepository>();
    final alerts = repo.getExpiringItems(3); // Items expiring in 3 days
    final nutrition = _calculateDailyNutrition(repo);
    final tip = _getHealthTip(repo.getActiveItems());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 90,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Good Morning,", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(repo.currentFamilyName, style: const TextStyle(fontSize: 34, color: Colors.black, fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: () => repo.toggleSeniorMode(false), // Exit Senior Mode
              icon: const Icon(Icons.exit_to_app_rounded, size: 36, color: Colors.black),
              tooltip: "Exit Senior Mode",
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // === 1. Information Stream (70%) ===
          Expanded(
            flex: 7,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // ⚠️ Urgent Alerts (High Priority)
                if (alerts.isNotEmpty)
                  _SeniorCard(
                    bgColor: const Color(0xFFFFEBEE), // Light Red
                    borderColor: Colors.red,
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                    title: "Eat Soon!",
                    contentWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${alerts.length} items expiring", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(alerts.take(3).map((e) => "• ${e.name}").join("\n"), style: const TextStyle(fontSize: 20, height: 1.5)),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),

                // 🥕 Nutrition Snapshot (Health Focus)
                _SeniorCard(
                  bgColor: const Color(0xFFE8F5E9), // Light Green
                  borderColor: Colors.green,
                  icon: Icons.health_and_safety_rounded,
                  iconColor: Colors.green,
                  title: "Nutrition Today",
                  contentWidget: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NutritionCounter("Fruits/Veg", nutrition['veggies']!, "🍎"),
                      Container(width: 2, height: 50, color: Colors.green.withOpacity(0.3)),
                      _NutritionCounter("Protein", nutrition['protein']!, "🥩"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 💡 Daily Tip (Engagement)
                _SeniorCard(
                  bgColor: const Color(0xFFE3F2FD), // Light Blue
                  borderColor: const Color(0xFF004A77),
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: const Color(0xFF004A77),
                  title: "Daily Tip",
                  contentWidget: Text(tip, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF004A77))),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),

          // === 2. Voice Command Center (30%) ===
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black, width: 2)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: Column(
                children: [
                  // Feedback Text
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _feedbackMessage, 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _isListening ? const Color(0xFF004A77) : Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  
                  // Big Mic Button
                  GestureDetector(
                    onTap: _listen,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.redAccent : const Color(0xFF004A77),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _isListening ? Colors.redAccent.withOpacity(0.4) : const Color(0xFF004A77).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: _isListening ? 5 : 0,
                            offset: const Offset(0, 5)
                          )
                        ],
                      ),
                      child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Tap & Say 'Bought Milk'", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === UI Components ===

class _SeniorCard extends StatelessWidget {
  final Color bgColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget contentWidget;

  const _SeniorCard({required this.bgColor, required this.borderColor, required this.icon, required this.iconColor, required this.title, required this.contentWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 36, color: iconColor),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 20, color: borderColor, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          contentWidget,
        ],
      ),
    );
  }
}

class _NutritionCounter extends StatelessWidget {
  final String label;
  final int count;
  final String emoji;
  const _NutritionCounter(this.label, this.count, this.emoji);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 4),
        Text("$count", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }
}