import 'package:flutter/material.dart';

const _bg = Color(0xFF05090E);
const _panel = Color(0xFF0B141C);
const _cyan = Color(0xFF50F5FF);
const _lime = Color(0xFFC9FF58);
const _text = Color(0xFFF1F8FF);
const _muted = Color(0xFF7990A1);

class AiCopilotSheet extends StatefulWidget {
  const AiCopilotSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiCopilotSheet(),
    );
  }

  @override
  State<AiCopilotSheet> createState() => _AiCopilotSheetState();
}

class _AiCopilotSheetState extends State<AiCopilotSheet> {
  final _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      "sender": "ai",
      "text": "Hello! I am your VoltEZ Business AI Copilot powered by Gemini & Lyzr. Ask me anything about off-peak availability, forecast demand, or charger utilization."
    }
  ];

  void _sendQuery(String query) {
    if (query.trim().isEmpty) return;
    setState(() {
      _messages.add({"sender": "user", "text": query});
      _controller.clear();
    });

    // Grounded deterministic AI responses based on VoltEZ playbook rules
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      String response = "Based on local Pune EV traffic data, charger demand peaks between 5 PM - 8 PM. Opening an off-peak slot (2 PM - 5 PM) at ₹20/kWh is predicted to increase your station utilization by 24%.";
      
      final lower = query.toLowerCase();
      if (lower.contains("why") || lower.contains("2-5")) {
        response = "The 2 PM – 5 PM window has high predicted driver corridor traffic (18 arrivals) while nearby competitor supply is low (only 5 active chargers). Opening this window converts idle capacity into footfall.";
      } else if (lower.contains("revenue") || lower.contains("earn")) {
        response = "Your projected revenue for this week is ₹42,850 (+18.4% vs last week). Accepting the recommended 2-5 PM window adds approximately ₹3,400 in incremental monthly earnings.";
      } else if (lower.contains("reliability") || lower.contains("health")) {
        response = "Your station reliability rating is 98% (Bayesian smoothed). All 3 chargers are currently in peak health with zero reported session drops.";
      }

      setState(() {
        _messages.add({"sender": "ai", "text": response});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(.06))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _cyan.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: _cyan, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "VOLTEZ AI COPILOT",
                      style: TextStyle(
                        color: _text,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      "Powered by Gemini & Lyzr Intelligence",
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _muted),
                ),
              ],
            ),
          ),

          // Suggested Prompts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _chip("Why open 2-5 PM window?"),
                _chip("Projected weekly revenue?"),
                _chip("Station reliability score"),
              ],
            ),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["sender"] == "user";

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? _cyan.withOpacity(.15) : _bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser ? _cyan.withOpacity(.4) : Colors.white.withOpacity(.08),
                      ),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                        color: isUser ? _cyan : _text,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bg,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(.06))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: _text, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Ask AI Copilot...",
                      hintStyle: const TextStyle(color: _muted),
                      filled: true,
                      fillColor: _panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: _sendQuery,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: _lime,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => _sendQuery(_controller.text),
                  icon: const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        backgroundColor: Colors.white.withOpacity(.04),
        side: BorderSide(color: _cyan.withOpacity(.2)),
        label: Text(
          text,
          style: const TextStyle(color: _cyan, fontSize: 10),
        ),
        onPressed: () => _sendQuery(text),
      ),
    );
  }
}
