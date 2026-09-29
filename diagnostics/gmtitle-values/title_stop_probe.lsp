;;; GMTITLE step 3 (2026-09-29): errors and ESC stop SWCADRUN.  Runs on a throw-away copy,
;;; never saved.
;;; Environment: SWT_STEP3_LOG = log path, SWT_LOADER = swcad_workflow_load.lsp path.
;;; Errors are injected by replacing functions with fakes; ESC arrives in LISP
;;; as an error, so a fake that raises an error stands for both.

(vl-load-com)
(load (getenv "SWT_LOADER"))

(setq *swt3-saved* nil)
(setq *swt3-log* nil)
(setq *swt3-fo-remaining* 0)
(setq *swt3-undo-results* nil)

(defun swt3-line (parts / text part)
  (setq text "")
  (foreach part parts
    (setq text (strcat text (if (= text "") "" "|") (vl-string-translate "|\n\r\t" "/   " (vl-princ-to-string part))))
  )
  (write-line text *swt3-log*)
)

(defun swt3-check (label actual expected)
  (swt3-line (list (if (equal actual expected) "UNIT_OK" "UNIT_FAIL") label actual expected))
)

(defun swt3-stub (sym fn)
  (setq *swt3-saved* (cons (cons sym (eval sym)) *swt3-saved*))
  (set sym fn)
)

(defun swt3-unstub-all (/ pair)
  (foreach pair *swt3-saved* (set (car pair) (cdr pair)))
  (setq *swt3-saved* nil)
)

(defun swt3-group-open-p (/ u) (setq u (getvar "UNDOCTL")) (= (logand u 8) 8))

(defun swt3-status () *swcad-title-last-apply-status*)

;;; A GMTITLE runner stopped by ESC: object snap off, undo group open, new pair pending.
(defun swt3-fake-stopped-runner ()
  (swcad-title-remember-gmtitle-input-vars (getvar "OSMODE") (swcad-title-safe-getvar "DYNMODE"))
  (setvar "OSMODE" 0)
  (vla-StartUndoMark (swcad-title-doc))
  (swcad-title-set-pending-gmtitle-pair (entlast) (entlast) "DR_A3_Outline" "native")
  (car "injected-esc")
)

(defun swt3-fake-error () (car "injected-error"))
(defun swt3-fake-nil (/) nil)
(defun swt3-fake-nil1 (a) nil)
(defun swt3-fake-nil3 (a b c) nil)
(defun swt3-fake-true (/) T)
(defun swt3-fake-one-record (/) (list (list (list nil) nil)))
(defun swt3-fake-list1 (/) (list 1))

(defun swt3-reset-state ()
  (setvar "OSMODE" 37)
  (setq *swcad-title-last-apply-status* nil)
  (swcad-title-command-entry-reset)
  (setvar "OSMODE" 37)
)

