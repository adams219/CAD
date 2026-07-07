;;; Diagnostic probe: run one internal remaining-sheet clone on a copied DWG.
;;; The PowerShell wrapper copies the real workcopy before launching this probe.
;;; This script does not save the drawing; it only records in-memory results.

(vl-load-com)

(setq *swtitle-singleclone-active-log-handle* nil)

(defun swtitle-singleclone-error-handler (msg)
  (if *swtitle-singleclone-active-log-handle*
    (progn
      (write-line (strcat "Probe error: " (if msg msg "<nil>")) *swtitle-singleclone-active-log-handle*)
      (write-line "Runtime check completed: error" *swtitle-singleclone-active-log-handle*)
      (close *swtitle-singleclone-active-log-handle*)
      (setq *swtitle-singleclone-active-log-handle* nil)
    )
  )
  (princ)
)

(defun *error* (msg)
  (swtitle-singleclone-error-handler msg)
)

(defun swtitle-singleclone-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-singleclone-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-singleclone-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-singleclone-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<missing>"
  )
)

(defun swtitle-singleclone-count (summary key)
  (if summary
    (swcad-title-fast-summary-value summary key)
    0
  )
)

(defun swtitle-singleclone-target-frame-count ()
  (+
    (swcad-title-count-inserts-by-effective-name "DR_A2_Outline")
    (swcad-title-count-inserts-by-effective-name "DR_A3_Outline")
    (swcad-title-count-inserts-by-effective-name "DR_A4_Outline")
  )
)

