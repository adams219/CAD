# GMTITLE 4?¨ê³„ ëª©í‘œ ê°ì‚¬ - 2026-07-04

## ê°ì‚¬ ê¸°ì?

ëª©í‘œ??SolidWorks DWGë¥?GstarCAD GMTITLE êµ¬ì¡°ë¡?ë°”ê¾¸?? ?¬ìš©?ê? ?©ì?ë³??„ì‹œ ëª…ë ¹???°ì? ?Šê³  ?„ë˜ ??ëª…ë ¹ë§??°ëŠ” ê²ƒì´??

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
```

ë³´ì¡° ëª…ë ¹?€ `SWTITLEVERSION`, `SWSCALESCAN`ë§??ˆìš©?œë‹¤. A3/A4 ?„ìš© ë³µêµ¬ ëª…ë ¹?€ ?´ë? ?¨ìˆ˜ë¡??¨ì•„???˜ì?ë§??¬ìš©??ê³µê°œ `c:` ëª…ë ¹?´ë©´ ???œë‹¤.

## ?„ì¬ ê¸°ì?

?„ì¬ LSP ë²„ì „:

```text
260704-frame-definition-classification-main-45
```

?„ì¬ main45 ?ŒìŠ¤??ë³µì‚¬ë³?

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\lsp_compare\swcad_title_scale_current_main45_compare_copy.lsp
```

?ë³¸/ë³µì‚¬ë³?SHA256:

```text
BB80F09CFDE8C083231D1106CEAF8C2A6DD83F40F8D8A59D30B295C5FD7A8AF8
```

?°í???fixture?€ ë¡œê·¸ ì¦ê±°??ì¶”ì ???¸ë±??

```text
docs/investigations/gmtitle-main45-verification-index-2026-07-04.md
```

## ?”êµ¬?¬í•­ë³??íƒœ

