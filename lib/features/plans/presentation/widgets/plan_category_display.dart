import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/plan.dart';

extension PlanCategoryDisplay on PlanCategory {
  String get label {
    switch (this) {
      case PlanCategory.vacation:
        return 'Vacation';
      case PlanCategory.birthday:
        return 'Birthday';
      case PlanCategory.celebration:
        return 'Celebration';
      case PlanCategory.roadTrip:
        return 'Road Trip';
      case PlanCategory.dinner:
        return 'Dinner';
      case PlanCategory.gathering:
        return 'Gathering';
      case PlanCategory.school:
        return 'School';
      case PlanCategory.graduation:
        return 'Graduation';
      case PlanCategory.workEvent:
        return 'Work Event';
      case PlanCategory.familyEvent:
        return 'Family Event';
      case PlanCategory.personalMilestone:
        return 'Personal Milestone';
      case PlanCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case PlanCategory.vacation:
        return Icons.flight_takeoff_rounded;
      case PlanCategory.birthday:
        return Icons.cake_rounded;
      case PlanCategory.celebration:
        return Icons.celebration_rounded;
      case PlanCategory.roadTrip:
        return Icons.directions_car_filled_rounded;
      case PlanCategory.dinner:
        return Icons.restaurant_rounded;
      case PlanCategory.gathering:
        return Icons.groups_rounded;
      case PlanCategory.school:
        return Icons.school_rounded;
      case PlanCategory.graduation:
        return Icons.workspace_premium_rounded;
      case PlanCategory.workEvent:
        return Icons.work_rounded;
      case PlanCategory.familyEvent:
        return Icons.family_restroom_rounded;
      case PlanCategory.personalMilestone:
        return Icons.emoji_events_rounded;
      case PlanCategory.other:
        return Icons.event_rounded;
    }
  }
}
