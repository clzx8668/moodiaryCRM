import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:moodiary/features/block/models/block.dart';

/// 智能实体卡片：解析 Block 内容 JSON，渲染可点击的实体摘要。
class EntityCard extends StatelessWidget {
  final Block block;

  const EntityCard({super.key, required this.block});

  /// 实体内容解析（容错：非 JSON 时回退原文）
  static Map<String, dynamic>? parseContent(Block block) {
    try {
      final decoded = jsonDecode(block.content);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final data = parseContent(block);
    if (data == null) {
      return Text(
        block.content,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }
    final name = (data['name'] as String?)?.trim() ?? '';
    final entityType = (data['entity_type'] as String?)?.trim() ?? '';
    final status = (data['status'] as String?)?.trim() ?? '';
    final company = (data['company'] as String?)?.trim() ?? '';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(
          entityType == 'company'
              ? Icons.apartment_rounded
              : Icons.person_rounded,
          size: 18,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(name.isEmpty ? '未命名实体' : name),
      subtitle: Text(
        [
          if (entityType.isNotEmpty) entityType,
          if (company.isNotEmpty) company,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: status.isEmpty
          ? null
          : Chip(
              label: Text(status),
              labelStyle: TextStyle(
                fontSize: 11,
                color: colorScheme.onSecondaryContainer,
              ),
              backgroundColor: colorScheme.secondaryContainer,
              side: BorderSide.none,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}
