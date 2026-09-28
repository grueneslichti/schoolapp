import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:logging/logging.dart';

class ApiService {
  static final Logger _log = Logger ('ApiService');
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // WICHTIG: Base URL anpassen!!!
  //Server_IP_ADRESSE!!!
  //Eventuell in env schreiben
  static const String baseUrl = '';

  static String fileUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final serverUrl = baseUrl.replaceFirst('/api/v1', '');
    return '$serverUrl${path.startsWith('/') ? path : '/$path'}';
  }
  String? _token;
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
  }
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    _token = token;
  }
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _token = null;
  }
  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }
  Future<Map<String, dynamic>?> login(String username, String password, String role) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login/$role');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': username,
          'password': password,
        },
      ).timeout(const Duration(seconds: 5), onTimeout: (){
        throw TimeoutException('Verbindung zum Server fehlgeschlagen');
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        await saveToken(token);
        return data;
      } else {
        _log.warning('Login fehlgeschlagen: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _log.warning('Netzwerkfehler beim Login: $e');
      return null;
    }
  }
  Future<http.Response> get(String endpoint) async {
    await loadToken();
    return await http.get(Uri.parse('$baseUrl$endpoint'), headers: _headers);
  }
  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    await loadToken();
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
  }
  Future<http.Response> put(String endpoint, Map<String, dynamic> body) async {
    await loadToken();
    return await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    );
  }
  Future<http.Response> delete(String endpoint) async {
    await loadToken();
    return await http.delete(Uri.parse('$baseUrl$endpoint'), headers: _headers);
  }
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    await loadToken(); // Stellt sicher, dass der Bearer-Token im Header ist
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: _headers,
        body: jsonEncode({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        _log.severe('Passwort-Änderung fehlgeschlagen: ${response.body}');
        return false;
      }
    } catch (e) {
      _log.severe('Netzwerkfehler beim Passwort ändern: $e');
      return false;
    }
  }
  Future<bool> requestPasswordReset(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/request-password-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  Future<List<dynamic>> getClassGrades(String classId) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/grades/class/$classId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _log.warning('Fehler beim Laden der Noten: ${response.body}');
        return [];
      }
    } catch (e) {
      _log.severe('Netzwerkfehler: $e');
      return [];
    }
  }
  Future<bool> createGrade({
    required String studentId,
    required String subject,
    required int value,
    String? description,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/grades/'),
        headers: _headers,
        body: jsonEncode({
          'student_id': studentId,
          'subject': subject,
          'value': value,
          'description': description,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      _log.warning('Fehler beim Erstellen der Note: $e');
      return false;
    }
  }
  Future<bool> deleteGrade(String gradeId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/grades/$gradeId'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      _log.warning('Fehler beim Löschen der Note: $e');
      return false;
    }
  }
  Future<List<dynamic>> getMyInbox({bool unreadOnly = false}) async {
    await loadToken();
    try {
      final url = unreadOnly
          ? '$baseUrl/feedbacks/inbox?unread_only=true'
          : '$baseUrl/feedbacks/inbox'; 
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<bool> markFeedbackAsRead(String feedbackId) async {
    await loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/feedbacks/inbox/$feedbackId/read'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  Future<bool> sendFeedback({
    required String message,
    String? category,
    bool isAnonymous = true,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/feedbacks/'),
        headers: _headers,
        body: jsonEncode({
          'message': message,
          'category': category,
          'is_anonymous': isAnonymous,
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      _log.warning('Fehler beim Senden: $e');
      return false;
    }
  }
  Future<Map<String, dynamic>> checkExamConflict({
    required String classId,
    required String subject,
    required String examDate,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exams/conflict-check'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'subject': subject,
          'exam_date': examDate,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'has_conflict': false, 'message': 'Prüfung fehlgeschlagen'};
      }
    } catch (e) {
      _log.severe('Fehler beim Konflikt-Check: $e');
      return {'has_conflict': false, 'message': 'Netzwerkfehler'};
    }
  }
  Future<Map<String, dynamic>?> createExam({
    required String classId,
    required String subject,
    required String examDate,
    String? description,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/exams/'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'subject': subject,
          'exam_date': examDate,
          'description': description,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        _log.warning('Fehler beim Erstellen: ${response.body}');
        return null;
      }
    } catch (e) {
      _log.severe('Netzwerkfehler: $e');
      return null;
    }
  }
  Future<List<dynamic>> getAllExams() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/exams/'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return [];
      }
    } catch (e) {
      _log.severe('Netzwerkfehler: $e');
      return [];
    }
  }
  Future<bool> deleteMyFeedback(String feedbackId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/feedbacks/my-feedbacks/$feedbackId'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
  Future<bool> deleteExam(String examId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/exams/$examId'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      _log.warning('Fehler beim Löschen: $e');
      return false;
    }
  }
  Future<List<dynamic>> getClasses() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/classes/'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _log.severe('Fehler beim Laden der Klassen: ${response.body}');
        return [];
      }
    } catch (e) {
      _log.severe('Netzwerkfehler: $e');
      return [];
    }
  }
  Future<Map<String, dynamic>?> completeFocusSession({
    required int plannedMinutes,
    required int actualMinutes,
    required bool completed,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/focus/complete'),
        headers: _headers,
        body: jsonEncode({
          'planned_minutes': plannedMinutes,
          'actual_minutes': actualMinutes,
          'completed': completed,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _log.warning('Fehler beim Fokus-Abschluss: ${response.body}');
        return null;
      }
    } catch (e) {
      _log.severe('Netzwerkfehler: $e');
      return null;
    }
  }
  Future<int> getMyXp() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/focus/my-xp'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['xp'] ?? 0;
      }
      return 0;
    } catch (e) {
     _log.warning('Fehler beim Laden der XP: $e');
      return 0;
    }
  }
  Future<List<dynamic>> getMyFriends() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/my-friends'),
        headers: _headers,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        _log.warning('Fehler beim Laden der Freunde: ${response.body}');
        return [];
      }
    } catch (e) {
      _log.severe('Netzwerkfehler: $e');
      return [];
    }
  }
  Future<Map<String, dynamic>> getRemainingXp() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/remaining-xp'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'remaining': 0, 'weekly_limit': 15, 'spent_this_week': 15};
    } catch (e) {
      _log.warning('Fehler: $e');
      return {'remaining': 0, 'weekly_limit': 15, 'spent_this_week': 15};
    }
  }
  Future<Map<String, dynamic>?> giveXpToFriend({
    required String receiverId,
    required int amount,
    String? message,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/give-xp'),
        headers: _headers,
        body: jsonEncode({
          'receiver_id': receiverId,
          'amount': amount,
          'message': message,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        _log.warning('Fehler: ${error['detail']}');
        return {'success': false, 'message': error['detail'] ?? 'Unbekannter Fehler'};
      }
    } catch (e) {
      _log.severe('Netzwerkfehler: $e');
      return null;
    }
  }
  Future<List<dynamic>> searchStudents(String query) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/search?q=$query'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      _log.warning('Suchfehler: $e');
      return [];
    }
  }
  Future<Map<String, dynamic>> sendFriendRequest(String receiverId) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request?receiver_id=$receiverId'),
        headers: _headers,
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'detail': 'Netzwerkfehler'};
    }
  }
  Future<List<dynamic>> getFriendRequests() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<bool> acceptFriendRequest(String requestId) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/requests/$requestId/accept'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  Future<bool> declineFriendRequest(String requestId) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/requests/$requestId/decline'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  Future<Map<String, dynamic>> getXpNotifications() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/xp-notifications'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'notifications': [], 'total_xp_received': 0, 'count': 0};
    } catch (e) {
      _log.warning('Fehler beim Laden der Benachrichtigungen: $e');
      return {'notifications': [], 'total_xp_received': 0, 'count': 0};
    }
  }
  Future<void> markXpNotificationsRead() async {
    await loadToken();
    try {
      await http.post(
        Uri.parse('$baseUrl/friends/xp-notifications/read'),
        headers: _headers,
      );
    } catch (e) {
      _log.warning('Fehler beim Markieren: $e');
    }
  }
  Future<Map<String, dynamic>> validateInvitationCode(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/registration/validate-code/${Uri.encodeComponent(code)}'),
      );
      if (response.statusCode == 200) {
        return {'valid': true, 'data': jsonDecode(response.body)};
      } else {
        final error = jsonDecode(response.body);
        return {'valid': false, 'detail': error['detail'] ?? 'Code ungültig'};
      }
    } catch (e) {
      return {'valid': false, 'detail': 'Netzwerkfehler'};
    }
  }
  Future<Map<String, dynamic>?> registerStudent({
    required String realName,
    required String invitationCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registration/register-student'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'real_name': realName,
          'invitation_code': invitationCode,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Registrierung fehlgeschlagen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<Map<String, dynamic>?> createInvitationCode({
    required String classId,
    required String code,
    int? maxUses,
    int expiresInDays = 30,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/registration/create-code'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'code': code,
          'max_uses': maxUses,
          'expires_in_days': expiresInDays,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Erstellen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<List<dynamic>> getMyInvitationCodes() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/registration/my-codes'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<bool> deactivateInvitationCode(String codeId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/registration/codes/$codeId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  Future<List<dynamic>> getTeacherClassSchedule(String classId) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schedule/teacher/class/$classId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      _log.warning('Fehler beim Laden des Stundenplans: $e');
      return [];
    }
  }
  Future<Map<String, dynamic>?> createTeacherScheduleEntry({
    required String classId,
    required String subject,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/schedule/teacher'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'subject': subject,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'room': room,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Erstellen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<bool> deleteTeacherScheduleEntry(String entryId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/schedule/teacher/$entryId'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
  Future<List<dynamic>> getMySchedule() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schedule/my-schedule'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      _log.warning('Fehler beim Laden des Stundenplans: $e');
      return [];
    }
  }
  Future<Map<String, dynamic>?> createStudentScheduleEntry({
    required String classId,
    required String subject,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/schedule/student'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'subject': subject,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'room': room,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Erstellen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<bool> deleteStudentScheduleEntry(String entryId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/schedule/student/$entryId'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
  Future<Map<String, dynamic>?> getMyInfo() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      _log.warning('Fehler beim Laden der User-Infos: $e');
      return null;
    }
  }
  Future<Map<String, dynamic>?> signalLessonEnd({
    required String classId,
    required String subject,
    int windowMinutes = 7,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lessons/signal-end'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'subject': subject,
          'window_minutes': windowMinutes,
        }),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<List<dynamic>> getUnratedToday() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lessons/unrated-today'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<dynamic>.from(data['unrated_signals'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<Map<String, dynamic>?> rateLesson({
    required String signalId,
    int? rating,
    bool isNeutral = false,
    String? comment,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/lessons/rate'),
        headers: _headers,
        body: jsonEncode({
          'signal_id': signalId,
          'rating': rating,
          'is_neutral': isNeutral,
          'comment': comment,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return Map<String, dynamic>.from(data);
      }
      return {'error': data['detail'] ?? 'Bewertung konnte nicht gespeichert werden'};
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<List<dynamic>> getClassLessonRatings(String classId) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/lessons/ratings/class/$classId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<bool> checkSdForgeAvailable() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/avatars/sdforge-status'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['available'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  Future<Map<String, dynamic>?> getMyAvatar() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/avatars/me'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Map<String, dynamic>?> uploadAvatar({
    required String imageBase64,
    bool applyAnimeStyle = false,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/avatars/upload'),
        headers: _headers,
        body: jsonEncode({
          'image_base64': imageBase64,
          'apply_anime_style': applyAnimeStyle,
        }),
      );     
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Hochladen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<Map<String, dynamic>?> regenerateAvatar({String? promptSuffix}) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/avatars/regenerate'),
        headers: _headers,
        body: jsonEncode({
          'prompt_suffix': promptSuffix,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler bei der KI-Generierung'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<Map<String, dynamic>?> switchAvatarVersion(String version) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/avatars/switch-version?version=$version'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Wechseln'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<List<dynamic>> getShopItems() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/items'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) { return []; }
  }
  Future<Map<String, dynamic>?> buyShopItem({
    required String shopItemId,
    required String color,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/buy'),
        headers: _headers,
        body: jsonEncode({
          'shop_item_id': shopItemId,
          'color': color,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<List<dynamic>> getMyAvatarItems() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/my-items'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) { return []; }
  }
  Future<Map<String, dynamic>?> toggleEquipItem(String itemId) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shop/equip/$itemId'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) { return null; }
  }
  Future<bool> updateItemPosition({
    required String itemId,
    required double posX,
    required double posY,
    required double scale,
  }) async {
    await loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/shop/position/$itemId'),
        headers: _headers,
        body: jsonEncode({
          'pos_x': posX,
          'pos_y': posY,
          'scale': scale,
        }),
      );
      return response.statusCode == 200;
    } catch (e) { return false; }
  }
  Future<List<Map<String, dynamic>>> getEquippedItems() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shop/my-items'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final items = jsonDecode(response.body) as List;
        // Nur ausgerüstete Items zurückgeben
        return items
            .where((i) => i['is_equipped'] == true)
            .map((i) => Map<String, dynamic>.from(i))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  } 
  Future<List<dynamic>> getClassTasks(String classId) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/class/$classId'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) { return []; }
  }
  Future<List<dynamic>> getMyTasks() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tasks/my-tasks'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) { return []; }
  }
  Future<Map<String, dynamic>?> createTask({
    required String classId,
    required String subject,
    required String title,
    String? description,
    required String dueDate,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks/'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'subject': subject,
          'title': title,
          'description': description,
          'due_date': dueDate,
        }),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Erstellen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<bool> deleteTask(String taskId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: _headers,
      );
      return response.statusCode == 204;
    } catch (e) { return false; }
  }
  Future<List<String>> getMySubjectsForClass(String classId) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assignments/my-subjects/$classId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['subjects'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<List<dynamic>> getMyAssignments() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assignments/my-assignments'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<Map<String, dynamic>?> completeTask(String taskId) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/complete'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) { return null; }
  }
  Future<Map<String, dynamic>?> uncompleteTask(String taskId) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/uncomplete'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) { return null; }
  }
  Future<bool> deleteFeedback(String feedbackId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/feedbacks/inbox/$feedbackId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  Future<Map<String, dynamic>?> bulkDeleteFeedbacks(List<String> feedbackIds) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/feedbacks/inbox/bulk-delete'),
        headers: _headers,
        body: jsonEncode({'feedback_ids': feedbackIds,}),
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<bool> checkMascotAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mascot/status'),
      );
      return response.statusCode == 200 && jsonDecode(response.body)['available'] == true;
    } catch (e) {
      return false;
    }
  }
  Future<String?> sendMascotMessage(
    String message,
    List<Map<String, String>> history,
  ) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mascot/chat'),
        headers: _headers,
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['reply'] as String?;
      }
      return null;
    } catch (e) {
      _log.severe('Mascot-Chat Fehler', e);
      return null;
    }
  }
  Future<String> getChatStorageKey() async {
    await loadToken();
    if (_token == null) return 'default';
    try {
      final parts = _token!.split('.');
      if (parts.length != 3) return 'default';
      String payload = parts[1];
      final padLength = (4 - payload.length % 4) % 4;
      payload = payload + ('=' * padLength);  
      final decoded = utf8.decode(base64Url.decode(payload));
      final data = jsonDecode(decoded);  
      final role = data['role'] ?? 'unknown';
      final userId = data['sub'] ?? 'unknown';
      return 'chat_${role}_$userId';
    } catch (e) {
      return 'chat_default';
    }
  }
  Future<Map<String, dynamic>?> setupSchool(String setupCode) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/schools/setup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'setup_code': setupCode}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'error': 'Ungültiger Setup-Code'};
  } catch (e) {
    return {'error': 'Verbindungsfehler'};
  }
}
  Future<Map<String, dynamic>?> getSchoolLoginBackground(String schoolId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/schools/$schoolId/login-background'),
      );
    
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Map<String, dynamic>> checkUpcomingExams() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/exams/has-upcoming'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'has_exams': false, 'count': 0};
    } catch (e) {
      return {'has_exams': false, 'count': 0};
    }
  }
  Future<List<dynamic>> getMyUpcomingExams() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/exams/my-upcoming'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<Map<String, dynamic>?> exportMyProfile() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/promotion/my-export'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Map<String, dynamic>?> loginTeacher(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/teacher'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        return data; // Enthält school_id, school_name, school_type, role, etc.
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Login fehlgeschlagen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
    Future<Map<String, dynamic>?> loginStudent(String identifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login/student'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        return data;
      } 
      else if (response.statusCode == 409) {
        final data = jsonDecode(response.body);
        final detail = data['detail'] is Map<String, dynamic>
            ? data['detail'] as Map<String, dynamic>
            : <String, dynamic>{};
        return {
          'requires_disambiguation': true,
          'options': detail['options'] ?? [],
          'password': password,
        };
      } 
      else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Login fehlgeschlagen'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<Map<String, dynamic>?> submitGameScore({
    required String gameType,
    required String difficulty,
    required int score,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/submit-score'),
        headers: _headers,
        body: jsonEncode({
          'game_type': gameType,
          'difficulty': difficulty,
          'score': score,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Speichern'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<Map<String, dynamic>?> checkChallengeStatus() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/status'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'can_play': false, 'message': 'Spiele sind momentan nicht verfügbar.'};
    } catch (e) {
      return {'can_play': false, 'message': 'Der Spielstatus konnte nicht geladen werden.'};
    }
  }

  Future<Map<String, dynamic>?> getClassHighscores({
    required String gameType,
    required String difficulty,
  }) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games/highscores/$gameType/$difficulty'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<List<dynamic>> getMyHighscores(String gameType) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games/my-highscores/$gameType'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['highscores'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<Map<String, dynamic>?> getFunctionTask({required String difficulty}) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games/functions/task?difficulty=$difficulty'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      final data = jsonDecode(response.body);
      return {
        'error': data['detail'] ?? 'Die Aufgabe konnte nicht geladen werden.',
      };
    } catch (e) {
      return {'error': 'Die Aufgabe konnte nicht geladen werden.'};
    }
  }
  Future<Map<String, dynamic>?> submitFunctionAnswer({
    required String answer,
    required String correctAnswer,
    required String difficulty,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/functions/submit?answer=$answer&correct_answer=$correctAnswer&difficulty=$difficulty'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Map<String, dynamic>?> getGraduationPhotoStatus() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/graduation-photo/status'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Map<String, dynamic>?> generateGraduationPhoto() async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/graduation-photo/generate'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<bool> declineGraduationPhoto() async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/graduation-photo/decline'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
   String getGraduationPhotoUrl() {
    return '$baseUrl/graduation-photo/image';
  }
  Future<List<dynamic>> getRandomizerClasses() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/randomizer/my-classes'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
   Future<Map<String, dynamic>?> generateRandomGroups({
    required String classId,
    required int numGroups,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/randomizer/generate'),
        headers: _headers,
        body: jsonEncode({
          'class_id': classId,
          'num_groups': numGroups,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['detail'] ?? 'Fehler beim Generieren'};
      }
    } catch (e) {
      return {'error': 'Netzwerkfehler: $e'};
    }
  }
  Future<Map<String, dynamic>?> getGameAccess(String gameType) async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games/access/$gameType'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Map<String, dynamic>?> startGameTrial(String gameType) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/start-trial/$gameType'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return null;
    } catch (e) {
      return null;
    }
  }
  Future<Map<String, dynamic>?> unlockGame(String gameType) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/games/unlock/$gameType'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      final error = jsonDecode(response.body);
      return {'error': error['detail'] ?? 'Fehler'};
    } catch (e) {
      return {'error': 'Netzwerkfehler'};
    }
  }
  Future<List<dynamic>> getTeacherContacts() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher-messages/contacts'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<List<dynamic>> getTeacherInbox() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher-messages/inbox'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<List<dynamic>> getTeacherSent() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher-messages/sent'),
        headers: _headers,
      );
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }
  Future<int> getTeacherUnreadCount() async {
    await loadToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teacher-messages/unread-count'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['unread_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
  Future<Map<String, dynamic>?> sendTeacherMessage({
    required String receiverId,
    required String message,
    String? subject,
  }) async {
    await loadToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teacher-messages/send'),
        headers: _headers,
        body: jsonEncode({
          'receiver_id': receiverId,
          'message': message,
          if (subject != null && subject.isNotEmpty) 'subject': subject,
        }),
      );
      if (response.statusCode == 201) return jsonDecode(response.body);
      final error = jsonDecode(response.body);
      return {'error': error['detail'] ?? 'Fehler beim Senden'};
    } catch (e) {
      return {'error': 'Netzwerkfehler'};
    }
  }
  Future<bool> markTeacherMessageRead(String messageId) async {
    await loadToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/teacher-messages/$messageId/read'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  Future<bool> deleteTeacherMessage(String messageId) async {
    await loadToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/teacher-messages/$messageId'),
        headers: _headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}