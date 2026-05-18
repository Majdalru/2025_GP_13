import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';

import '/medmain.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import '../models/medication.dart';

// ── Data models ───────────────────────────────────────────────────────────────
class _TodaySummary {
  final String? nextName;
  final DateTime? nextTime;
  final int onTime;
  final int late;
  final int missed;
  final int total;
  final int completed;

  _TodaySummary({
    this.nextName,
    this.nextTime,
    this.onTime = 0,
    this.late = 0,
    this.missed = 0,
    this.total = 0,
    this.completed = 0,
  });
}

class _NextDose {
  final String name;
  final DateTime when;
  final String? doseForm;
  final String? doseStrength;
  const _NextDose(this.name, this.when, {this.doseForm, this.doseStrength});
}

// ── Streams ───────────────────────────────────────────────────────────────────
Stream<_TodaySummary> _todaySummaryStream(String elderlyId) {
  final fs = FirebaseFirestore.instance;
  final now = DateTime.now();
  final todayKey = DateFormat('yyyy-MM-dd').format(now);
  final todayName = DateFormat('EEEE').format(now);

  return fs.collection('medications').doc(elderlyId).snapshots().asyncMap((
    medsSnap,
  ) async {
    final meds = <Medication>[];
    if (medsSnap.exists && medsSnap.data()?['medsList'] != null) {
      final all = (medsSnap.data()!['medsList'] as List)
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList();
      meds.addAll(
        all.where(
          (m) => m.days.contains('Every day') || m.days.contains(todayName),
        ),
      );
    }
    if (meds.isEmpty) return _TodaySummary();

    Map<String, dynamic> log = {};
    final logDoc = await fs
        .collection('medication_log')
        .doc(elderlyId)
        .collection('daily_log')
        .doc(todayKey)
        .get();
    if (logDoc.exists) log = logDoc.data() ?? {};

    int onTime = 0, late = 0, missed = 0, total = 0;
    final nowDT = DateTime.now();
    final doses = <Map<String, dynamic>>[];

    for (final med in meds) {
      for (int i = 0; i < med.times.length; i++) {
        total++;
        final t = med.times[i];
        final when = DateTime(
          nowDT.year,
          nowDT.month,
          nowDT.day,
          t.hour,
          t.minute,
        );
        final logKey = '${med.id}_$i';
        final dlog = log[logKey] as Map<String, dynamic>?;

        String status = 'upcoming';
        if (dlog != null) {
          status = (dlog['status'] as String?) ?? 'upcoming';
        } else if (nowDT.isAfter(when.add(const Duration(minutes: 10)))) {
          status = 'missed';
        }

        if (status == 'taken_on_time') {
          onTime++;
        } else if (status == 'taken_late') {
          late++;
        } else if (status == 'missed') {
          missed++;
        }

        doses.add({
          'name': med.name,
          'when': when,
          'status': status,
          'doseForm': med.doseForm,
          'doseStrength': med.doseStrength,
        });
      }
    }

    final completed = onTime + late;

    String? nextName;
    DateTime? nextTime;
    final upcoming =
        doses
            .where(
              (d) =>
                  d['status'] == 'upcoming' &&
                  !(d['when'] as DateTime).isBefore(nowDT),
            )
            .toList()
          ..sort(
            (a, b) => (a['when'] as DateTime).compareTo(b['when'] as DateTime),
          );

    if (upcoming.isNotEmpty) {
      nextName = upcoming.first['name'] as String;
      nextTime = upcoming.first['when'] as DateTime;
    }

    return _TodaySummary(
      nextName: nextName,
      nextTime: nextTime,
      onTime: onTime,
      late: late,
      missed: missed,
      total: total,
      completed: completed,
    );
  });
}

