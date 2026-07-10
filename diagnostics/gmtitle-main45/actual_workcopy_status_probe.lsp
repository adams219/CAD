;;; Tracked read-only status/verify probe for a copied actual work DWG.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT before launching GstarCAD.
;;; This script does not save the drawing.

(defun swtitle-diag45-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-diag45-path (relative)
  (strcat (swtitle-diag45-root) "/" relative)
)

(defun swtitle-diag45-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-diag45-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-diag45-run-command (handle label func / result)
  (swtitle-diag45-write-line handle (strcat "Run: " label))
  (setq result (vl-catch-all-apply func nil))
  (if (vl-catch-all-error-p result)
    (swtitle-diag45-write-line
      handle
      (strcat "Result: ERROR " label " - " (vl-catch-all-error-message result))
    )
    (swtitle-diag45-write-line
      handle
      (strcat "Result: OK " label " status=" (swtitle-diag45-status-value))
    )
  )
  (not (vl-catch-all-error-p result))
)

(defun swtitle-diag45-count-line (handle label counts)
  (swtitle-diag45-write-line handle label)
  (if counts
    (foreach item counts
      (swtitle-diag45-write-line handle (strcat "  " (car item) ": " (itoa (cdr item))))
    )
    (swtitle-diag45-write-line handle "  <none>")
  )
)

(defun swtitle-diag45-file-contains-p (path pattern / file line found)
  (setq found nil)
  (if (and path (findfile path))
    (progn
      (setq file (open path "r"))
      (if file
        (progn
          (while (and (not found) (setq line (read-line file)))
            (if (vl-string-search pattern line)
              (setq found T)
            )
          )
          (close file)
        )
      )
    )
  )
  found
)

(defun swtitle-diag45-env-or-default (name default / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    default
    value
  )
)