| ?”êµ¬?¬í•­ | ?„ì¬ ì¦ê±° | ?íƒœ |
| --- | --- | --- |
| ê³µê°œ GMTITLE ëª…ë ¹??4?¨ê³„ë¡??µí•© | `rg "(defun c:SWTITLE"` ê²°ê³¼ê°€ `SWTITLESTATUS`, `SWTITLEPREPARE`, `SWTITLECONVERT`, `SWTITLEVERIFY`, ë³´ì¡° `SWTITLEVERSION`, `SWSCALESCAN`ë§??œì‹œ | êµ¬í˜„??|
| `SWTITLESTATUS`ê°€ A2/A3/A4, ?ë³¸/?€???˜ëŸ‰, DR ?„ë©´?€ ?•ì˜ êµ¬ì¡°, A4 bbox ?„í—˜, ?¤ìŒ ëª…ë ¹??ì¶œë ¥ | `SWTITLESTATUS` ?´ë??ì„œ fast status, frame def check, native frame check, structure diagnosis, next step???¸ì¶œ | êµ¬í˜„?? ?¤ì œ ë³€???„ë£Œ DWG ?¬ê?ì¦??„ìš” |
| `SWTITLESTATUS`ê°€ ?¤ì¹˜ ?ë³¸ A3 ?´ë? native ?•ìƒ ?Œë¬¸??`SWTITLEPREPARE`ë¥??˜ëª» ?ˆë‚´?˜ì? ?ŠìŒ | `work/swtitle_status_nativeformat_fixture_main45_260704.txt`?ì„œ `Structure next action: SWTITLECONVERT`, blocking/cleanup 0 | ê²€ì¦ë¨ |
| `SWTITLEPREPARE`ê°€ ?„ë©´ ë³€ê²?ê°€???¨ê³„?ì„œ ?‘ì—…ë³µì‚¬ë³?YES ?•ì¸???”êµ¬ | ?´ë? ?•ë¦¬ ?¨ìˆ˜?¤ì´ read-only/work-copy/user ?•ì¸ ê²½ë¡œë¥?ê°€ì§?| êµ¬í˜„?? ?¤ì œ interactive YES ?•ë¦¬ ê²€ì¦ì? ?¨ìŒ |
| `SWTITLEPREPARE`ê°€ SCRIPT ?ë™ ?¤í–‰ ì¤?YES ?•ë¦¬ë¡??¤ì–´ê°€ì§€ ?ŠìŒ | `work/swtitle_prepare_guard_main45_260704.txt`?ì„œ `ABORT_PREPARE_SCRIPT_ACTIVE` | ê²€ì¦ë¨ |
| `SWTITLEPREPARE`ê°€ native A3 ?•ìƒ???ë™ ?? œ?˜ì? ?ŠìŒ | `swcad-title-frame-embedded-title-records`??`swcad-title-frame-definition-class-record`ê°€ `source-contaminated`ë¡?ë¶„ë¥˜???„ë©´?€ë§??•ë¦¬ ?„ë³´ë¡?ë°˜í™˜. `native-format-with-title-geometry`??ì°¨ë‹¨/?? œ ?„ë³´?ì„œ ?œì™¸ | ?•ì  ê°ì‚¬??|
| ?•ìƒ `DR_titlea_3rd` ?œëª©ë¸”ë¡?€ ?•ë¦¬ ?„ë³´ë¡??¤íŒ?˜ì? ?ŠìŒ | `work/swtitle_title_protection_fixture_main45_260704.txt`?ì„œ ?•ìƒ title insert 1ê°? frame-definition child-title cleanup ?„ë³´ 0, ?„ë©´?€ ?´ë? ?•ë¦¬ ?„ë³´ 0 | ê²€ì¦ë¨ |
| native A3 ?´ë? ?•ìƒ??source ?¤ì—¼?¼ë¡œ ?¤íŒ?˜ì? ?ŠìŒ | `work/swtitle_install_frame_scan_main45_260704.txt`, `work/swtitle_verify_nativeformat_fixture_main45_260704.txt`?ì„œ A3 class `native-format-with-title-geometry`, cleanup/blocking 0 | ê²€ì¦ë¨ |
| source-like child block???ˆëŠ” ?„ë©´?€ ?•ì˜???•ê·œ??ì°¨ë‹¨ ?€?ìœ¼ë¡?ë¶„ë¥˜ | `work/swtitle_frameclass_fixture_main45_260704.txt`?ì„œ A4 synthetic fixture class `source-contaminated`, blocking 1 | ê²€ì¦ë¨ |
| A2/A3/A4 ê³µí†µ ?„ë©´?€ ?•ì˜ ë¶„ë¥˜ê°€ source/native/outline??êµ¬ë¶„ | `diagnostics/gmtitle-main45/run_frameclass_common_probe.ps1`?ì„œ mixed, all_contaminated, all_native ?œë‚˜ë¦¬ì˜¤ ëª¨ë‘ PASS. all_native??cleanup 0, all_contaminated??A2/A3/A4 ëª¨ë‘ cleanup ?„ë³´ | ê²€ì¦ë¨ |
| `SWTITLECONVERT`ê°€ ?©ì?ë³?ê³µê°œ ëª…ë ¹ ?†ì´ ê¸°ì¡´ ?´ë? ?ë¦„???¸ì¶œ | `swcad-title-integrated-convert`ê°€ ì²?native, fast batch, frame-only, A3/A4 native replacementë¥??´ë? ë¶„ê¸° | êµ¬í˜„?? ?¤ì œ ?„ì²´ ë³€???„ë£Œ ê²€ì¦??„ìš” |
| `SWTITLECONVERT`ê°€ SCRIPT ?ë™ ?¤í–‰ ì¤?native GMTITLE ?€?”ì‹ ?¨ê³„ë¡??¤ì–´ê°€ì§€ ?ŠìŒ | `work/swtitle_convert_guard_main45_260704.txt`?ì„œ `ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE` | ê²€ì¦ë¨ |
| `SWTITLEVERIFY`ê°€ OK/WARN/FAIL ìµœì¢… ?”ì•½ | `swcad-title-integrated-verify-final-summary`ê°€ `SWTITLEVERIFY_FINAL_OK/WARN/FAIL` ?íƒœë¥??¨ê? | êµ¬í˜„??|
| LSP ë³µì‚¬ë³¸ì„ ë§Œë“¤??ë¹„êµ | `work/lsp_compare/swcad_title_scale_current_main45_compare_copy.lsp`?€ ?ë³¸ SHA256 ?¼ì¹˜ | ê²€ì¦ë¨ |
| main44?€ main45 ì¤????˜ì? ìª?ë¹„êµ | `docs/history/gmtitle-main44-vs-main45-comparison-2026-07-04.md` | ê²°ë¡ : main45 |
| GitHub origin/main LSP?€ ?„ì¬ main45 LSP ë³µì‚¬ë³?ë¹„êµ | `docs/history/gmtitle-origin-main-vs-current-main45-copy-comparison-2026-07-04.md`. origin/main?€ ê³µê°œ `c:` ëª…ë ¹ 21ê°? `SWTITLESTATUS` probe timeout. main45??ê³µê°œ `c:` ëª…ë ¹ 6ê°? `SWTITLESTATUS`/`SWTITLEVERIFY` probe ?„ë£Œ | ê²°ë¡ : main45 |
| ?¤ì œ ?‘ì—…ë³µì‚¬ë³??„ì¬ ?íƒœë¥?main45ë¡??½ê¸° ?„ìš© ?•ì¸ | `work/swtitle_actual_workcopy_status_main45_260704.txt` ë°?tracked wrapper ?¬ì‹¤??ë¡œê·¸ `work/swtitle_actual_workcopy_status_main45_diagnostics.txt`?ì„œ ?ë³¸ ?œì œ?€ 13, ?ë³¸ ?„ë©´?€ 15, frame-only 2, target 0, ?¤ìŒ ?íƒœ `NEXT_CREATE_FIRST_NATIVE_GMTITLE` | ë³€?????íƒœ ?•ì¸??|
| ?¬ìš©??facing ë¬¸ì„œê°€ 4?¨ê³„/main45 ê¸°ì????ˆë‚´ | `README.md`, `docs/guide/commands.md`, `docs/guide/gmtitle-native-frame-upgrade.md`, `work/README.md`ê°€ `SWTITLESTATUS/PREPARE/CONVERT/VERIFY`?€ main45 ?„ë©´?€ ë¶„ë¥˜ë¥??ˆë‚´ | ë¬¸ì„œ ?•ë¦¬??|
| APPLOAD ë¡œë” ?ˆë‚´ê°€ 4?¨ê³„ ?ë¦„???œì‹œ | `swcad_load.lsp` ë²„ì „ ë¬¸ì??`260704-4step-gmtitle-main47`, ë¡œë“œ ??`GMTITLE workflow: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY` ì¶œë ¥. `work/swtitle_loader_probe_main45_diagnostics.txt`?ì„œ loader/GMTITLE ë²„ì „, ê³µê°œ ëª…ë ¹ ?±ë¡, ?ˆì „ ê³µê°œ ëª…ë ¹ ë¹„í™œ?±í™” ?•ì¸ | ?°í???ê²€ì¦ë¨ |
| ?¤ì œ CAD ë³€??ì²´í¬ë¦¬ìŠ¤???œê³µ | `docs/guide/gmtitle-cad-conversion-checklist.md`ê°€ APPLOAD, STATUS, ?„ìš” ??PREPARE, CONVERT 1?? STATUS ?¬í™•?? VERIFY, ?”ë¸”?´ë¦­ ?•ì¸ ?œì„œë¥??ˆë‚´ | ë¬¸ì„œ ?•ë¦¬??|

