import 'package:flutter/material.dart';
import '../models.dart';

class SessionDetailSheet extends StatelessWidget {
  final Course course;
  final Session session;
  final String sessionType;

  const SessionDetailSheet({
    super.key,
    required this.course,
    required this.session,
    required this.sessionType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(course.courseCode, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(course.courseName, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          if (course.note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo[100]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note_alt, size: 18, color: Colors.indigo[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      course.note.trim(),
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 24),
          _detailRow(Icons.category, 'Type', sessionType),
          _detailRow(Icons.qr_code, 'CRN', session.crn.toString()),
          _detailRow(Icons.tag, 'Section', session.sessionCode),
          _detailRow(Icons.calendar_today, 'Day', session.sessionDay),
          _detailRow(Icons.access_time, 'Time', '${session.sessionStartTime} - ${session.sessionEndTime}'),
          if (session.locked)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Chip(
                avatar: Icon(Icons.lock, size: 16),
                label: Text('Locked Session'),
                backgroundColor: Colors.orange,
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