(defun swtitle-diag45-main (/ log-path env-log-path handle load-result load-ok version-value old-log-suffix requested-log-suffix ok-version ok-status status-after-status ok-verify status-after-verify summary source-count source-frame-count frame-only-count expected-counts target-counts blockers embedded-records title-count frame-count pair-records pair-count native-like-pair-count non-native-like-pair-count cloned-pair-count a3a4-native-upgrade-count orphan-target-frame-count duplicate-target-pair-count record bootstrap-record bootstrap-sheet bootstrap-frame bootstrap-title missing-native-frames missing-selection-record missing-selection-sheet missing-selection-frame missing-selection-title missing-selection-role first-native-guidance-ok next-step-log log-evidence-note automation-split-note human-check-note first-native-selection-log-note manual-forecast-log-note source-before-title-missing-forecast-note structure-log title-missing-deferred-note verify-summary-log verify-source-priority verify-title-missing-first)
  (setq load-result
    (vl-catch-all-apply
      'load
      (list (swtitle-diag45-path "src/tools/gmtitle/swcad_title_scale.lsp"))
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq version-value
    (if (boundp '*swcad-title-scale-version*)
      *swcad-title-scale-version*
      "<version variable missing>"
    )
  )
  (setq old-log-suffix
    (if (boundp '*swcad-title-log-file-suffix*)
      *swcad-title-log-file-suffix*
      nil
    )
  )
  (setq requested-log-suffix
    (swtitle-diag45-env-or-default
      "SWCAD_ACTUAL_WORKCOPY_LOG_SUFFIX"
      "_actual_workcopy_main56_diagnostics"
    )
  )
  (if load-ok
    (setq *swcad-title-log-file-suffix* requested-log-suffix)
  )
  (setq env-log-path (getenv "SWCAD_ACTUAL_WORKCOPY_STATUS_LOG"))
  (if (and env-log-path (> (strlen env-log-path) 0))
    (setq log-path (vl-string-translate "\\" "/" env-log-path))
    (setq log-path (swtitle-diag45-path "work/swtitle_actual_workcopy_status_main56_diagnostics.txt"))
  )
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-diag45-write-line handle "SWTITLE main56 actual workcopy read-only status probe")
      (if load-ok
        (swtitle-diag45-write-line handle "Load result: OK")
        (swtitle-diag45-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-diag45-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-diag45-write-line handle "Expected version: 260710-native-title-missing-frame-1")
      (swtitle-diag45-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-diag45-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (swtitle-diag45-write-line handle (strcat "DBMOD before commands: " (itoa (getvar "DBMOD"))))
      (swtitle-diag45-write-line handle "Commands requested: SWTITLEVERSION, SWTITLESTATUS, SWTITLEVERIFY")
      (swtitle-diag45-write-line handle (strcat "Detail log suffix: " requested-log-suffix))
      (if load-ok
        (progn
          (setq ok-version (swtitle-diag45-run-command handle "SWTITLEVERSION" 'c:SWTITLEVERSION))
          (setq ok-status (swtitle-diag45-run-command handle "SWTITLESTATUS" 'c:SWTITLESTATUS))
          (setq status-after-status (swtitle-diag45-status-value))
          (setq summary (swcad-title-fast-sheet-summary))
          (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
          (setq source-frame-count (swcad-title-fast-summary-value summary "source-frame-count"))
          (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
          (setq expected-counts (swcad-title-current-total-sheet-counts summary))
          (setq target-counts (swcad-title-target-frame-sheet-counts))
          (setq blockers (swcad-title-frame-definition-blocking-records))
          (setq embedded-records (swcad-title-frame-embedded-title-records))
          (setq bootstrap-record (swcad-title-next-bootstrap-selection-record))
          (setq bootstrap-sheet (if bootstrap-record (car bootstrap-record) "<none>"))
          (setq bootstrap-frame (if bootstrap-record (cadr bootstrap-record) "<none>"))
          (setq bootstrap-title (if bootstrap-record (caddr bootstrap-record) "<none>"))
          (setq missing-native-frames (swcad-title-missing-required-native-frame-blocks summary))
          (setq missing-selection-record (swcad-title-next-missing-native-selection-record summary missing-native-frames))
          (setq missing-selection-sheet (if missing-selection-record (car missing-selection-record) "<none>"))
          (setq missing-selection-frame (if missing-selection-record (cadr missing-selection-record) "<none>"))
          (setq missing-selection-title (if missing-selection-record (caddr missing-selection-record) "<none>"))
          (setq missing-selection-role (if missing-selection-record (cadddr missing-selection-record) "<none>"))
          (setq first-native-guidance-ok
            (and
              (equal status-after-status "NEXT_CREATE_FIRST_NATIVE_GMTITLE")
              (equal bootstrap-sheet "A2")
              (equal bootstrap-frame "DR_A2_Outline")
              (equal bootstrap-title "DR_titlea_3rd")
            )
          )
          (setq title-count (swcad-title-count-inserts-by-effective-name (swcad-title-target-title-block-name)))
          (setq frame-count
            (+
              (swcad-title-count-inserts-by-effective-name "DR_A2_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A3_Outline")
              (swcad-title-count-inserts-by-effective-name "DR_A4_Outline")
            )
          )
          (setq pair-records (swcad-title-target-gmtitle-pair-records))
          (setq pair-count (length pair-records))
          (setq native-like-pair-count 0)
          (foreach record pair-records
            (if (swcad-title-target-pair-native-like-p record)
              (setq native-like-pair-count (+ native-like-pair-count 1))
            )
          )
          (setq non-native-like-pair-count (- pair-count native-like-pair-count))
          (setq cloned-pair-count (swcad-title-cloned-gmtitle-pair-total))
          (setq a3a4-native-upgrade-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (setq orphan-target-frame-count (length (swcad-title-orphan-target-frame-records)))
          (setq duplicate-target-pair-count (length (swcad-title-duplicate-target-pair-records)))
          (setq ok-verify (swtitle-diag45-run-command handle "SWTITLEVERIFY" 'c:SWTITLEVERIFY))
          (setq status-after-verify (swtitle-diag45-status-value))
          (setq next-step-log (swcad-title-work-log-path "swcad_title_next_step_last.txt"))
          (setq log-evidence-note
            (swtitle-diag45-file-contains-p
              next-step-log
              "로그 판단 기준:"
            )
          )
          (setq automation-split-note
            (swtitle-diag45-file-contains-p
              next-step-log
              "자동화 분담:"
            )
          )
          (setq human-check-note
            (swtitle-diag45-file-contains-p
              next-step-log
              "사람 확인:"
            )
          )
          (setq first-native-selection-log-note
            (and
              (swtitle-diag45-file-contains-p next-step-log "다음 첫 native GMTITLE 선택:")
              (swtitle-diag45-file-contains-p next-step-log "용지/도면틀: DR_A2_Outline")
              (swtitle-diag45-file-contains-p next-step-log "제목블록: DR_titlea_3rd")
            )
          )
          (setq manual-forecast-log-note
            (and
              (swtitle-diag45-file-contains-p next-step-log "예상 수동 GMTITLE 확인량:")
              (swtitle-diag45-file-contains-p next-step-log "지금 필요한 확인: DR_A2_Outline / DR_titlea_3rd 1회")
              (swtitle-diag45-file-contains-p next-step-log "장은 원본 표제란 부재가 검증된 경우에만 제목블록 생성 대상에서 제외합니다.")
            )
          )
          (setq source-before-title-missing-forecast-note
            (or
              (swtitle-diag45-file-contains-p
                next-step-log
                "우선순위: 남은 원본 표제란 시트 변환이 title-missing/frame-only 예외보다 먼저입니다."
              )
              (swtitle-diag45-file-contains-p
                next-step-log
                "우선순위: 남은 원본 표제란 시트 변환이 title-없음/표제란 없는 도면틀 예외보다 먼저입니다."
              )
            )
          )
          (setq structure-log (swcad-title-work-log-path "swcad_title_structure_diagnosis_last.txt"))
          (setq title-missing-deferred-note
            (swtitle-diag45-file-contains-p
              structure-log
              "title-missing 판단 보충:"
            )
          )
          (setq verify-summary-log (swcad-title-work-log-path "swcad_title_verify_summary_last.txt"))
          (setq verify-source-priority
            (swtitle-diag45-file-contains-p
              verify-summary-log
              "SOURCE_SHEETS_BEFORE_TITLE_MISSING"
            )
          )
          (setq verify-title-missing-first
            (swtitle-diag45-file-contains-p
              verify-summary-log
              "TITLE_MISSING_AFTER_SOURCES"
            )
          )
          (swtitle-diag45-write-line handle "Summary after SWTITLESTATUS:")
          (swtitle-diag45-write-line handle (strcat "  source-title-count: " (itoa source-count)))
          (swtitle-diag45-write-line handle (strcat "  source-frame-count: " (itoa source-frame-count)))
          (swtitle-diag45-write-line handle (strcat "  frame-only-count: " (itoa frame-only-count)))
          (swtitle-diag45-write-line handle (strcat "  target-title-count: " (itoa title-count)))
          (swtitle-diag45-write-line handle (strcat "  target-frame-count: " (itoa frame-count)))
          (swtitle-diag45-write-line handle (strcat "  target-gmtitle-pair-count: " (itoa pair-count)))
          (swtitle-diag45-write-line handle (strcat "  native-like-target-pair-count: " (itoa native-like-pair-count)))
          (swtitle-diag45-write-line handle (strcat "  non-native-like-target-pair-count: " (itoa non-native-like-pair-count)))
          (swtitle-diag45-write-line handle (strcat "  cloned-gmtitle-pair-count: " (itoa cloned-pair-count)))
          (swtitle-diag45-write-line handle (strcat "  a2a3a4-native-upgrade-candidate-count: " (itoa a3a4-native-upgrade-count)))
          (swtitle-diag45-write-line handle (strcat "  orphan-target-frame-count: " (itoa orphan-target-frame-count)))
          (swtitle-diag45-write-line handle (strcat "  duplicate-target-pair-count: " (itoa duplicate-target-pair-count)))
          (swtitle-diag45-write-line handle (strcat "  next-step-log: " next-step-log))
          (swtitle-diag45-write-line handle (strcat "  log-evidence-note-found: " (if log-evidence-note "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  automation-split-note-found: " (if automation-split-note "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  human-check-note-found: " (if human-check-note "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  first-native-selection-log-note-found: " (if first-native-selection-log-note "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  manual-forecast-log-note-found: " (if manual-forecast-log-note "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  source-before-title-missing-forecast-note-found: " (if source-before-title-missing-forecast-note "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  structure-log: " structure-log))
          (swtitle-diag45-write-line handle (strcat "  title-missing-deferred-note-found: " (if title-missing-deferred-note "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  verify-summary-log: " verify-summary-log))
          (swtitle-diag45-write-line handle (strcat "  verify-source-priority-note-found: " (if verify-source-priority "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  verify-title-missing-first-note-found: " (if verify-title-missing-first "yes" "no")))
          (swtitle-diag45-write-line handle (strcat "  frame-definition-blockers: " (itoa (length blockers))))
          (swtitle-diag45-write-line handle (strcat "  frame-embedded-cleanup-records: " (itoa (length embedded-records))))
          (swtitle-diag45-write-line handle (strcat "  next-bootstrap-source-sheet: " bootstrap-sheet))
          (swtitle-diag45-write-line handle (strcat "  next-bootstrap-frame: " bootstrap-frame))
          (swtitle-diag45-write-line handle (strcat "  next-bootstrap-title: " bootstrap-title))
          (swtitle-diag45-write-line handle (strcat "  next-missing-native-source-sheet: " missing-selection-sheet))
          (swtitle-diag45-write-line handle (strcat "  next-missing-native-frame: " missing-selection-frame))
          (swtitle-diag45-write-line handle (strcat "  next-missing-native-title: " missing-selection-title))
          (swtitle-diag45-write-line handle (strcat "  next-missing-native-role: " missing-selection-role))
          (if missing-native-frames
            (foreach frame-block missing-native-frames
              (swtitle-diag45-write-line handle (strcat "  missing-native-frame: " frame-block))
            )
            (swtitle-diag45-write-line handle "  missing-native-frame: <none>")
          )
          (swtitle-diag45-write-line handle (strcat "  first-native-guidance-ok: " (if first-native-guidance-ok "yes" "no")))
          (swtitle-diag45-count-line handle "  expected-sheet-counts:" expected-counts)
          (swtitle-diag45-count-line handle "  target-sheet-counts:" target-counts)
          (swtitle-diag45-write-line handle (strcat "  status-after-status: " status-after-status))
          (swtitle-diag45-write-line handle (strcat "  status-after-verify: " status-after-verify))
          (swtitle-diag45-write-line handle (strcat "  dbmod-after-commands: " (itoa (getvar "DBMOD"))))
        )
        (progn
          (setq ok-version nil)
          (setq ok-status nil)
          (setq ok-verify nil)
        )
      )
      (swtitle-diag45-write-line
        handle
        (strcat "Runtime check completed: " (if (and ok-version ok-status ok-verify) "yes" "no"))
      )
      (close handle)
    )
  )
  (if load-ok
    (setq *swcad-title-log-file-suffix* old-log-suffix)
  )
  (princ)
)

(swtitle-diag45-main)