## ê³µê°œ ëª…ë ¹ ?¬í™•??
2026-07-04 ?´ì–´???‘ì—…?˜ë©´???¤ì œ source LSP??ê³µê°œ `c:` ëª…ë ¹???¤ì‹œ ?•ì¸?ˆë‹¤.

```text
SWTITLESTATUS
SWTITLEPREPARE
SWTITLECONVERT
SWTITLEVERIFY
SWTITLEVERSION
SWSCALESCAN
```

?¼ë°˜ GMTITLE ë³€???¬ìš©?ëŠ” ?ì˜ ??ëª…ë ¹ë§??¬ìš©?œë‹¤. `SWTITLEVERSION`ê³?`SWSCALESCAN`?€ ë³´ì¡°/?½ê¸° ?„ìš© ?±ê²©?´ë‹¤.

?„ë˜ ?ˆì „ ?¤í—˜ ëª…ë ¹?¤ì? ?„ì¬ source LSP??ê³µê°œ `c:` ëª…ë ¹?¼ë¡œ ?¸ì¶œ?˜ì? ?ŠëŠ”??

```text
SWTITLEA3FRAMECLEAN
SWTITLECLEANORPHANFRAME
SWTITLEA3A4NEXT
SWTITLEA3A4ALL
SWTITLEFASTSTATUS
SWTITLETRANSFERFASTBATCH
SWTITLEFRAMEONLYAPPLY
SWTITLETRANSFERAPPLY
SWTITLETRANSFERBOOTSTRAPFAST
```

