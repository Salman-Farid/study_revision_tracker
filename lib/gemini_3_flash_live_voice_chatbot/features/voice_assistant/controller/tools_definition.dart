part of '../voice_assistant_controller.dart';

/// Tool schema sent to Gemini Live (what the model may call).
/// Tool declarations sent to Gemini Live (library-private).
List<Map<String, dynamic>> buildVoiceAssistantTools() {
  return [
    {
      'name': 'getAllData',
      'description': 'Get a compact SUMMARY of all subjects: name, topic count, pending revision count. Call this first for "what subjects/how many/overview" questions. For topic-level detail of ONE subject, call getSubjectDetail instead.',
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
      'description': 'Add one or more subjects, each optionally with topics (and optional nested SUBTOPICS under a topic), in ONE call. Use for ANY subject-add request. topics[] entries may be strings OR objects {name, subtopics:[...]}. HIERARCHY: Subject → Topic → Subtopic. A subtopic is NEVER a subject-level topic. After topics are created you MUST ask the user if they want subtopics under them (unless already provided in the same call). If blocked for hierarchy, ask the subtopic question or retry with confirmNewTopics: true only when the user wants new subject-level topics. Topics stay in first read until markFirstReadCompleted.',
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
                      'Topic names as strings, or objects {"name": "...", "subtopics": ["...", "..."]} when the user already listed subtopics UNDER a topic.',
                  'items': {
                    'type': 'object',
                    'properties': {
                      'name': {'type': 'string', 'description': 'TOP-LEVEL topic name under this subject'},
                      'subtopics': {
                        'type': 'array',
                        'items': {'type': 'string'},
                        'description': 'SUBTOPIC names UNDER this topic — not under the subject',
                      },
                    },
                    'required': ['name'],
                  },
                },
                'color': {'type': 'string', 'description': 'Optional hex color code like #87CEEB'},
                'confirmNewTopics': {
                  'type': 'boolean',
                  'description': 'Set true ONLY when the user confirmed they want NEW subject-level topics while a subtopic question is still pending',
                },
              },
              'required': ['name'],
            },
          },
          'confirmNewTopics': {
            'type': 'boolean',
            'description': 'Top-level escape hatch: true only after the user wants new subject-level topics despite a pending "want subtopics?" question',
          },
        },
        'required': ['subjects'],
      },
    },
    {
      'name': 'addSubject',
      'description': 'Add a new study subject with NO topics yet. Use only when the user wants just the subject, not topics too — for subject+topics together use addSubjectsBulk instead.',
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
      'description': 'Creates ONE topic. WITHOUT parentTopicName → TOP-LEVEL topic under a SUBJECT. WITH parentTopicName → SUBTOPIC under that existing TOPIC (preferred path is still addSubtopics for multiple names). HIERARCHY: Subject → Topic → Subtopic. After EVERY successful TOP-LEVEL addTopic you MUST ask (ONE language): "Do you want any subtopics under <topic>?" then WAIT. Never skip. If user asked for subtopics under an existing topic → addSubtopics (or parentTopicName here) — never a subject-level topic. If the call is blocked as hierarchy_pending_subtopic_question, ask that question first or use confirmNewTopics: true only for genuine new topics. Parent with children is Done only when ALL subtopics finish first-read + all 6 revisions.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name (optional if contextSubject is provided)'},
          'name': {'type': 'string', 'description': 'Topic name, or subtopic name when parentTopicName is set'},
          'parentTopicName': {
            'type': 'string',
            'description': 'EXISTING parent TOPIC name — when set, creates a SUBTOPIC under that topic, NOT a subject-level topic',
          },
          'confirmNewTopics': {
            'type': 'boolean',
            'description': 'true ONLY when the user confirmed a new subject-level topic while a subtopic question is pending',
          },
        },
        'required': ['name'],
      },
    },
    {
      'name': 'addSubtopics',
      'description': 'THE tool for subtopics. MUST USE when user wants subtopics UNDER a topic (e.g. "AI er niche subtopic add koro", "add subtopics under Artificial Intelligence", "topic er bhitore subtopic", "X under Y"). Creates children UNDER one existing TOPIC — NOT subject-level topics. Subtopic ≠ Topic. topicName is the PARENT topic; names are user-provided subtopic names only. If topic missing, call getSubjectDetail — never fall back to addTopic/addMultipleTopics for those names. Parent stays first-read until all subtopics complete the full revision process. After success confirm in ONE language; ask once if more subtopics are wanted under that parent.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject that owns the parent topic'},
          'topicName': {'type': 'string', 'description': 'EXISTING parent TOPIC name — subtopics go under THIS topic'},
          'names': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Subtopic names the user listed (must be user-provided)',
          },
        },
        'required': ['subjectName', 'topicName', 'names'],
      },
    },
    {
      'name': 'addMultipleTopics',
      'description': 'Multiple TOPICS under a SUBJECT. topics[] may include nested subtopics as {name, subtopics:[...]}. If the user said subtopics under a topic, call addSubtopics (or set parentTopicName) — do NOT create subject-level topics for those names. After successful top-level creates you MUST ask "Do you want any subtopics under <names>?" and WAIT. Blocked hierarchy_pending_subtopic_question → ask first, or confirmNewTopics: true only for genuine new topics.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name'},
          'topics': {
            'type': 'array',
            'description':
                'Topic names as strings, or objects {"name":"...","subtopics":["..."]} when subtopics under a topic are already known',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string', 'description': 'TOP-LEVEL topic name'},
                'subtopics': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'description': 'SUBTOPICS under this topic — not under the subject',
                },
              },
              'required': ['name'],
            },
          },
          'parentTopicName': {
            'type': 'string',
            'description': 'If set, these names are SUBTOPICS under this existing topic — routed to addSubtopics',
          },
          'confirmNewTopics': {
            'type': 'boolean',
            'description': 'true ONLY when user confirmed new subject-level topics while a subtopic question is pending',
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
      'description': 'Register a class routine / timetable entry. Use when user says "I have class", "add my class schedule", "my class is at...", "I have a lecture in room...", or wants to set up their class timetable. Location is optional — user can say it however they want like "UB43A" or "UB20A 3rd floor room 301". If they give a single word like "UB43A", use the "location" field. Do NOT ask separately for building/floor/room.',
      'parameters': {
        'type': 'object',
        'properties': {
          'subjectName': {'type': 'string', 'description': 'Subject name for the class'},
          'startTime': {'type': 'string', 'description': 'Start time in HH:MM 24h format, e.g. "09:00" or "14:30"'},
          'endTime': {'type': 'string', 'description': 'End time in HH:MM 24h format. Auto-calculate if user gives duration (e.g. 9:00 + 1.5h = 10:30).'},
          'durationMinutes': {'type': 'integer', 'description': 'Duration of the class in minutes, e.g. 60, 90, 120'},
          'dates': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'List of dates for the class in YYYY-MM-DD format, e.g. ["2026-09-05","2026-09-08"]. For recurring classes, use recurringDays instead.',
          },
          'recurringDays': {
            'type': 'array',
            'items': {'type': 'integer'},
            'description': 'Recurring days of week (1=Mon...7=Sun). Use this OR dates, not both. e.g. [1,3,5] for Mon/Wed/Fri.',
          },
          'location': {'type': 'string', 'description': 'Location as a single string, e.g. "UB43A", "UB20A 3rd floor room 301", "Science Block". Use this instead of separate building/floor/room when user gives a single location string.'},
          'building': {'type': 'string', 'description': 'Building name/code (optional). Use "location" field instead if user gives a single string.'},
          'floor': {'type': 'string', 'description': 'Floor number (optional).'},
          'room': {'type': 'string', 'description': 'Room number (optional).'},
          'notes': {'type': 'string', 'description': 'Optional notes about the class'},
        },
        'required': ['subjectName', 'startTime', 'durationMinutes'],
      },
    },
    {
      'name': 'registerDailyRoutine',
      'description': 'Register a daily study routine. WINDOW: ALWAYS from the EXACT create minute (7:20 → starts 7:20, never 8:00) until EXACTLY 23:30. HARD END: last block MUST end at 23:30 (11:30 PM) — app extends the last block so the day always finishes then. Freshen Up 30 min is auto-inserted at the start when create time is before 8:00 AM — do not send it yourself. NEVER invent subjects (e.g. "Study Gap Filler") — only real subjects from getAllData; empty gaps are filled by the app. REVISIONS: only if revisions_due_today has items — ALL of them, 30 min, at the BEGINNING. NEVER type review. After revisions: study 50 on user topics. BREAK RULE: after EACH study add break 10 ONLY if next block is not meal/nap/class; no daily break cap; never break without study. question_practice MAX 1/day 50 min. MEALS: do NOT invent times — app inserts fixed 20-min slots (Breakfast 8:00, Lunch 13:30, Snack 17:00, Dinner 20:00) when still upcoming. JSON time=HH:mm. AFTER SUCCESS: ONE short confirmation only (e.g. "Your routine is ready") — NEVER read out/list the routine. Classes from class_routines_today MUST be included at their times.',
      'parameters': {
        'type': 'object',
        'properties': {
          'date': {'type': 'string', 'description': 'Date for this routine in YYYY-MM-DD format. Use today if not specified.'},
          'items': {
            'type': 'array',
            'description': 'Ordered work blocks only (meals are auto-inserted at fixed times). REVISION first if due (30 min each, all at start). Then study 50. Break 10 after study when next is not meal/nap/class (no daily cap). question_practice max 1. NEVER review. Pack from now until 23:30.',
            'items': {
              'type': 'object',
              'properties': {
                'time': {'type': 'string', 'description': 'Start time 24h HH:mm for tools, e.g. "14:30".'},
                'subject': {'type': 'string', 'description': 'Subject name'},
                'topic': {'type': 'string', 'description': 'Topic name within the subject'},
                'type': {'type': 'string', 'description': 'revision (due only, 30 min, all first) | study | first_read | question_practice (max 1) | break (after study only) | nap | class. Meals are auto-placed. NEVER review.'},
                'durationMinutes': {'type': 'integer', 'description': 'revision=30, study/first_read=50, question_practice=50 (max 1), break=10 (after study; skip if meal/nap/class next), nap=20-25'},
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
      'description': 'Delete a class routine. Use when user says "delete my class routine", "remove this class", "cancel my class schedule". The assistant already knows which screen the user is on from the ROUTINE_CONTEXT in the system prompt. If context is "class", delete from class routines directly. Ask for subject name to identify which one to delete if multiple exist.',
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
      'description': 'Delete ALL daily routine items for a date (default today). ALWAYS tell the user (in THEIR language) that it was deleted and how many blocks were removed. UI refreshes automatically. After success, if the user also asked to create a new routine, call getAllData immediately (fresh) then registerDailyRoutine — never stall on Thinking, never re-delete the same day in a loop.',
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
