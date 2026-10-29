# ERRORS_LOG: ispotipay

> Log of non-trivial bugs, root causes, fixes, and prevention rules.
> Read before debugging to avoid repeating past mistakes.

---

## 1. Principles for debugging

1. **Find root cause first.** No blind guessing or masking symptoms.
2. **One change at a time.** Re-run tests to confirm.
3. **If same fix fails twice, STOP.** Step back and re-evaluate.

---

## 2. Prevention checklist

Before marking any feature as done:
- [ ] Ran `flutter analyze` with 0 issues
- [ ] Ran `flutter test` with all tests passing
- [ ] No unhandled futures or memory leaks (Controllers, Streams, Timers properly disposed)
- [ ] Proper error handling around network calls and file I/O

**Lessons learned from this project**
- *Always initialize FFI (`sqfliteFfiInit()`) when running on Windows/Desktop platforms before opening a database.*

---

## 3. Quick-lookup index

| ID | Date | Short symptom / error message | Area | Status |
|----|------|-------------------------------|------|--------|

---

## 4. Error records (newest first)

*(No errors recorded yet. Fresh codebase ready for development.)*