??‚¬ ë¬¸ì„œ?ëŠ” ?ˆì „ ëª…ë ¹ëª…ì´ ?¨ì•„ ?ˆì?ë§? ?„ì¬ ?¬ìš©??ê°€?´ë“œ?€ ?¤ì œ source LSP??ê³µê°œ ëª…ë ¹ ?œë©´?€ 4?¨ê³„ ?ë¦„ ê¸°ì??´ë‹¤.

2026-07-04 ì¶”ê? ?•ì¸: GstarCAD ?œì‘ ???ˆì „ LSPê°€ ?ë™ ë¡œë“œ?˜ì–´ CAD ë©”ëª¨ë¦¬ì— ?¤ë˜??`c:SWTITLE*` ëª…ë ¹???¨ì„ ???ˆì—ˆ?? ?„ì¬ LSP??ë¡œë“œ ???€???ˆê±°??ëª…ë ¹??nil ì²˜ë¦¬?œë‹¤. tracked loader/copy probe?ì„œ ?„ë˜ ?˜í”Œ??ëª¨ë‘ ë¹„í™œ?±í™”??ê²ƒì„ ?•ì¸?ˆë‹¤.

```text
Command c:SWTITLEFASTSTATUS: no
Command c:SWTITLETRANSFERBOOTSTRAPFAST: no
Command c:SWTITLETRANSFERFASTBATCH: no
Command c:SWTITLEFRAMEONLYAPPLY: no
Command c:SWTITLEA3A4NEXT: no
Command c:SWTITLEA3A4ALL: no
Command c:SWTITLEGMTITLEVERIFYALL: no
```

## SWTITLEPREPARE ?•ê·œ??ë¡œì§ ê°ì‚¬

2026-07-04 ?´ì–´???‘ì—…?˜ë©´??`SWTITLEPREPARE`ê°€ A3 native-format ?•ìƒ???˜ëª» ì§€?°ì? ?ŠëŠ”ì§€ ?•ì ?¼ë¡œ ?¤ì‹œ ?•ì¸?ˆë‹¤.

?µì‹¬ ?¸ì¶œ ?ë¦„:

```text
SWTITLEPREPARE
-> swcad-title-integrated-prepare
-> swcad-title-frame-embedded-title-records
-> swcad-title-frame-definition-class-record
```

?„ì¬ `swcad-title-frame-embedded-title-records`??ëª¨ë“  ?´ì¥ ?œì œ?€???•ìƒ??ë°”ë¡œ ?? œ ?„ë³´ë¡??˜ê¸°ì§€ ?ŠëŠ”?? ê°?`DR_A2_Outline`, `DR_A3_Outline`, `DR_A4_Outline`??ë¨¼ì? ë¶„ë¥˜???? classê°€ ?„ë˜???Œë§Œ ?•ë¦¬ ?„ë³´ë¥?ë°˜í™˜?œë‹¤.

```text
source-contaminated
```

ë°˜ë?ë¡??„ë˜ class???ë™ ?? œ ?„ë³´ê°€ ?„ë‹ˆ??

```text
native-format-with-title-geometry
```

