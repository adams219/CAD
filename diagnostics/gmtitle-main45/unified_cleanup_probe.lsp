;;; Focused copied-DWG cleanup probe. It performs one normalization and saves.
;;; Full structural/value verification is intentionally a separate read-only probe.

(defun swtitle-cleanup-probe-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-cleanup-probe-path (relative)
  (strcat (swtitle-cleanup-probe-root) "/" relative)
)

(defun swtitle-cleanup-probe-write (handle value)
  (write-line (if value value "") handle)
)

(defun swtitle-cleanup-probe-native-like-count (records / count record)
  (setq count 0)
  (foreach record records
    (if (swcad-title-target-pair-native-like-p record)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swtitle-cleanup-probe-existing-handle-count (handles / count item)
  (setq count 0)
  (foreach item handles
    (if (handent item) (setq count (+ count 1)))
  )
  count
)

(defun swtitle-cleanup-probe-main (/ *error* load-result load-ok log-path handle version style-before delete-before residue-before pair-before native-before cleanup-result cleanup-status style-after delete-after residue-after pair-records pair-after native-after frame-after title-after orphan-after protected-note-handles protected-note-count save-result save-ok)
  (setq load-result
    (vl-catch-all-apply
      'load
      (list (swtitle-cleanup-probe-path "src/tools/gmtitle/swcad_title_scale.lsp"))
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq log-path (getenv "SWCAD_UNIFIED_CLEANUP_LOG"))
  (if (or (not log-path) (= (strlen log-path) 0))
    (setq log-path (swtitle-cleanup-probe-path "work/swtitle_unified_cleanup_probe.txt"))
  )
  (setq log-path (vl-string-translate "\\" "/" log-path))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (defun *error* (msg)
        (swcad-title-frame-style-analysis-cache-end)
        (if handle
          (progn
            (swtitle-cleanup-probe-write handle (strcat "Probe runtime error: " (if msg msg "<unknown>")))
            (swtitle-cleanup-probe-write handle "Probe result: FAIL")
            (swtitle-cleanup-probe-write handle "Runtime check completed: yes")
            (close handle)
            (setq handle nil)
          )
        )
        (princ)
      )
      (swtitle-cleanup-probe-write handle "SWTITLE unified focused cleanup probe")
      (swtitle-cleanup-probe-write handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (if load-ok
        (progn
          (setq version (if (boundp '*swcad-title-scale-version*) *swcad-title-scale-version* "<missing>"))
          (swcad-title-frame-style-analysis-cache-begin)
          (setq style-before (swcad-title-frame-style-normalization-records))
          (setq delete-before (swcad-title-frame-style-records-from-pairs style-before 12))
          (setq residue-before (swcad-title-frame-style-records-from-pairs style-before 13))
          (setq pair-before (swcad-title-target-gmtitle-pair-records))
          (setq native-before (swtitle-cleanup-probe-native-like-count pair-before))
          (setq cleanup-result (vl-catch-all-apply 'swcad-title-frame-style-normalization-clean nil))
          (setq cleanup-status (if (boundp '*swcad-title-last-apply-status*) *swcad-title-last-apply-status* "<missing>"))
          (setq style-after (swcad-title-frame-style-normalization-records))
          (setq delete-after (swcad-title-frame-style-records-from-pairs style-after 12))
          (setq residue-after (swcad-title-frame-style-records-from-pairs style-after 13))
          (setq pair-records (swcad-title-target-gmtitle-pair-records))
          (setq pair-after (length pair-records))
          (setq native-after (swtitle-cleanup-probe-native-like-count pair-records))
          (setq frame-after (length (swcad-title-frame-records)))
          (setq title-after (length (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))))
          (setq orphan-after (length (swcad-title-orphan-target-frame-records)))
          (setq protected-note-handles '("36EB" "36EA" "36E9" "36E8" "5299" "5298" "5297" "5296"))
          (setq protected-note-count (swtitle-cleanup-probe-existing-handle-count protected-note-handles))
          (swcad-title-frame-style-analysis-cache-end)
          (setq save-result (vl-catch-all-apply 'vla-Save (list (swcad-title-doc))))
          (setq save-ok (not (vl-catch-all-error-p save-result)))
          (swtitle-cleanup-probe-write handle (strcat "Loaded version: " version))
          (swtitle-cleanup-probe-write handle (strcat "Before style/delete/residue: " (itoa (length style-before)) "/" (itoa (length delete-before)) "/" (itoa (length residue-before))))
          (swtitle-cleanup-probe-write handle (strcat "Before pair/native-like: " (itoa (length pair-before)) "/" (itoa native-before)))
          (swtitle-cleanup-probe-write handle (strcat "Cleanup call: " (if (vl-catch-all-error-p cleanup-result) (strcat "ERROR - " (vl-catch-all-error-message cleanup-result)) "OK")))
          (swtitle-cleanup-probe-write handle (strcat "Cleanup status: " cleanup-status))
          (swtitle-cleanup-probe-write handle (strcat "After style/delete/residue: " (itoa (length style-after)) "/" (itoa (length delete-after)) "/" (itoa (length residue-after))))
          (swtitle-cleanup-probe-write handle (strcat "After frame/title/pair/native-like/orphan: " (itoa frame-after) "/" (itoa title-after) "/" (itoa pair-after) "/" (itoa native-after) "/" (itoa orphan-after)))
          (swtitle-cleanup-probe-write handle (strcat "Protected A4 note handles remaining: " (itoa protected-note-count)))
          (swtitle-cleanup-probe-write handle (strcat "Saved cleaned probe DWG: " (if save-ok "yes" "no")))
          (swtitle-cleanup-probe-write
            handle
            (strcat
              "Probe result: "
              (if
                (and
                  (equal version "260711-unified-title-value-3")
                  (not (vl-catch-all-error-p cleanup-result))
                  (equal cleanup-status "OK_FRAME_STYLE_NORMALIZATION_CLEANED")
                  (= (length style-before) 15)
                  (= (length delete-before) 52)
                  (= (length residue-before) 52)
                  (= (length style-after) 0)
                  (= (length delete-after) 0)
                  (= (length residue-after) 0)
                  (= (length pair-before) 15)
                  (= native-before 15)
                  (= frame-after 15)
                  (= title-after 15)
                  (= pair-after 15)
                  (= native-after 15)
                  (= orphan-after 0)
                  (= protected-note-count 8)
                  save-ok
                )
                "PASS"
                "FAIL"
              )
            )
          )
        )
        (progn
          (swtitle-cleanup-probe-write handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
          (swtitle-cleanup-probe-write handle "Probe result: FAIL")
        )
      )
      (swtitle-cleanup-probe-write handle "Runtime check completed: yes")
      (close handle)
      (setq handle nil)
    )
  )
  (princ)
)

(swtitle-cleanup-probe-main)
