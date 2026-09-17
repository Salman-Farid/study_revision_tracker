# Gemini 3 Flash Live Voice Chatbot

Self-contained voice/text AI package used by Smart Revision Tracker.

```
gemini_3_flash_live_voice_chatbot/
├── config/                 # model id, API key, default voice
├── core/
│   ├── audio/              # mic record + speaker play (io vs web)
│   ├── models/             # ChatMessage
│   └── websocket/          # Gemini Live WebSocket (+ socket/ split)
├── features/voice_assistant/
│   ├── README.md           # ← start here for the feature
│   ├── voice_assistant_controller.dart
│   ├── voice_assistant_screen.dart      # full-screen chat
│   ├── study_assistant_dialogue.dart    # floating card
│   ├── controller/                      # logic parts (tools, mic, session)
│   └── widgets/                         # UI parts (full_screen | floating_dialogue | shared)
├── services/
│   ├── gemini_live_service.dart
│   └── gemini_live/                     # session control part
├── shared/widgets/         # thinking dots, etc.
└── gemini_chatbot.dart     # public barrel (export this)
```

**Import only** `gemini_chatbot.dart` from the rest of the app unless you need
a private widget.

See `features/voice_assistant/README.md` for tool modes and how to add tools.