?°ë¼???¤ì¹˜ ?ë³¸ `DR_A3_Outline`ì²˜ëŸ¼ ?œì œ?€ì²˜ëŸ¼ ë³´ì´???´ë? ?•ìƒ???ˆì–´??source-like child block???†ìœ¼ë©?`SWTITLEPREPARE`ê°€ ë°”ë¡œ ì§€?°ì? ?ŠëŠ”??

??ê°ì‚¬???•ì  ì½”ë“œ êµ¬ì¡° ?•ì¸?´ë‹¤. ?¤ì œ workcopy?ì„œ source-contaminatedê°€ ?ˆëŠ” ê²½ìš° `SWTITLEPREPARE`ê°€ ?„ë³´ ëª©ë¡??ë³´ì—¬ì£¼ê³  `YES` ?•ì¸ ???¸ê³½???ˆê¸ˆ/ì¢Œí‘œ?œì‹œë¥?ë³´í˜¸?˜ë©´???„ìš”???ì—­ë§?ì§€?°ëŠ”ì§€??ë³„ë„ interactive ê²€ì¦ì´ ?¨ì•„ ?ˆë‹¤.

## ?¬ìš©??facing ë¬¸ì„œ ?•ë¦¬ ?íƒœ

?„ë˜ ?Œì¼?€ ?„ì¬ main45 ê¸°ì??¼ë¡œ ?•ë¦¬?ˆë‹¤.

```text
README.md
docs/guide/commands.md
docs/guide/gmtitle-native-frame-upgrade.md
docs/guide/gmtitle-cad-conversion-checklist.md
work/README.md
swcad_load.lsp
```

?µì‹¬ ?•ë¦¬:

```text
1. ?¼ë°˜ ?¬ìš© ëª…ë ¹?€ SWTITLESTATUS / SWTITLEPREPARE / SWTITLECONVERT / SWTITLEVERIFY ??ê°œë¡œ ?ˆë‚´?œë‹¤.
2. SWTITLEVERSIONê³?SWSCALESCAN?€ ë³´ì¡°/?½ê¸° ?„ìš© ëª…ë ¹?¼ë¡œë§??ˆë‚´?œë‹¤.
3. ?ˆì „ SWTITLETRANSFER*, SWTITLEFAST*, SWTITLEA3A4*, SWTITLEFRAMEONLY* ê³µê°œ ëª…ë ¹ ?ë¦„?€ ?¬ìš©???ˆì°¨?ì„œ ?œê±°?ˆë‹¤.
4. main45 ?„ë©´?€ ?•ì˜ ? í˜•?€ unknown / outline-only / native-format-with-title-geometry / source-contaminatedë¡??ˆë‚´?œë‹¤.
5. native-format-with-title-geometry???ë™ ?? œ ê¸ˆì?, source-contaminatedë§??•ê·œ???€?ìœ¼ë¡??ˆë‚´?œë‹¤.
6. work README??ìµœì‹  tracked diagnostics runner??diagnostics/gmtitle-main45/run_actual_workcopy_status_probe.ps1ë¥??ˆë‚´?œë‹¤.
7. ?¤ì œ CAD ë³€??ì²´í¬ë¦¬ìŠ¤?¸ëŠ” `SWTITLECONVERT`ë¥??°ì† ?¤í–‰?˜ì? ?Šê³  ë§¤ë²ˆ `SWTITLESTATUS`ë¥??¤ì‹œ ?•ì¸?˜ë„ë¡??ˆë‚´?œë‹¤.
```

## APPLOAD ë¡œë” ê²½ë¡œ ê²€ì¦?
tracked wrapper:

```text
diagnostics/gmtitle-main45/run_loader_probe.ps1
```

ê²°ê³¼:

