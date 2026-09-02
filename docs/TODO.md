# TODO

Everything from the 2026-09-02 UX/UI pass is done and recorded in
`docs/CHANGELOG.md`. What's left:

- [ ] **#12 (Windows close crash)** — live-tested today with a real
  close-while-playing-video: reproduced. The candidate fix's dispose hook
  did fire, but the crash still happened, at the native/OS layer after
  Dart-side cleanup. Root cause not yet found; see `docs/ROADMAP.md` #12.
- [ ] **`ROADMAP.md` code-consistency cleanup** — light pass done. Ask was
  vague; flag a more specific target if there's a particular section in
  mind.
- [ ] **Stable release + GitHub publish for both apps** — explicitly held
  back per your answer ("finish the UX pass first"). Not started.
