;;; Synthetic probe for the A3/A4 BATCH automation guard.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LSP
;;;   SWCAD_COMPARE_LOG
;;; This script modifies only the copied probe DWG and does not save it.

(vl-load-com)

(defun swtitle-batchguard-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-batchguard-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-batchguard-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-batchguard-symbol-present-p (symbol-name / found symbol value)
  (setq found (atoms-family 1 (list (strcase symbol-name))))
  (if found
    (progn
      (setq symbol (read symbol-name))
      (setq value (vl-catch-all-apply 'eval (list symbol)))
      (if (vl-catch-all-error-p value) nil (if value T nil))
    )
    nil
  )
)

(defun swtitle-batchguard-delete-all-inserts (/ ss index ename)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq index 0)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index))
      (vl-catch-all-apply 'entdel (list ename))
      (setq index (+ index 1))
    )
  )
)

(defun swtitle-batchguard-insert-count (/ ss)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (if ss (sslength ss) 0)
)

(defun swtitle-batchguard-ensure-rect-block (name width height /)
  (if (not (tblsearch "BLOCK" name))
    (progn
      (entmake (list '(0 . "BLOCK") (cons 2 name) '(70 . 0) '(10 0.0 0.0 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") '(10 0.0 0.0 0.0) (list 11 width 0.0 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") (list 10 width 0.0 0.0) (list 11 width height 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") (list 10 width height 0.0) (list 11 0.0 height 0.0)))
      (entmake (list '(0 . "LINE") '(8 . "0") (list 10 0.0 height 0.0) '(11 0.0 0.0 0.0)))
      (entmake '((0 . "ENDBLK")))
    )
  )
  name
)

(defun swtitle-batchguard-insert-block (name point /)
  (entmake
    (list
      '(0 . "INSERT")
      (cons 2 name)
      (cons 10 point)
      '(41 . 1.0)
      '(42 . 1.0)
      '(43 . 1.0)
      '(50 . 0.0)
    )
  )
  (entlast)
)

(defun swtitle-batchguard-mark-pair (title frame frame-name /)
  (if (swtitle-batchguard-symbol-present-p "SWCAD-TITLE-MARK-NATIVE-EXEMPLAR-PAIR")
    (swcad-title-mark-native-exemplar-pair title frame frame-name "clone")
  )
)

(defun swtitle-batchguard-create-pair (base-x / frame title)
  (setq frame (swtitle-batchguard-insert-block "DR_A3_Outline" (list base-x 0.0 0.0)))
  (setq title (swtitle-batchguard-insert-block "DR_titlea_3rd" (list (+ base-x 230.0) 10.0 0.0)))
  (swtitle-batchguard-mark-pair title frame "DR_A3_Outline")
  (list frame title)
)

(defun swtitle-batchguard-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<missing>"
  )
)

(defun swtitle-batchguard-main (/ root lsp-path log-path handle load-result load-ok version-value pair1 pair2 before-candidates after-candidates before-inserts after-inserts batch-result status pass)
  (setq root (swtitle-batchguard-root))
  (setq lsp-path
    (swtitle-batchguard-env-path
      "SWCAD_COMPARE_LSP"
      (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-batchguard-env-path
      "SWCAD_COMPARE_LOG"
      (strcat root "/work/swtitle_a3a4_batch_guard_probe.txt")
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
      (swtitle-batchguard-write-line handle "SWTITLE A3/A4 batch guard probe")
      (swtitle-batchguard-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-batchguard-write-line handle "Load result: OK")
        (swtitle-batchguard-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-batchguard-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-batchguard-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-batchguard-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (swtitle-batchguard-write-line handle (strcat "Script active: " (if (swcad-title-script-active-p) "yes" "no")))
      (if load-ok
        (progn
          (setq *swcad-title-log-file-suffix* "_a3a4_batch_guard_probe")
          (swtitle-batchguard-delete-all-inserts)
          (swtitle-batchguard-ensure-rect-block "DR_A3_Outline" 420.0 297.0)
          (swtitle-batchguard-ensure-rect-block "DR_titlea_3rd" 180.0 42.0)
          (setq pair1 (swtitle-batchguard-create-pair 0.0))
          (setq pair2 (swtitle-batchguard-create-pair 500.0))
          (setq before-candidates (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (setq before-inserts (swtitle-batchguard-insert-count))
          (setq batch-result (vl-catch-all-apply 'swcad-title-upgrade-native-a3a4-batch nil))
          (setq status (swtitle-batchguard-status-value))
          (setq after-candidates (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (setq after-inserts (swtitle-batchguard-insert-count))
          (if (vl-catch-all-error-p batch-result)
            (swtitle-batchguard-write-line handle (strcat "Batch result: ERROR - " (vl-catch-all-error-message batch-result)))
            (swtitle-batchguard-write-line handle "Batch result: OK")
          )
          (swtitle-batchguard-write-line handle (strcat "Status after batch: " status))
          (swtitle-batchguard-write-line handle (strcat "Candidates before/after: " (itoa before-candidates) "/" (itoa after-candidates)))
          (swtitle-batchguard-write-line handle (strcat "INSERT count before/after: " (itoa before-inserts) "/" (itoa after-inserts)))
          (setq pass
            (and
              (= before-candidates 2)
              (= after-candidates 2)
              (= before-inserts after-inserts)
              (equal status "ABORT_NATIVE_A3A4_BATCH_SCRIPT_ACTIVE")
            )
          )
          (swtitle-batchguard-write-line handle (strcat "Batch guard preserved candidates: " (if pass "yes" "no")))
        )
      )
      (swtitle-batchguard-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-batchguard-main)
