import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../repositories/inventory_repository.dart';
import 'today_page.dart'; // 引入 FadeInSlide 和 BouncingButton

class FamilyPage extends StatefulWidget {
  final InventoryRepository repo;
  const FamilyPage({super.key, required this.repo});

  @override
  State<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends State<FamilyPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    final list = await widget.repo.getFamilyMembers();
    if (mounted) {
      setState(() {
        _members = list;
        _loading = false;
      });
    }
  }

  Future<void> _generateInvite() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    
    try {
      final code = await widget.repo.createInviteCode();
      if (mounted) {
        setState(() => _loading = false);
        _showInviteDialog(code);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        String errorMsg = e.toString();
        if (errorMsg.contains('message:')) {
           errorMsg = errorMsg.split('message:')[1].split(',')[0];
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to generate code:\n\n$errorMsg'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ],
          ),
        );
      }
    }
  }

  Future<void> _joinFamily() async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController();
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Join Family', style: TextStyle(fontWeight: FontWeight.w700)),
        // 🟢 核心修复：添加 SingleChildScrollView 防止键盘弹起时溢出
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the 6-digit invitation code shared by a family member.', 
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5)
              ),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                autofocus: true, // 打开弹窗自动聚焦键盘
                decoration: InputDecoration(
                  labelText: 'Invite Code',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                ),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF005F87)),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Cancel')
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF005F87),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Join', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (ok == true && controller.text.trim().length >= 6) {
      setState(() => _loading = true);
      final success = await widget.repo.joinFamily(controller.text.trim());
      if (mounted) {
        setState(() => _loading = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
              content: Text('Joined family successfully! 🎉'),
              backgroundColor: Color(0xFF005F87),
            )
          );
          Navigator.pop(context); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
              content: Text('Invalid or expired code.'), 
              backgroundColor: Colors.redAccent
            )
          );
        }
      }
    }
  }

  void _showInviteDialog(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true, // 🟢 允许 BottomSheet 根据内容高度自适应（防止小屏幕溢出）
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView( // 🟢 同样添加滚动支持
          child: Padding(
            // 这里利用 viewInsets 处理键盘遮挡（虽然这个界面通常没有输入框，但为了通用性）
            padding: EdgeInsets.only(
              left: 32, 
              right: 32, 
              bottom: 32 + MediaQuery.of(ctx).viewInsets.bottom
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_unread_rounded, size: 36, color: Color(0xFF005F87)),
                ),
                const SizedBox(height: 20),
                const Text('Invite Member', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
                const SizedBox(height: 8),
                const Text('Share this code with your family member.\nThey can use it to join your home.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 14)
                ),
                const SizedBox(height: 32),
                
                // 邀请码卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: Column(
                    children: [
                      SelectableText(
                        code, 
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 6, color: Color(0xFF005F87))
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Expires in 2 days', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF005F87),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC), // 浅灰蓝背景
      appBar: AppBar(
        title: const Text('My Family', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black87)),
        backgroundColor: const Color(0xFFF8F9FC),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF005F87)))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                // 1. Header Card
                FadeInSlide(
                  index: 0,
                  child: _buildHeaderCard(),
                ),
                const SizedBox(height: 40),

                // 2. Members Title
                FadeInSlide(
                  index: 1,
                  child: Row(
                    children: [
                      const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF005F87).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_members.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF005F87)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Members List
                ..._members.asMap().entries.map((e) => FadeInSlide(
                  index: 2 + e.key,
                  child: _MemberTile(member: e.value),
                )),
                
                const SizedBox(height: 48),

                // 4. Actions
                FadeInSlide(
                  index: 2 + _members.length,
                  child: Column(
                    children: [
                      BouncingButton(
                        onTap: _generateInvite,
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF005F87), Color(0xFF0077A3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF005F87).withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8))
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 12),
                              Text('Invite New Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      BouncingButton(
                        onTap: _joinFamily,
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade200, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.group_add_outlined, color: Color(0xFF005F87), size: 22),
                              SizedBox(width: 12),
                              Text('Join Another Family', style: TextStyle(color: Color(0xFF005F87), fontWeight: FontWeight.w700, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF005F87).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_rounded, color: Color(0xFF005F87), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            widget.repo.currentFamilyName,
            style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Inventory & Shopping List Synced', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Map<String, dynamic> member;
  const _MemberTile({required this.member});

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue.shade400,
      Colors.purple.shade400,
      Colors.teal.shade400,
      Colors.orange.shade400,
      Colors.pink.shade400,
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final name = member['name'] ?? 'Unknown';
    final role = (member['role'] ?? 'member').toString().toUpperCase();
    final isOwner = role == 'OWNER';
    final avatarColor = _getAvatarColor(name);

    return BouncingButton( // 给每个成员卡片加上点击动效
      onTap: () {}, // 占位，保持动效
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: avatarColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: TextStyle(fontWeight: FontWeight.w800, color: avatarColor, fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOwner ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 10, 
                        color: isOwner ? Colors.orange[800] : Colors.grey[600], 
                        fontWeight: FontWeight.w700, 
                        letterSpacing: 0.5
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isOwner)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.star_rounded, color: Colors.orange[400], size: 18),
              ),
          ],
        ),
      ),
    );
  }
}