```text
Load result: OK
Loaded loader version: 260704-4step-gmtitle-main47
Loaded GMTITLE version: 260704-frame-definition-classification-main-45
Command c:SWTITLESTATUS: yes
Command c:SWTITLEPREPARE: yes
Command c:SWTITLECONVERT: yes
Command c:SWTITLEVERIFY: yes
Command c:SWTITLEVERSION: yes
Command c:SWSCALESCAN: yes
Legacy command disabled sample:
Command c:SWTITLEFASTSTATUS: no
Command c:SWTITLETRANSFERBOOTSTRAPFAST: no
Command c:SWTITLETRANSFERFASTBATCH: no
Command c:SWTITLEFRAMEONLYAPPLY: no
Command c:SWTITLEA3A4NEXT: no
Command c:SWTITLEA3A4ALL: no
Command c:SWTITLEGMTITLEVERIFYALL: no
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
Runtime check completed: yes
```

?´ì„:

```text
?¬ìš©?ê? APPLOADë¡?swcad_load.lspë¥?ë¡œë“œ?´ë„ main45 GMTITLE êµ¬í˜„??ë¡œë“œ?œë‹¤.
ê³µê°œ ëª…ë ¹ ?œë©´?€ 4?¨ê³„ ëª…ë ¹ê³?ë³´ì¡° 2ê°œë¡œ ? ì??œë‹¤.
?„ì¬ ?‘ì—…ë³µì‚¬ë³¸ì? ?¬ì „??ì²?native GMTITLE ?ì„± ???íƒœ??
```

## ?„ì§ ?„ë£Œë¡?ë³????†ëŠ” ??ª©

?„ë˜ ??ª©?€ ?„ì¬ ëª©í‘œ??ìµœì¢… ?„ë£Œ ì¦ê±°ë¡??„ì§ ë¶€ì¡±í•˜??

```text
1. ?¤ì œ SolidWorks ?‘ì—…ë³µì‚¬ë³??„ì²´ë¥?main45 ê¸°ì??¼ë¡œ ë³€??2. SWTITLEVERIFY_FINAL_OK ?•ì¸
3. ?ë³¸ ?œì œ?€ ?„ë³´ 0, ?ë³¸ ?„ë©´?€ ?„ë³´ 0 ?•ì¸
4. A2/A3/A4 ê¸°ì? ?˜ëŸ‰ê³?target GMTITLE ?˜ëŸ‰ ?¼ì¹˜ ?•ì¸
5. A3 ?œëª©ë¸”ë¡ ì¤‘ë³µ ?†ìŒ ?•ì¸
6. A4 frame-only ?œíŠ¸ ?„ë½ ?†ìŒ ?•ì¸
7. ?„ë©´ ?ˆì˜ ë²ˆí˜¸/ì£¼ì„/BOM/?ìŠ¤???? œ ?†ìŒ ?•ì¸
8. ?€??A2/A3/A4 `DR_titlea_3rd` ?”ë¸”?´ë¦­ ??GMTITLE ???¸ì§‘ì°??•ì¸
```

?„ì¬ ìµœì‹  probe??`SWTITLEVERIFY_FINAL_FAIL`?€ main45 ?¤íŒ¨ê°€ ?„ë‹ˆ??ë³€?????íƒœ?¼ëŠ” ?»ì´?? target GMTITLE ?„ë©´?€/?œëª©ë¸”ë¡ ?˜ê? 0?´ë?ë¡?ìµœì¢… ?„ë£Œ ?ì •?¼ë¡œ ?¬ìš©?????†ë‹¤.

## ?¤ì œ ?‘ì—…ë³µì‚¬ë³?main45 ?½ê¸° ?„ìš© ?íƒœ

?ê? ?€??probe DWG:

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\swtitle_actual_workcopy_main45_status_probe_260704.dwg
```

?ë³¸ ?‘ì—…ë³µì‚¬ë³?

```text
C:\Users\DR-DESIGN\Documents\CAD tool\work\0000_A_DRP125_CP_ALL_260626_test_workcopy_03.dwg
```

ë¡œê·¸:

```text
work/swtitle_actual_workcopy_status_main45_260704.txt
work/swtitle_actual_workcopy_status_main45_diagnostics.txt
```

ê²°ê³¼:

```text
Load result: OK
Loaded version: 260704-frame-definition-classification-main-45
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL

source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
frame-definition-blockers: 0
frame-embedded-cleanup-records: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
target-sheet-counts:
  <none>
