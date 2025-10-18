import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// نص الاسم (firstName + lastName) ينسحب تلقائيًا من users/{uid}.
/// لو المستخدم مو داخل، يعرض Guest. ولو ما فيه اسم محفوظ، يعرض الإيميل.
class CaregiverNameText extends StatelessWidget {
  final TextStyle? style;
  const CaregiverNameText({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Text('Guest', style: style);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Text('Loading…', style: style);
        }
        final data = snap.data?.data();
        final first = (data?['firstName'] ?? '').toString().trim();
        final last  = (data?['lastName']  ?? '').toString().trim();
        final email = (data?['email']     ?? '').toString().trim();

        final name = [first, last].where((s) => s.isNotEmpty).join(' ');
        return Text(
          name.isNotEmpty ? name : (email.isNotEmpty ? email : 'Guest'),
          style: style,
        );
      },
    );
  }
}

/// نص الدور (role) من users/{uid}. افتراضيًا "Caregiver" لو ما لُقي شيء.
class RoleSubtitleText extends StatelessWidget {
  final TextStyle? style;
  const RoleSubtitleText({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Text('Caregiver', style: style); // fallback
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return Text('Caregiver', style: style);
        final role = (snap.data!.data()?['role'] ?? '').toString().toLowerCase().trim();
        final label = role == 'elderly'
            ? 'Elderly'
            : 'Caregiver'; // أي شيء غير elderly اعتبره caregiver
        return Text(label, style: style);
      },
    );
  }
}
