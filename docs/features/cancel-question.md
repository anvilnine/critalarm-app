# Cancel question

Moved out of AGENTS.md on 2026-11-02 (added to main on 2026-10-27, after the split branch left). Read before changing this area.

**Cancel question.** An ask, not a notice, and not a notification or an alarm:
a sheet the person sees by opening Home, and it schedules nothing.
`CancelQuestion.dueFor` reads `ProEndingView.endsAt` (not the sheet, so the
pill still counts) and asks once per end date. The local key is the UTC date of
`ProEndingView.endsAtInstant`, the store's expiry instant, never through
`DeviceTimeZone`. The mark is written when the sheet opens, so any way of
closing it counts as asked. A billing issue skips it. It shows before the Cloud
ends sheet. The answer goes through `CancelAnswerSender`: the chip at once, the
text second, a failed send tried on three later launches, then dropped (at once
on another account, off Cloud or on a 403). `AccountData.forget` clears the
queue. The `cancel_reason` event carries the wire name only. Prefs keys:
`cancel_question_asked_for` and `cancel_question_pending_v1`.
