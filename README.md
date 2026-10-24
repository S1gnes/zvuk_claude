# zvuk_claude

A Claude Code hook for Windows that plays a random sound every time Claude finishes an answer, so you know the reply is ready without watching the terminal.

Sounds play in shuffled order: each one plays once before any repeats, never the same one twice in a row. Comes with 31 sounds; any `.wav`, `.mp3`, `.wma`, `.m4a` or `.aac` dropped into `%USERPROFILE%\.claude\sounds` joins the rotation.