Stream<List<_NextDose>> _nextDosesStream(String elderlyId) {
  final fs = FirebaseFirestore.instance;
  final now = DateTime.now();
  final todayKey = DateFormat('yyyy-MM-dd').format(now);
  final todayName = DateFormat('EEEE').format(now);

  return fs.collection('medications').doc(elderlyId).snapshots().asyncMap((
    medsSnap,
  ) async {
    final meds = <Medication>[];
    if (medsSnap.exists && medsSnap.data()?['medsList'] != null) {
      final all = (medsSnap.data()!['medsList'] as List)
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList();
      meds.addAll(
        all.where(
          (m) => m.days.contains('Every day') || m.days.contains(todayName),
        ),
      );
    }
    if (meds.isEmpty) return const <_NextDose>[];

    Map<String, dynamic> log = {};
    final logDoc = await fs
        .collection('medication_log')
        .doc(elderlyId)
        .collection('daily_log')
        .doc(todayKey)
        .get();
    if (logDoc.exists) log = logDoc.data() ?? {};

    final nowDT = DateTime.now();
    final nextList = <_NextDose>[];

    for (final med in meds) {
      for (int i = 0; i < med.times.length; i++) {
        final t = med.times[i];
        final when = DateTime(
          nowDT.year,
          nowDT.month,
          nowDT.day,
          t.hour,
          t.minute,
        );
        final logKey = '${med.id}_$i';
        final dlog = log[logKey] as Map<String, dynamic>?;

        String status = 'upcoming';
        if (dlog != null) {
          status = (dlog['status'] as String?) ?? 'upcoming';
        } else if (nowDT.isAfter(when.add(const Duration(minutes: 10)))) {
          status = 'missed';
        }

        if (status == 'upcoming' && !when.isBefore(nowDT)) {
          nextList.add(
            _NextDose(
              med.name,
              when,
              doseForm: med.doseForm,
              doseStrength: med.doseStrength,
            ),
          );
        }
      }
    }

    nextList.sort((a, b) => a.when.compareTo(b.when));
    return nextList;
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────
class HomePage extends StatelessWidget {
  final String elderlyId;
  final String elderlyName;
  final VoidCallback onTapArrowToMedsSummary;
  final VoidCallback onTapArrowToMedmain;
  final VoidCallback onTapEmergency;

  const HomePage({
    super.key,
    required this.elderlyId,
    required this.elderlyName,
    required this.onTapArrowToMedsSummary,
    required this.onTapArrowToMedmain,
    required this.onTapEmergency,
  });

  // ── Palette ───────────────────────────────────────────────────────────────
  static const _kNavy = Color(0xFF102E50);
  static const _kMint = Color(0xFF3A8C78);
  static const _kGold = Color(0xFFF5C35D);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final formattedDate = DateFormat(
      'd MMM',
    ).format(DateTime.now()).toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Med status card ───────────────────────────────────────────
        StreamBuilder<_TodaySummary>(
          stream: _todaySummaryStream(elderlyId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingCard();
            }
            final s = snap.data ?? _TodaySummary();
            return _MedStatusCard(
              summary: s,
              formattedDate: formattedDate,
              elderlyName: elderlyName,
              onTapMedmain: onTapArrowToMedmain,
              onTapMedsSummary: onTapArrowToMedsSummary,
              loc: loc,
            );
          },
        ),

        const SizedBox(height: 12),

        // ── Upcoming doses card ───────────────────────────────────────
        StreamBuilder<List<_NextDose>>(
          stream: _nextDosesStream(elderlyId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const _LoadingCard(height: 120);
            }
            final doses = snap.data ?? [];
            return _UpcomingDosesCard(doses: doses, loc: loc);
          },
        ),
      ],
    );
  }
}

// ── Med status card ───────────────────────────────────────────────────────────
class _MedStatusCard extends StatelessWidget {
  final _TodaySummary summary;
  final String formattedDate;
  final String elderlyName;
  final VoidCallback onTapMedmain;
  final VoidCallback onTapMedsSummary;
  final AppLocalizations loc;