(defun swt3-main (/ e u0 u1 u2 r a b)
  (setq *swt3-log* (open (getenv "SWT_STEP3_LOG") "w"))
  (swt3-line (list "VERSION" *swcad-title-scale-version* *swapp-version*))
  (setq e (entmakex (list '(0 . "LINE") '(8 . "0") '(10 0.0 0.0 0.0) '(11 5.0 0.0 0.0))))

  ;; 1. Stop statuses.
  (foreach s '("ABORT_X" "ERROR_X" "WARN_X" "BLOCKED_X" "REVIEW_X")
    (swt3-check (strcat "stop-status " s) (if (swcad-title-stop-status-p s) T nil) T)
  )
  (foreach s '("OK_X" "STOP_X" "APPLIED_TITLE_TRANSFER" "WAITING_X" "")
    (swt3-check (strcat "not-stop-status " s) (if (swcad-title-stop-status-p s) T nil) nil)
  )
  (swt3-check "not-stop-status nil" (if (swcad-title-stop-status-p nil) T nil) nil)

  ;; 2. Undo group.  GstarCAD does not show a vla-StartUndoMark group in UNDOCTL
  ;; (bit 8 stays 0), so what UNDO 1 removes is measured instead:
  ;;   closed:   Start, A, End, B      -> UNDO 1
  ;;   recover:  Start, A, recover, B  -> UNDO 1 (should match "closed")
  ;;   dangling: Start, A, B           -> UNDO 1, then End
  (setq u0 (getvar "UNDOCTL"))
  (vla-StartUndoMark (swcad-title-doc))
  (setq u1 (getvar "UNDOCTL"))
  (vla-EndUndoMark (swcad-title-doc))
  (swt3-line (list "UNDOCTL" u0 u1))
  ;; (The UNDO measurement runs in step3_undo_probe.lsp with raw script lines.)
  (vla-StartUndoMark (swcad-title-doc))
  (setq r (vl-catch-all-apply 'swcad-title-recover-after-caught-error nil))
  (swt3-check "recover-with-open-group-no-error" (vl-catch-all-error-p r) nil)
  (setq r (vl-catch-all-apply 'vla-EndUndoMark (list (swcad-title-doc))))
  (swt3-check "end-undo-without-group-no-error" (vl-catch-all-error-p r) nil)
  (swt3-check "end-undo-without-group-keeps-undoctl" (getvar "UNDOCTL") u0)

  ;; 3. Per-sheet batch: ESC in transfer-apply.
  (swt3-reset-state)
  (swt3-stub 'swcad-title-transfer-apply swt3-fake-stopped-runner)
  (swcad-title-transfer-batch-run (swt3-fake-one-record) 1)
  (swt3-unstub-all)
  (swt3-check "batch-run-esc-status" (swt3-status) "ERROR_BATCH_APPLY")
  (swt3-check "batch-run-esc-osmode-restored" (getvar "OSMODE") 37)
  (swt3-check "batch-run-esc-restore-cleared" *swcad-title-gmtitle-input-restore* nil)
  (swt3-check "batch-run-esc-pending-cleared" *swcad-title-pending-native-title-ename* nil)

  ;; 4. Native auto-select batch: a stop on the last sheet must not become OK.
  (defun swt3-fake-batch-review (records count) (setq *swcad-title-last-apply-status* "REVIEW_OLD_TITLE_NOT_DELETED"))
  (defun swt3-fake-batch-applied (records count) (setq *swcad-title-last-apply-status* "APPLIED_TITLE_TRANSFER"))
  (defun swt3-fake-batch-error (records count) (setq *swcad-title-batch-mode* T) (car "injected-error"))
  (foreach item (list
                  (list swt3-fake-batch-review "REVIEW_OLD_TITLE_NOT_DELETED" "autoselect-last-sheet-review-kept")
                  (list swt3-fake-batch-applied "OK_NATIVE_AUTOSELECT_BATCH_COMPLETE" "autoselect-all-applied-ok")
                  (list swt3-fake-batch-error "ERROR_NATIVE_AUTOSELECT_BATCH" "autoselect-batch-error")
                )
    (swt3-reset-state)
    (swt3-stub 'swcad-title-transfer-batch-source-records swt3-fake-one-record)
    (swt3-stub 'swcad-title-gmtitle-autoselect-available-p swt3-fake-true)
    (swt3-stub 'swcad-title-source-title-candidates swt3-fake-nil)
    (swt3-stub 'swcad-title-write-native-autoselect-batch-summary swt3-fake-nil3)
    (swt3-stub 'swcad-title-transfer-batch-run (car item))
    (swcad-title-transfer-native-autoselect-all)
    (swt3-unstub-all)
    (swt3-check (caddr item) (swt3-status) (cadr item))
    (swt3-check (strcat (caddr item) "-batch-mode") *swcad-title-batch-mode* nil)
  )

  ;; 5. Title-missing batch.
  (defun swt3-fake-fo-candidates (/) (if (> *swt3-fo-remaining* 0) (list 'x) nil))
  (defun swt3-fake-fo-error () (setq *swt3-fo-remaining* 0) (car "injected-error"))
  (defun swt3-fake-fo-not-reduced () (setq *swcad-title-last-apply-status* "FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER"))
  (defun swt3-fake-fo-done () (setq *swt3-fo-remaining* 0) (setq *swcad-title-last-apply-status* "FINALIZED_TITLE_MISSING_OUTLINE_TRANSFER"))
  (foreach item (list
                  (list swt3-fake-fo-error "ERROR_TITLE_MISSING_OUTLINE_BATCH_APPLY" "title-missing-error-after-last-sheet")
                  (list swt3-fake-fo-not-reduced "REVIEW_TITLE_MISSING_OUTLINE_NOT_REDUCED" "title-missing-count-not-reduced")
                  (list swt3-fake-fo-done "OK_TITLE_MISSING_OUTLINE_BATCH_COMPLETE" "title-missing-done-ok")
                )
    (swt3-reset-state)
    (setq *swt3-fo-remaining* 1)
    (swt3-stub 'swcad-title-frame-only-source-candidates swt3-fake-fo-candidates)
    (swt3-stub 'swcad-title-gmtitle-autoselect-available-p swt3-fake-true)
    (swt3-stub 'swcad-title-write-title-missing-batch-summary swt3-fake-nil3)
    (swt3-stub 'swcad-title-transfer-title-missing-outline-apply (car item))
    (swcad-title-transfer-title-missing-outline-all)
    (swt3-unstub-all)
    (swt3-check (caddr item) (swt3-status) (cadr item))
    (swt3-check (strcat (caddr item) "-flags") (list *swcad-title-batch-mode* *swcad-title-allow-batch-interactive-native-gmtitle*) '(nil nil))
  )

  ;; 6. A2/A3/A4 batch: error outside its per-sheet catch.
  (defun swt3-fake-a3a4-batch-error ()
    (setq *swcad-title-native-upgrade-batch-mode* T)
    (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
    (setq *swcad-title-native-upgrade-selected-pair* (list e e "DR_A3_Outline"))
    (setq *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE")
    (car "injected-error")
  )
  (foreach fn (list 'swcad-title-upgrade-native-a3a4-all 'swcad-title-upgrade-native-a3a4-batch-manual)
    (swt3-reset-state)
    (swt3-stub 'swcad-title-upgrade-native-a3a4-batch swt3-fake-a3a4-batch-error)
    (apply fn nil)
    (swt3-unstub-all)
    (swt3-check (strcat (vl-symbol-name fn) "-error-status") (swt3-status) "ERROR_NATIVE_GMTITLE_UPGRADE_BATCH")
    (swt3-check
      (strcat (vl-symbol-name fn) "-error-flags")
      (list *swcad-title-native-upgrade-batch-mode* *swcad-title-allow-batch-interactive-native-gmtitle* *swcad-title-native-upgrade-selected-pair* *swcad-title-a3a4-batch-default-all*)
      '(nil nil nil nil)
    )
  )

  ;; 7. A2/A3/A4 OPEN: error in the one-sheet replacement.
  (defun swt3-fake-a3a4-records (/) (list (list e e "DR_A3_Outline")))
  (defun swt3-fake-reason (record) "probe")
  (defun swt3-fake-open-answer (a b c) "OPEN")
  (swt3-reset-state)
  (swt3-stub 'swcad-title-a3a4-native-upgrade-candidate-records swt3-fake-a3a4-records)
  (swt3-stub 'swcad-title-target-pair-upgrade-reason swt3-fake-reason)
  (swt3-stub 'swcad-title-auto-next-answer-or-prompt swt3-fake-open-answer)
  (swt3-stub 'swcad-title-upgrade-native-one swt3-fake-stopped-runner)
  (swcad-title-upgrade-native-a3a4-next)
  (swt3-unstub-all)
  (swt3-check "a3a4-open-error-status" (swt3-status) "ERROR_NATIVE_GMTITLE_UPGRADE_OPEN")
  (swt3-check "a3a4-open-error-pair-cleared" *swcad-title-native-upgrade-selected-pair* nil)
  (swt3-check "a3a4-open-error-skip-restored" *swcad-title-skip-native-upgrade-confirmation* nil)
  (swt3-check "a3a4-open-error-osmode" (getvar "OSMODE") 37)

  ;; 8. SWTITLECONVERTNEXT outer catch.
  (defun swt3-fake-convert-error ()
    (setq *swcad-title-batch-mode* T)
    (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
    (swt3-fake-stopped-runner)
  )
  (swt3-reset-state)
  (swt3-stub 'swcad-title-integrated-convert swt3-fake-convert-error)
  (swcad-title-integrated-convert-next)
  (swt3-unstub-all)
  (swt3-check "convert-next-error-status" (swt3-status) "ERROR_CONVERT_NEXT_FATAL")
  (swt3-check
    "convert-next-error-flags"
    (list *swcad-title-batch-mode* *swcad-title-allow-batch-interactive-native-gmtitle* *swcad-title-convert-next-mode*)
    '(nil nil nil)
  )
  (swt3-check "convert-next-error-osmode" (getvar "OSMODE") 37)

  ;; 9. SWTITLECONVERT: a branch that leaves no status is not done; a stale status is not reused.
  (swt3-reset-state)
  (setq *swcad-title-last-apply-status* "OK_STALE_FROM_BEFORE")
  (setq *swcad-title-pending-manual-native-upgrade* (list (cons "probe" 1)))
  (swt3-stub 'swcad-title-script-active-p swt3-fake-nil)
  (swt3-stub 'swcad-title-active-dwg-confirmed-p swt3-fake-true)
  (swt3-stub 'swcad-title-upgrade-native-a3a4-finish swt3-fake-nil)
  (swcad-title-integrated-convert)
  (swt3-unstub-all)
  (setq *swcad-title-pending-manual-native-upgrade* nil)
  (swt3-check "convert-no-status-is-review" (swt3-status) "REVIEW_CONVERT_RESULT_UNKNOWN")

  ;; 9b. A stop in the clone or fast batch step is not covered by the next A2/A3/A4 step.
  (setq *swt3-a3a4-on* nil)
  (setq *swt3-a3a4-next-called* nil)
  (defun swt3-fake-a3a4-candidates (/) (if *swt3-a3a4-on* (list (list e e "DR_A3_Outline")) nil))
  (defun swt3-fake-summary-source-only (summary key) (if (= key "source-title-count") 1 0))
  (defun swt3-fake-clone-review () (setq *swt3-a3a4-on* T) (setq *swcad-title-last-apply-status* "REVIEW_OLD_TITLE_NOT_DELETED"))
  (defun swt3-fake-fast-warn () (setq *swt3-a3a4-on* T) (setq *swcad-title-last-apply-status* "WARN_FAST_BATCH_REMAINING_SOURCES"))
  (defun swt3-fake-a3a4-next () (setq *swt3-a3a4-next-called* T) (setq *swcad-title-last-apply-status* "UPGRADED_CLONE_TO_NATIVE_GMTITLE"))
  (defun swt3-fake-example (/) e)
  (foreach item (list
                  (list T 'swcad-title-transfer-clone-apply swt3-fake-clone-review "REVIEW_OLD_TITLE_NOT_DELETED" "convert-next-clone-stop-kept")
                  (list nil 'swcad-title-transfer-fast-batch swt3-fake-fast-warn "WARN_FAST_BATCH_REMAINING_SOURCES" "convert-fast-batch-stop-kept")
                )
    (swt3-reset-state)
    (setq *swt3-a3a4-on* nil)
    (setq *swt3-a3a4-next-called* nil)
    (swt3-stub 'swcad-title-script-active-p swt3-fake-nil)
    (swt3-stub 'swcad-title-active-dwg-confirmed-p swt3-fake-true)
    (swt3-stub 'swcad-title-fast-sheet-summary swt3-fake-nil)
    (swt3-stub 'swcad-title-fast-summary-value swt3-fake-summary-source-only)
    (swt3-stub 'swcad-title-command-text-residue-records swt3-fake-nil)
    (swt3-stub 'swcad-title-a3a4-native-upgrade-candidate-records swt3-fake-a3a4-candidates)
    (swt3-stub 'swcad-title-native-example-title swt3-fake-example)
    (swt3-stub 'swcad-title-missing-required-native-frame-blocks swt3-fake-nil1)
    (swt3-stub 'swcad-title-frame-style-normalization-records swt3-fake-nil)
    (swt3-stub 'swcad-title-frame-definition-blocking-records swt3-fake-nil)
    (swt3-stub 'swcad-title-frame-definition-raw-bbox-risk-records swt3-fake-nil)
    (swt3-stub 'swcad-title-orphan-target-frame-records swt3-fake-nil)
    (swt3-stub 'swcad-title-print-fast-sheet-summary swt3-fake-nil1)
    (swt3-stub 'swcad-title-next-fast-target-ready-p swt3-fake-true)
    (swt3-stub 'swcad-title-gmtitle-autoselect-available-p swt3-fake-nil)
    (swt3-stub 'swcad-title-upgrade-native-a3a4-next swt3-fake-a3a4-next)
    (swt3-stub (nth 1 item) (nth 2 item))
    (setq *swcad-title-convert-next-mode* (nth 0 item))
    (swcad-title-integrated-convert)
    (setq *swcad-title-convert-next-mode* nil)
    (swt3-unstub-all)
    (swt3-check (nth 4 item) (list (swt3-status) *swt3-a3a4-next-called*) (list (nth 3 item) nil))
  )

  ;; 9c. Fast batch phases: a stop on the last clone sheet does not become OK.
  (setq *swt3-source-calls* 0)
  (defun swt3-fake-source-count (/) (setq *swt3-source-calls* (1+ *swt3-source-calls*)) (if (= *swt3-source-calls* 1) 1 0))
  (defun swt3-fake-clone-batch-review (count) (setq *swcad-title-last-apply-status* "REVIEW_OLD_TITLE_NOT_DELETED"))
  (defun swt3-fake-zero (/) 0)
  (swt3-reset-state)
  (swt3-stub 'swcad-title-source-title-count swt3-fake-source-count)
  (swt3-stub 'swcad-title-transfer-clone-batch-run swt3-fake-clone-batch-review)
  (swt3-stub 'swcad-title-frame-only-source-count swt3-fake-zero)
  (swt3-stub 'swcad-title-fast-sheet-summary swt3-fake-nil)
  (swt3-stub 'swcad-title-print-fast-sheet-summary swt3-fake-nil1)
  (swt3-stub 'swcad-title-contaminated-target-frame-blocks swt3-fake-nil)
  (swcad-title-run-fast-batch-phases)
  (swt3-unstub-all)
  (swt3-check "fast-batch-phases-stop-kept" (swt3-status) "REVIEW_OLD_TITLE_NOT_DELETED")

  ;; 10. SWTITLEPREPARE keeps the first stop.
  (defun swt3-fake-summary-value (summary key) 0)
  (defun swt3-fake-clean-abort () (swcad-title-apply-result "ABORT_COMMAND_TEXT_CLEAN_USER"))
  (defun swt3-fake-clean-ok () (swcad-title-apply-result "OK_FRAME_DEF_TITLE_CHILDREN_CLEANED"))
  (defun swt3-fake-clean-warn () (swcad-title-apply-result "WARN_RESIDUE_REMAINS"))
  (foreach item (list
                  (list swt3-fake-list1 swt3-fake-clean-abort swt3-fake-list1 swt3-fake-clean-ok "ABORT_COMMAND_TEXT_CLEAN_USER" "prepare-first-stop-kept")
                  (list swt3-fake-list1 swt3-fake-clean-ok swt3-fake-list1 swt3-fake-clean-warn "WARN_RESIDUE_REMAINS" "prepare-later-warn-kept")
                  (list swt3-fake-list1 swt3-fake-clean-ok swt3-fake-nil swt3-fake-clean-ok "OK_FRAME_DEF_TITLE_CHILDREN_CLEANED" "prepare-ok-kept")
                  (list swt3-fake-nil swt3-fake-clean-ok swt3-fake-nil swt3-fake-clean-ok "OK_PREPARE_DONE" "prepare-nothing-to-clean")
                )
    (swt3-reset-state)
    (setq *swcad-title-last-apply-status* "OK_STALE_FROM_BEFORE")
    (swt3-stub 'swcad-title-script-active-p swt3-fake-nil)
    (swt3-stub 'swcad-title-active-dwg-confirmed-p swt3-fake-true)
    (swt3-stub 'swcad-title-fast-sheet-summary swt3-fake-nil)
    (swt3-stub 'swcad-title-fast-summary-value swt3-fake-summary-value)
    (swt3-stub 'swcad-title-frame-def-check swt3-fake-nil)
    (swt3-stub 'swcad-title-native-frame-completion-check swt3-fake-nil)
    (swt3-stub 'swcad-title-command-text-residue-records (nth 0 item))
    (swt3-stub 'swcad-title-command-text-clean-safe (nth 1 item))
    (swt3-stub 'swcad-title-frame-def-title-child-records (nth 2 item))
    (swt3-stub 'swcad-title-clean-frame-def-title-children (nth 3 item))
    (swt3-stub 'swcad-title-frame-embedded-title-records swt3-fake-nil)
    (swt3-stub 'swcad-title-frame-style-normalization-records swt3-fake-nil)
    (swt3-stub 'swcad-title-frame-definition-blocking-records swt3-fake-nil)
    (swt3-stub 'swcad-title-frame-definition-blocking-records-by-class swt3-fake-nil1)
    (swt3-stub 'swcad-title-frame-definition-raw-bbox-risk-records swt3-fake-nil)
    (swt3-stub 'swcad-title-title-missing-outline-definition-needed-p swt3-fake-nil)
    (swt3-stub 'swcad-title-orphan-target-frame-records swt3-fake-nil)
    (swt3-stub 'swcad-title-duplicate-target-pair-records swt3-fake-nil)
    (swcad-title-integrated-prepare)
    (swt3-unstub-all)
    (swt3-check (nth 5 item) (swt3-status) (nth 4 item))
  )

  ;; 11. frame-def-clean-safe now records its result.
  (swt3-reset-state)
  (swt3-stub 'swcad-title-document-read-only-p swt3-fake-true)
  (swcad-title-frame-def-clean-safe)
  (swt3-unstub-all)
  (swt3-check "frame-def-clean-records-status" (swt3-status) "ABORT_READ_ONLY_DOCUMENT")

  ;; 12. Command entry puts back what a stopped command left.
  (swt3-reset-state)
  (swcad-title-read-scan-cache-begin)
  (swcad-title-frame-style-analysis-cache-begin)
  (setq *swcad-title-batch-mode* T)
  (setq *swcad-title-convert-next-mode* T)
  (setq *swcad-title-native-upgrade-batch-mode* T)
  (setq *swcad-title-allow-batch-interactive-native-gmtitle* T)
  (setq *swcad-title-a3a4-batch-default-all* T)
  (setq *swcad-title-pending-manual-native-upgrade* (list (cons "probe" 1)))
  (swcad-title-open-log "swt3_entry_reset_probe.txt" "probe")
  (swcad-title-remember-gmtitle-input-vars 37 (swcad-title-safe-getvar "DYNMODE"))
  (setvar "OSMODE" 0)
  (vla-StartUndoMark (swcad-title-doc))
  (swcad-title-command-entry-reset)
  (swt3-check
    "entry-reset-flags"
    (list
      *swcad-title-read-scan-cache-enabled*
      *swcad-title-frame-style-analysis-cache-enabled*
      *swcad-title-batch-mode*
      *swcad-title-convert-next-mode*
      *swcad-title-native-upgrade-batch-mode*
      *swcad-title-allow-batch-interactive-native-gmtitle*
      *swcad-title-a3a4-batch-default-all*
      *swcad-title-debug-log-handle*
    )
    '(nil nil nil nil nil nil nil nil)
  )
  (swt3-check "entry-reset-keeps-manual-upgrade" (if *swcad-title-pending-manual-native-upgrade* T nil) T)
  (setq *swcad-title-pending-manual-native-upgrade* nil)
  (swt3-check "entry-reset-osmode" (getvar "OSMODE") 37)

  ;; 13. SWCADRUN title step: no result stops, a result continues.
  (defun swt3-fake-diagnosis (/) "SWTITLEVERIFY")
  (defun swt3-fake-verify-ok (/) (setq *swcad-title-last-apply-status* "SWTITLEVERIFY_FINAL_OK"))
  (foreach item (list
                  (list swt3-fake-nil nil "REVIEW_TITLE_STEP_NO_RESULT" "run-title-next-no-result-stops")
                  (list swt3-fake-verify-ok T "SWTITLEVERIFY_FINAL_OK" "run-title-next-result-continues")
                )
    (swt3-reset-state)
    (swt3-stub 'swcad-title-integrated-structure-diagnosis swt3-fake-diagnosis)
    (swt3-stub 'c:SWTITLEVERIFY (car item))
    (setq r (swapp-run-title-next))
    (swt3-unstub-all)
    (swt3-check (nth 3 item) (list (if r T nil) (swt3-status)) (list (cadr item) (caddr item)))
  )
  (swt3-check "recommended-after-no-result" (swapp-recommended-next-action "TITLE" "REVIEW_TITLE_STEP_NO_RESULT") "SWCADRUN 반복 금지 - 현재 도면을 저장하지 말고 오류 원인을 확인하세요")

  (write-line "Step3 unit part completed: yes" *swt3-log*)
  (close *swt3-log*)
  (setq *swt3-log* nil)

  ;; 14. SWCADRUN *error*: an error no step catches.  The check runs in the next
  ;; script line (title_stop_probe_after.lsp), after the error unwinds.
  (swt3-reset-state)
  (defun swt3-fake-stage (/) "TITLE")
  (setq *swt3-orig-stage* swapp-workflow-stage)
  (setq *swt3-orig-title-next* swapp-run-title-next)
  (setq swapp-workflow-stage swt3-fake-stage)
  (setq swapp-run-title-next swt3-fake-stopped-runner)
  (c:SWCADRUN)
)

(swt3-main)