Runtime check completed: yes
```

?´ì„:

```text
?„ì¬ ?‘ì—…ë³µì‚¬ë³¸ì? ?„ì§ ë³€?????íƒœ??
?„ë©´?€ ?•ì˜ ?•ê·œ??ì°¨ë‹¨ ??ª©?€ ?†ë‹¤.
?¤ìŒ ?¤ì œ CAD ?¨ê³„??SWTITLECONVERTë¡?ì²?native GMTITLE ê¸°ì? ê°ì²´ë¥?ë§Œë“œ??ê²ƒì´??
```

2026-07-04 ?´ì–´??ê°™ì? tracked wrapperë¥??¤ì‹œ ?¤í–‰?ˆê³  ?™ì¼??ê²°ë¡ ???•ì¸?ˆë‹¤.

```text
Run: SWTITLESTATUS
Result: OK SWTITLESTATUS status=NEXT_CREATE_FIRST_NATIVE_GMTITLE
Run: SWTITLEVERIFY
Result: OK SWTITLEVERIFY status=SWTITLEVERIFY_FINAL_FAIL
source-title-count: 13
source-frame-count: 15
frame-only-count: 2
target-title-count: 0
target-frame-count: 0
frame-definition-blockers: 0
frame-embedded-cleanup-records: 0
expected-sheet-counts:
  A2: 1
  A3: 12
  A4: 2
Runtime check completed: yes
```

## ?¤ìŒ ?¤ì œ CAD ê²€ì¦??œì„œ

?‘ì—…ë³µì‚¬ë³?DWGë¥??????„ë˜ ?œì„œë¡?ì§„í–‰?œë‹¤.

```text
APPLOAD
C:\Users\DR-DESIGN\Documents\CAD tool\src\tools\gmtitle\swcad_title_scale.lsp

SWTITLEVERSION
SWTITLESTATUS
SWTITLEPREPARE   ?„ìš”??ê²½ìš°?ë§Œ, CAD ëª…ë ¹ì¤„ì—??ì§ì ‘ ?¤í–‰?˜ê³  YES ?•ì¸
SWTITLESTATUS
SWTITLECONVERT
SWTITLESTATUS
SWTITLECONVERT   ?„ì§ ?¤ìŒ ë³€?˜ì´ ?¨ì•˜?¤ê³  ?ˆë‚´???Œë§Œ ë°˜ë³µ
SWTITLEVERIFY
```

`SWTITLEVERIFY_FINAL_OK`ê°€ ?˜ì˜¤ê¸??„ì—??ëª¨ì–‘??ë§ì•„ ë³´ì—¬???„ë£Œë¡?ë³´ì? ?ŠëŠ”??

## ?¤ìŒ SWTITLECONVERT ?ˆìƒ ?ë¦„

?„ì¬ ?‘ì—…ë³µì‚¬ë³¸ì? `target-title-count=0`, `target-frame-count=0`?´ê³  native GMTITLE ê¸°ì? ê°ì²´ê°€ ?†ë‹¤. ?°ë¼???¤ìŒ `SWTITLECONVERT`???„ë˜ ë¶„ê¸°ë¡??¤ì–´ê°€???œë‹¤.

```text
swcad-title-integrated-convert
-> swcad-title-transfer-bootstrap-fast
-> ì²?native GMTITLE ?ì„±/ë§ˆë¬´ë¦?```

?ˆìƒ ?¬ìš©???•ì¸:

```text
ì²?native GMTITLE???ì„±/ë§ˆë¬´ë¦¬í•˜ê³?ê³„ì†?˜ë ¤ë©?YES ?…ë ¥
GMTITLE ì°½ì—??DR_A2_Outline ? íƒ
?œëª©ë¸”ë¡?€ DR_titlea_3rd ? íƒ
Frame positioning: ON
Object move: OFF
```

?¤í–‰ ?¤ì—??ë°”ë¡œ ?¤ì‹œ `SWTITLECONVERT`ë¥??„ë¥´ì§€ ?Šê³  `SWTITLESTATUS`ë¥??¤í–‰?œë‹¤.
