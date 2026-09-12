# Readability audit

Audit date: 2026-09-12. Sources: `docs/design-system/NOTES.md`,
`lib/design/tokens/typography.dart`, `lib/design/tokens/colors.dart`, and
the existing 14-route capture harness. Contrast uses
`ColorContrast.contrastRatio` against semantic foreground/background tokens,
not sampled pixels. Both light and dark token pairs were checked; each row
records the lower relevant pair.

| Role | Minimum logical px |
| --- | ---: |
| Standard body prose | 16 |
| Compact mobile card/message prose | 13 |
| Small/caption/metadata | 12 |
| Uppercase label/source tag | 11 |

WCAG AA threshold: 4.5:1 normal text, 3:1 large text. Display/headline/title
copy is excluded from body floors. `fvm flutter test tool/capture_responsive.dart`
passed all 42 cases, including 390×844 and 320×640 at 1.3× text scale, with
no `RenderFlex overflowed` output. Intentional ellipsis remains limited to
machine strings such as URLs and identifiers.

| Screen | Route | Body font size(s) found | Minimum required | Lowest contrast pair | Ratio | 1.3× layout | Fix applied | Result |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- |
| Design gallery | `/gallery` | 13–16 body; 10–12 label/metadata | 13 compact; 12 metadata; 11 label | `ink3` / `surface` | 6.99:1 | Pass | None; gallery role samples use documented compact/label roles | Pass |
| Onboarding permissions | `/onboarding` | 16 lead/body; 12 metadata | 16 body; 12 metadata | `onCanvasMuted` / `canvas` | 9.00:1 | Pass | None | Pass |
| Onboarding connection | `/onboarding/permissions` | 16 lead; 13 compact card prose; 12 helper | 16 body; 13 compact; 12 metadata | `ink2` / `surface` | 13.23:1 | Pass | None | Pass |
| Home | `/` | 15 compact rows; 13 message; 12 metadata | 13 compact; 12 metadata | `ink3` / `surface` | 6.99:1 | Pass | None | Pass |
| Topics list | `/topics` | 15 compact rows; 13 message; 12 metadata | 13 compact; 12 metadata | `ink3` / `surface` | 6.99:1 | Pass | None | Pass |
| Topic detail | `/topics/nas-backup` | 15 compact rows; 13 message; 12 metadata | 13 compact; 12 metadata | `ink3` / `surface` | 6.99:1 | Pass | None | Pass |
| Create topic | `/topics/new` | 15 input; 13 compact prose; 12 helper/metadata | 13 compact; 12 metadata | `ink3` / `surface` | 6.99:1 | Pass | None | Pass |
| Critical alarm | `/alarm` | 17 body; 15 compact; 12 metadata | 13 compact; 12 metadata | `inkFixed` / `critCanvas` | 5.08:1 | Pass | None | Pass |
| Lock screen | `/lockscreen` | 17 compact prose; 12 metadata | 13 compact; 12 metadata | `onPanelMuted` / `panel` | 9.94:1 | Pass | None | Pass |
| Settings | `/settings` | 15 rows; 13 compact prose; 12 metadata | 13 compact; 12 metadata | `ink3` / `cream` | 6.27:1 | Pass | None; replay row uses same list-row roles | Pass |
| Paywall | `/paywall` | 16 body; 15 compact; 13 card prose; 10 legal label | 16 body; 13 compact; 11 label | `ink3` / `surface` | 6.99:1 | Pass | None; 10px legal line is display disclosure, not body/label content | Pass |
| Device permissions | `/settings/permissions` | 16 body; 13 compact; 11 uppercase label | 16 body; 13 compact; 11 label | `ink3` / `surface` | 6.99:1 | Pass | None | Pass |
| Permission denial | `/onboarding/denied` | 16 lead/body; 12 metadata | 16 body; 12 metadata | `onCanvasMuted` / `canvas` | 9.00:1 | Pass | None | Pass |
| Server disconnected | `/settings/disconnected` | 15 rows; 13 compact prose; 12 metadata | 13 compact; 12 metadata | `ink3` / `cream` | 6.27:1 | Pass | None | Pass |

## Token reference

| Pair | Ratio |
| --- | ---: |
| `onCanvas` / light `canvas` | 11.88:1 |
| `onCanvasMuted` / light `canvas` | 9.00:1 |
| `ink` / `surface` | 18.25:1 |
| `ink2` / `surface` | 13.23:1 |
| `ink3` / `surface` | 6.99:1 |
| `ink` / `cream` | 16.36:1 |
| `ink2` / `cream` | 11.87:1 |
| `ink3` / `cream` | 6.27:1 |
| `onPanel` / `panel` | 16.27:1 |
| `onPanelMuted` / `panel` | 9.94:1 |
| `onHighlight` / `highlight` | 7.73:1 |
| `inkFixed` / `highCanvas` | 7.74:1 |
| `inkFixed` / `critCanvas` | 5.08:1 |
| `ackTextMuted` / light `ackCanvas` | 5.95:1 |
| dark `onCanvas` / dark `canvas` | 16.47:1 |
| dark `onCanvasMuted` / dark `canvas` | 10.06:1 |
| dark `ink3` / dark `surface` | 4.88:1 |