(defun swtitle-singleclone-native-like-count (/ count records)
  (setq count 0)
  (setq records (swcad-title-target-gmtitle-pair-records))
  (foreach record records
    (if (swcad-title-target-pair-native-like-p record)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swtitle-singleclone-write-counts (handle label summary / target-pairs native-like)
  (setq target-pairs (length (swcad-title-target-gmtitle-pair-records)))
  (setq native-like (swtitle-singleclone-native-like-count))
  (swtitle-singleclone-write-line handle label)
  (swtitle-singleclone-write-line handle (strcat "  source-title-count: " (itoa (swtitle-singleclone-count summary "source-title-count"))))
  (swtitle-singleclone-write-line handle (strcat "  source-frame-count: " (itoa (swtitle-singleclone-count summary "source-frame-count"))))
  (swtitle-singleclone-write-line handle (strcat "  frame-only-count: " (itoa (swtitle-singleclone-count summary "frame-only-count"))))
  (swtitle-singleclone-write-line handle (strcat "  target-title-count: " (itoa (swcad-title-count-inserts-by-effective-name (swcad-title-target-title-block-name)))))
  (swtitle-singleclone-write-line handle (strcat "  target-frame-count: " (itoa (swtitle-singleclone-target-frame-count))))
  (swtitle-singleclone-write-line handle (strcat "  target-pair-count: " (itoa target-pairs)))
  (swtitle-singleclone-write-line handle (strcat "  native-like-target-pair-count: " (itoa native-like)))
  (swtitle-singleclone-write-line handle (strcat "  non-native-like-target-pair-count: " (itoa (- target-pairs native-like))))
  (swtitle-singleclone-write-line handle (strcat "  cloned-gmtitle-pair-count: " (itoa (swcad-title-cloned-gmtitle-pair-total))))
  (swtitle-singleclone-write-line handle (strcat "  a2a3a4-native-upgrade-candidate-count: " (itoa (length (swcad-title-a3a4-native-upgrade-candidate-records)))))
)

(defun swtitle-singleclone-main (/ root lsp-path log-path handle load-result load-ok version-value old-suffix before-summary after-summary verify-summary source-before source-after target-before target-after native-candidates-before native-candidates-after target-frame next-ready old-batch clone-result clone-status verify-result verify-status scriptable-safe pass)
  (setq root (swtitle-singleclone-root))
  (setq lsp-path (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp"))
  (setq log-path
    (swtitle-singleclone-env-path
      "SWCAD_SINGLE_CLONE_PROBE_LOG"
      (strcat root "/work/swtitle_single_clone_probe.txt")
    )
  )
  (setq load-result (vl-catch-all-apply 'load (list lsp-path)))
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq version-value
    (if (boundp '*swcad-title-scale-version*)
      *swcad-title-scale-version*
      "<version variable missing>"
    )
  )
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (setq *swtitle-singleclone-active-log-handle* handle)
      (swtitle-singleclone-write-line handle "SWTITLE single clone diagnostic probe")
      (swtitle-singleclone-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-singleclone-write-line handle "Load result: OK")
        (swtitle-singleclone-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-singleclone-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-singleclone-write-line handle "Expected version: 260707-convert-next-clone-upgrade-19")
      (swtitle-singleclone-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-singleclone-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (swtitle-singleclone-write-line handle (strcat "Script active: " (if (and load-ok (swcad-title-script-active-p)) "yes" "no")))
      (swtitle-singleclone-write-line handle "Probe save behavior: no SAVE command is issued")
      (if load-ok
        (progn
          (swtitle-singleclone-write-line handle "Checkpoint: loaded LSP, starting summary")
          (setq old-suffix *swcad-title-log-file-suffix*)
          (setq *swcad-title-log-file-suffix* "_single_clone_probe")
          (setq before-summary (swcad-title-fast-sheet-summary))
          (swtitle-singleclone-write-line handle "Checkpoint: before summary collected")
          (setq source-before (swtitle-singleclone-count before-summary "source-title-count"))
          (setq target-before (length (swcad-title-target-gmtitle-pair-records)))
          (setq native-candidates-before (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (setq target-frame (swcad-title-next-fast-target-frame-block))
          (setq next-ready (swcad-title-next-fast-target-ready-p))
          (swtitle-singleclone-write-line handle "Checkpoint: before metrics collected")
          (swtitle-singleclone-write-counts handle "Counts before internal clone:" before-summary)
          (swtitle-singleclone-write-line handle (strcat "Next fast target frame: " (if target-frame target-frame "<none>")))
          (swtitle-singleclone-write-line handle (strcat "Next fast target ready: " (if next-ready "yes" "no")))
          (if (and (> source-before 0) next-ready)
            (progn
              (setq old-batch *swcad-title-batch-mode*)
              (setq *swcad-title-batch-mode* T)
              (swtitle-singleclone-write-line handle "Checkpoint: starting internal clone")
              (setq clone-result (vl-catch-all-apply 'swcad-title-transfer-clone-apply nil))
              (setq *swcad-title-batch-mode* old-batch)
              (setq clone-status (swtitle-singleclone-status-value))
              (if (vl-catch-all-error-p clone-result)
                (swtitle-singleclone-write-line handle (strcat "Internal clone result: ERROR - " (vl-catch-all-error-message clone-result)))
                (swtitle-singleclone-write-line handle "Internal clone result: OK")
              )
              (swtitle-singleclone-write-line handle (strcat "Internal clone status: " clone-status))
            )
            (progn
              (setq clone-status "SKIPPED_NOT_READY")
              (swtitle-singleclone-write-line handle "Internal clone result: SKIPPED_NOT_READY")
            )
          )
          (swtitle-singleclone-write-line handle "Checkpoint: starting after summary")
          (setq after-summary (swcad-title-fast-sheet-summary))
          (setq source-after (swtitle-singleclone-count after-summary "source-title-count"))
          (setq target-after (length (swcad-title-target-gmtitle-pair-records)))
          (setq native-candidates-after (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (swtitle-singleclone-write-counts handle "Counts after internal clone:" after-summary)
          (setq verify-result (vl-catch-all-apply 'c:SWTITLEVERIFY nil))
          (setq verify-status (swtitle-singleclone-status-value))
          (if (vl-catch-all-error-p verify-result)
            (swtitle-singleclone-write-line handle (strcat "Verify after clone: ERROR - " (vl-catch-all-error-message verify-result)))
            (swtitle-singleclone-write-line handle (strcat "Verify after clone: OK status=" verify-status))
          )
          (setq verify-summary (swcad-title-fast-sheet-summary))
          (swtitle-singleclone-write-counts handle "Counts after verify:" verify-summary)
          (setq scriptable-safe
            (and
              (= source-after (- source-before 1))
              (= target-after (+ target-before 1))
              (= native-candidates-after native-candidates-before)
              (= (length (swcad-title-a3a4-native-upgrade-candidate-records)) 0)
            )
          )
          (setq pass
            (and
              (not (vl-catch-all-error-p clone-result))
              (= source-after (- source-before 1))
              (= target-after (+ target-before 1))
            )
          )
          (swtitle-singleclone-write-line handle (strcat "Source title delta: " (itoa (- source-after source-before))))
          (swtitle-singleclone-write-line handle (strcat "Target pair delta: " (itoa (- target-after target-before))))
          (swtitle-singleclone-write-line handle (strcat "Native-upgrade candidate delta: " (itoa (- native-candidates-after native-candidates-before))))
          (swtitle-singleclone-write-line handle (strcat "Single clone basic conversion passed: " (if pass "yes" "no")))
          (swtitle-singleclone-write-line handle (strcat "Single clone scriptable without GMTITLE dialog evidence: " (if scriptable-safe "yes" "no")))
          (swtitle-singleclone-write-line handle (strcat "DBMOD after probe: " (itoa (getvar "DBMOD"))))
          (setq *swcad-title-log-file-suffix* old-suffix)
        )
      )
      (swtitle-singleclone-write-line handle "Runtime check completed: yes")
      (close handle)
      (setq *swtitle-singleclone-active-log-handle* nil)
    )
  )
  (princ)
)

(swtitle-singleclone-main)
