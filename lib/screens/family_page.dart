// lib/screens/family_page.dart
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

  // 🟢 核心修复：使用 try-catch-finally 确保 Loading 必定停止
  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final list = await widget.repo.getFamilyMembers();
      if (mounted) {
        setState(() {
          _members = list;
        });
      }
    } catch (e) {
      debugPrint("Error loading members: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load members: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // 无论成功还是失败，都必须停止转圈
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _generateInvite() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    
    try {
      // 增加超时保护，防止卡死
      final code = await widget.repo.createInviteCode().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw 'Request timed out. Please check your network.';
        },
      );

      if (mounted) {
        _showInviteDialog(code);
      }
    } catch (e) {
      if (mounted) {
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
    } finally {
      // 🟢 修复：生成邀请码后也要确保 Loading 停止
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _joinFamily() async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController();
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Join Family', style: TextStyle(fontWeight: FontWeight.w700, color: colors.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the 6-digit invitation code shared by a family member.', 
                  style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.6), height: 1.5)
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Invite Code',
                    labelStyle: TextStyle(color: colors.onSurface.withOpacity(0.7)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: theme.cardColor,
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
        );
      },
    );

    if (ok == true && controller.text.trim().length >= 6) {
      setState(() => _loading = true);
      
      try {
        final success = await widget.repo.joinFamily(controller.text.trim());
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(20),
                content: Text('Joined family successfully! 🎉'),
                backgroundColor: Color(0xFF005F87),
              )
            );
            // 重新加载成员列表
            _loadMembers();
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
      } catch (e) {
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  // 🟢 退出家庭的处理函数
  Future<void> _handleLeaveFamily() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Family?'),
        content: const Text('You will no longer see shared inventory and shopping lists. You will return to your own private home.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        final success = await widget.repo.leaveFamily();
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Left family. Switched to private mode.'))
            );
            _loadMembers(); // 重新加载（会自动变为 My Home）
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to leave family.'), backgroundColor: Colors.red)
            );
          }
        }
      } catch (e) {
        debugPrint('Leave family error: $e');
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _showInviteDialog(String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      showDragHandle: true,
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colors = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: SingleChildScrollView( 
            child: Padding(
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
                    decoration: BoxDecoration(
                      color: isDark ? colors.onSurface.withOpacity(0.08) : const Color(0xFFE3F2FD),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, size: 36, color: Color(0xFF005F87)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Invite Member',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: colors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Text('Share this code with your family member.\nThey can use it to join your home.', 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurface.withOpacity(0.6), height: 1.5, fontSize: 14)
                  ),
                  const SizedBox(height: 32),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.dividerColor, width: 1),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? colors.surfaceVariant.withOpacity(0.35) : theme.cardColor;
    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('My Family', style: TextStyle(fontWeight: FontWeight.w800, color: colors.onSurface)),
          backgroundColor: theme.scaffoldBackgroundColor,
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: colors.onSurface),
        ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF005F87)))
          : AnimatedBuilder(
              animation: widget.repo,
              builder: (context, _) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  children: [
                    if (_shouldShowMigrationBanner(widget.repo))
                      FadeInSlide(
                        index: 0,
                        child: _buildMigrationBanner(widget.repo),
                      ),
                    FadeInSlide(
                      index: 1,
                      child: _buildHeaderCard(),
                    ),
                    const SizedBox(height: 32),

                    // 🟢 2. Inventory Mode Selection (新增)
                    FadeInSlide(
                      index: 2,
                      child: _buildModeSelection(),
                    ),
                    const SizedBox(height: 32),

                    FadeInSlide(
                      index: 3,
                      child: Row(
                        children: [
                          Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.onSurface,
                            ),
                          ),
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

                    if (_members.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                          child: Text(
                            "No members found.",
                            style: TextStyle(color: colors.onSurface.withOpacity(0.6)),
                          ),
                        ),
                      )
                    else
                      ..._members.asMap().entries.map((e) => FadeInSlide(
                        index: 4 + e.key,
                        child: _MemberTile(member: e.value),
                      )),
                    
                    const SizedBox(height: 48),

                    FadeInSlide(
                      index: 4 + (_members.isEmpty ? 1 : _members.length),
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
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: theme.dividerColor, width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.group_add_outlined, color: Color(0xFF005F87), size: 22),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Join Another Family',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // 🟢 底部退出按钮
                          const SizedBox(height: 40),
                          TextButton.icon(
                            onPressed: _handleLeaveFamily,
                            icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent, size: 20),
                            label: const Text('Leave This Family', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? colors.surfaceVariant.withOpacity(0.35) : theme.cardColor;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
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
              color: isDark ? colors.onSurface.withOpacity(0.08) : const Color(0xFFF0F7FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.home_rounded, color: Color(0xFF005F87), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            widget.repo.currentFamilyName,
            style: TextStyle(color: colors.onSurface, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Inventory & Shopping List Synced',
            style: TextStyle(color: colors.onSurface.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  bool _shouldShowMigrationBanner(InventoryRepository repo) {
    return repo.migrationPhase == MigrationPhase.preparing ||
        repo.migrationPhase == MigrationPhase.migrating ||
        repo.migrationPhase == MigrationPhase.cleaning ||
        repo.migrationPhase == MigrationPhase.failed;
  }

  Widget _buildMigrationBanner(InventoryRepository repo) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isFailed = repo.migrationPhase == MigrationPhase.failed;
    final bg = isFailed
        ? (isDark ? const Color(0xFF2A1B1B) : const Color(0xFFFFF3F3))
        : (isDark ? colors.surfaceVariant.withOpacity(0.35) : const Color(0xFFF2F6FB));
    final borderColor = isFailed ? Colors.redAccent : const Color(0xFF005F87);
    final title = isFailed ? 'Migration failed' : 'Migrating your data';
    final subtitle = repo.migrationMessage ?? 'Please keep the app open.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFailed ? Icons.error_outline_rounded : Icons.sync_rounded,
              color: borderColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withOpacity(0.6),
                  ),
                ),
                if (!isFailed) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    minHeight: 6,
                    color: const Color(0xFF005F87),
                    backgroundColor: colors.onSurface.withOpacity(0.08),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Attempt ${repo.migrationAttempt} / 3',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
                if (isFailed && repo.migrationError != null && repo.migrationError!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    repo.migrationError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🟢 新增：模式选择组件
  Widget _buildModeSelection() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? colors.surfaceVariant.withOpacity(0.35) : theme.cardColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Inventory Mode',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface.withOpacity(0.6)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              RadioListTile<bool>(
                title: Text('Shared Fridge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: colors.onSurface)),
                subtitle: Text('All members manage inventory together.', style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.6))),
                value: true,
                groupValue: widget.repo.isSharedUsage,
                activeColor: const Color(0xFF0E7AA8),
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.group_work_rounded, color: Colors.blue),
                ),
                onChanged: (val) => widget.repo.setSharedUsageMode(val!),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              RadioListTile<bool>(
                title: Text('Separate Fridges', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: colors.onSurface)),
                subtitle: Text('Items are strictly assigned to owners.', style: TextStyle(fontSize: 13, color: colors.onSurface.withOpacity(0.6))),
                value: false,
                groupValue: widget.repo.isSharedUsage,
                activeColor: const Color(0xFF0E7AA8),
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(isDark ? 0.2 : 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline_rounded, color: Colors.orange),
                ),
                onChanged: (val) => widget.repo.setSharedUsageMode(val!),
              ),
            ],
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? colors.surfaceVariant.withOpacity(0.35) : theme.cardColor;
    final name = member['name'] ?? 'Unknown';
    final role = (member['role'] ?? 'member').toString().toUpperCase();
    final isOwner = role == 'OWNER';
    final avatarColor = _getAvatarColor(name);

    return BouncingButton( 
      onTap: () {}, 
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
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
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: colors.onSurface,
                    ),
                  ),
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
