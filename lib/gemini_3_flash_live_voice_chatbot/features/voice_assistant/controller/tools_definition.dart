part of '../voice_assistant_controller.dart';

/// Tool schema sent to Gemini Live (what the model may call).
/// Tool declarations sent to Gemini Live (library-private).
List<Map<String, dynamic>> buildVoiceAssistantTools() {
  return [
    {
      'name': 'getAllData',
      'description': 'Compact summary of all subjects: name, topic counts, pending revisions, today\'s classes, revisions due today, and today\'s daily routine. Call first for overview questions; use getSubjectDetail for one subject\'s full topic list.',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'getSubjectDetail',
          'description': 'Get full topic list with revision counts and next revision date for ONE subject by name. Use when the user asks about a specific subject\'s topics or revision schedule.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
        },
        'required': ['subjectName'],
      },
    },
    {
      'name': 'addSubjectsBulk',
      'description': 'Add one or more subjects, each optionally with topics and nested subtopics, in ONE call. Use for any subject-add request. topics[] entries may be strings or {"name":"...","subtopics":[...]} objects.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjects': {
            'type': 'array',
            'description': 'One entry per subject to add',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string', 'description': 'Subject name'},
                'topics': {
                  'type': 'array',
                  'description':
                      'Topic names as strings, or {"name":"...","subtopics":["..."]} objects.',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'name': {'type': 'string', 'description': 'Topic name'},
                      'subtopics': {
                        'type': 'array',
                        'items': {'type': 'string'},
                        'description': 'Subtopic names under this topic',
                      },
                    },
                    'required': ['name'],
                  },
                },
                'color': {'type': 'string', 'description': 'Optional hex color code like #87CEEB'},
                'confirmNewTopics': {
                  'type': 'boolean',
                  'description': 'Escape hatch: true only when the user confirmed new subject-level topics despite a pending subtopic question.',
                },
              },
              'required': ['name'],
            },
          },
          'confirmNewTopics': {
            'type': 'boolean',
            'description': 'Escape hatch: true only when the user confirmed new subject-level topics despite a pending subtopic question.',
          },
        },
        'required': ['subjects'],
      },
    },
    {
      'name': 'addSubject',
      'description': 'Add a new subject with no topics yet. For subject+topics together, use addSubjectsBulk.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Subject name'},
          'color': {'type': 'string', 'description': 'Hex color code like #87CEEB'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'addTopic',
      'description': 'Create ONE topic under a subject — or, with parentTopicName set, ONE subtopic under an existing topic. For multiple subtopics use addSubtopics.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name (optional if contextSubject is provided)'},
          'name': {'type': 'string', 'description': 'Topic name (or subtopic name when parentTopicName is set)'},
          'parentTopicName': {
            'type': 'string',
            'description': 'Existing parent topic name — creates a subtopic under it, not a subject-level topic.',
          },
          'confirmNewTopics': {
            'type': 'boolean',
            'description': 'Escape hatch: true only when the user confirmed new subject-level topics despite a pending subtopic question.',
          },
        },
        'required': ['name'],
      },
    },
    {
      'name': 'addSubtopics',
      'description': 'Create subtopics under ONE existing topic. topicName is the parent topic; names are the user-provided subtopic names.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject that owns the parent topic'},
          'topicName': {'type': 'string', 'description': 'Existing parent topic name'},
          'names': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Subtopic names from the user',
          },
        },
        'required': ['subjectName', 'topicName', 'names'],
      },
    },
    {
      'name': 'addMultipleTopics',
      'description': 'Create multiple top-level topics under a subject. topics[] may be strings or {"name":"...","subtopics":[...]} objects.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topics': {
            'type': 'array',
            'description':
                'Topic names as strings, or {"name":"...","subtopics":[...]} objects.',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string', 'description': 'Topic name'},
                'subtopics': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'Subtopics under this topic',
                },
              },
              'required': ['name'],
            },
          },
          'parentTopicName': {
            'type': 'string',
            'description': 'If set, names become subtopics under this topic (routed to addSubtopics).',
          },
          'confirmNewTopics': {
            'type': 'boolean',
            'description': 'Escape hatch: true only when the user confirmed new subject-level topics despite a pending subtopic question.',
          },
        },
        'required': ['subjectName', 'topics'],
      },
    },
    {
      'name': 'deleteAllSubjects',
      'description': 'Delete ALL subjects and their topics. Use when user says to delete everything or all subjects.',
      'parameters': {
        'type': 'object',
        'properties': {},
      },
    },
    {
      'name': 'deleteSubjectByName',
      'description': 'Delete a subject by its NAME. Use when user says to delete a specific subject by name.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Subject name to delete'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'deleteTopicByName',
      'description': 'Delete a topic by its NAME from a subject.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name to delete'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
    {
      'name': 'getTopicStatus',
      'description': 'Get detailed status of a topic: first read completion, revision progress (which revisions are completed/pending, next revision number and day). Use when the user asks about a topic\'s progress or before performing any completion action.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
    {
      'name': 'markFirstReadCompleted',
      'description': 'Mark a topic\'s first read as completed. Use when user says "mark the topic as completed", "I\'ve read the topic", "first read done" or similar. The topic moves to revision tracking after this.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
    {
      'name': 'markRevisionCompleted',
      'description': 'Mark the NEXT sequential revision as completed for a topic. Follows strict order: 1st(1day) → 2nd(3days) → 3rd(7days) → 4th(14days) → 5th(30days) → 6th(90days). Cannot skip incomplete previous revisions. Use when user says "mark revision as completed", "complete the revision", or similar.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topicName': {'type': 'string', 'description': 'Topic name'},
        },
        'required': ['subjectName', 'topicName'],
      },
    },
    {
      'name': 'getAllTopicsRevisionDates',
      'description': 'Get revision dates for ALL topics in a subject. Use when user asks "what are all the revision dates?", "show me all revision dates", "when are all revisions due?", or similar. Returns each topic with its 6 revision dates and status.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
        },
        'required': ['subjectName'],
      },
    },
    {
      'name': 'registerClassRoutine',
      'description': 'Register a class routine / timetable entry. Location is optional — pass it as one string in "location" (e.g. "UB43A"); do not ask separately for building/floor/room.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name for the class'},
          'startTime': {'type': 'string', 'description': 'Start time in HH:MM 24h format, e.g. "09:00" or "14:30"'},
          'endTime': {'type': 'string', 'description': 'End time HH:mm 24h. Auto-calculate from duration if the user gives one (e.g. 9:00 + 1.5h = 10:30).'},
          'durationMinutes': {'type': 'integer', 'description': 'Duration of the class in minutes, e.g. 60, 90, 120'},
          'dates': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of dates for the class in YYYY-MM-DD format, e.g. ["2026-09-05","2026-09-08"]. For recurring classes, use recurringDays instead.',
          },
          'recurringDays': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'Days of week (1=Mon..7=Sun). Use this OR dates, not both.',
          },
          'location': {'type': 'string', 'description': 'Single location string, e.g. "UB43A". Prefer this over building/floor/room.'},
          'building': {'type': 'string', 'description': 'Optional. Prefer "location" when the user gives a single string.'},
          'floor': {'type': 'string', 'description': 'Floor number (optional).'},
          'room': {'type': 'string', 'description': 'Room number (optional).'},
          'notes': {'type': 'string', 'description': 'Optional notes about the class'},
        },
        'required': ['subjectName', 'startTime', 'durationMinutes'],
      },
    },
    {
      'name': 'registerDailyRoutine',
      'description': 'Register a daily study routine for a date. Pass ordered work blocks in items[]; the app auto-inserts meals, freshen-up, and gap fills. Call getAllData first for real subject/topic names, due revisions, and today\'s classes.',
      'parameters': {
        'type': 'object',
        'properties': {
          'date': {'type': 'string', 'description': 'Date for this routine in YYYY-MM-DD format. Use today if not specified.'},
          'items': {
            'type': 'array',
            'description': 'Ordered work blocks. The app auto-inserts meals, freshen-up, and gap fills.',
            'items': {
              'type': 'object',
              'properties': {
                'time': {'type': 'string', 'description': 'Start time, 24h HH:mm, e.g. "14:30".'},
                'subject': {'type': 'string', 'description': 'Subject name'},
                'topic': {'type': 'string', 'description': 'Topic name within the subject'},
                'type': {'type': 'string', 'description': 'Block type: revision | study | first_read | question_practice | break | nap | class.'},
                'durationMinutes': {'type': 'integer', 'description': 'Minutes: revision 30, study/first_read 50, question_practice 50, break 10, nap 20-25.'},
                'notes': {'type': 'string', 'description': 'Optional notes'},
              },
              'required': ['time', 'subject', 'topic', 'type', 'durationMinutes'],
            },
          },
        },
        'required': ['items'],
      },
    },
    {
      'name': 'deleteClassRoutine',
      'description': 'Delete a class routine by subject name. Ask for the subject name if several exist.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name of the class routine to delete'},
        },
        'required': ['subjectName'],
      },
    },
    {
      'name': 'deleteDailyRoutine',
      'description': 'Delete all daily routine items for a date (default today).',
      'parameters': {
        'type': 'object',
        'properties': {
          'date': {'type': 'string', 'description': 'Date of the daily routine to delete in YYYY-MM-DD format. Use today if not specified.'},
        },
        'required': [],
      },
    },
  ];
}