  const _MedStatusCard({
    required this.summary,
    required this.formattedDate,
    required this.elderlyName,
    required this.onTapMedmain,
    required this.onTapMedsSummary,
    required this.loc,
  });

  static const _kNavy = Color(0xFF102E50);
  static const _kMint = Color(0xFF3A8C78);

  @override
  Widget build(BuildContext context) {
    final total = summary.total;
    final completed = summary.completed;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.todayLabel(formattedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2340),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loc.viewingDailyMeds(elderlyName),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Go to med list button
                GestureDetector(
                  onTap: onTapMedmain,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2F5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: _kNavy,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      total == 0
                          ? loc.noUpcomingMeds
                          : loc.dosesCompletedOf(completed, total),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      total > 0 ? '${(progress * 100).round()}%' : '--',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEEF0F3),
                    valueColor: const AlwaysStoppedAnimation<Color>(_kMint),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Stats row — fixed height avoids IntrinsicHeight overflow
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F2F5))),
            ),
            height: 64,
            child: Row(
              children: [
                _StatCell(
                  count: summary.onTime,
                  label: loc.onTimeStatus,
                  color: const Color(0xFF3A8C78),
                ),
                Container(width: 1, color: const Color(0xFFF0F2F5)),
                _StatCell(
                  count: summary.late,
                  label: loc.takenLate,
                  color: const Color(0xFFE08A2E),
                ),
                Container(width: 1, color: const Color(0xFFF0F2F5)),
                _StatCell(
                  count: summary.missed,
                  label: loc.missedStatus,
                  color: Colors.red.shade600,
                ),
              ],
            ),
          ),

          // Monthly overview link
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F2F5))),
            ),
            child: TextButton(
              onPressed: onTapMedsSummary,
              child: Text(
                loc.monthlyOverview,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _kNavy,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat cell ─────────────────────────────────────────────────────────────────
class _StatCell extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatCell({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming doses card ───────────────────────────────────────────────────────
class _UpcomingDosesCard extends StatelessWidget {
  final List<_NextDose> doses;
  final AppLocalizations loc;

  const _UpcomingDosesCard({required this.doses, required this.loc});

  String _doseSubtitle(_NextDose d) {
    final parts = <String>[];
    if (d.doseForm != null && d.doseForm!.isNotEmpty) parts.add(d.doseForm!);
    if (d.doseStrength != null && d.doseStrength!.isNotEmpty)
      parts.add(d.doseStrength!);
    return parts.join(' · ');
  }

  String _badge(_NextDose d) {
    final diff = d.when.difference(DateTime.now()).inMinutes;
    if (diff <= 30) return loc.soon;
    return loc.later;
  }

  Color _badgeColor(_NextDose d) {
    final diff = d.when.difference(DateTime.now()).inMinutes;
    if (diff <= 30) return const Color(0xFFFEF6E4);
    return const Color(0xFFF0F2F5);
  }

  Color _badgeTextColor(_NextDose d) {
    final diff = d.when.difference(DateTime.now()).inMinutes;
    if (diff <= 30) return const Color(0xFFC89A30);
    return const Color(0xFF6B7280);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              loc.upcomingDoses.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (doses.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.grey.shade300,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loc.allDosesCompleted,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            )
          else
            ...doses.take(3).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final dose = entry.value;
              final timeStr = DateFormat('h:mm a').format(dose.when);
              final sub = _doseSubtitle(dose);

              return Column(
                children: [
                  if (i > 0)
                    const Divider(
                      height: 1,
                      indent: 62,
                      endIndent: 0,
                      color: Color(0xFFF0F2F5),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F2),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.medication_outlined,
                            color: Color(0xFF3A8C78),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dose.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A2340),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (sub.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  sub,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF102E50),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _badgeColor(dose),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _badge(dose),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _badgeTextColor(dose),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),

          if (doses.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '+${doses.length - 3} ${loc.moreDoses}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ── Loading placeholder ───────────────────────────────────────────────────────
class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({this.height = 220});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
