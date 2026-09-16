import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/person.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.person,
    this.size = 40,
    this.selected = false,
  });

  final Person person;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = person.photoUrl != null && person.photoUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected ? Border.all(color: AppColors.primary, width: 2.5) : null,
        color: AppColors.primaryLight,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: person.photoUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _Initials(person: person, size: size),
            )
          : _Initials(person: person, size: size),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.person, required this.size});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        person.initials,
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
