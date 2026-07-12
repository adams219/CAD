;;; Sheet-size-independent source-title-missing fixture probe.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT, SWCAD_STM_LOG,
;;; SWCAD_STM_MODE (GAP/PREPARE/SCRIPT_GUARD), and SWCAD_STM_SHEET (A2/A3/A4).
;;; This probe runs only on a disposable copied DWG and never saves it.

(vl-load-com)

(defun swtitle-stm-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-stm-path (relative)
  (strcat (swtitle-stm-root) "/" relative)
)

(defun swtitle-stm-write-line (handle value)
  (write-line (if value value "") handle)
)

(defun swtitle-stm-env-value (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0)) fallback value)
)

(defun swtitle-stm-mode ()
  (strcase (swtitle-stm-env-value "SWCAD_STM_MODE" "GAP"))
)

(defun swtitle-stm-sheet (/ value)
  (setq value (strcase (swtitle-stm-env-value "SWCAD_STM_SHEET" "A3")))
  (if (member value '("A2" "A3" "A4")) value "A3")
)

(defun swtitle-stm-status-value ()
  (if (and (boundp '*swcad-title-last-apply-status*) *swcad-title-last-apply-status*)
    (swcad-title-string *swcad-title-last-apply-status*)
    "<none>"
  )
)

(defun swtitle-stm-clear-model-space (/ doc layers layer space items item deleted result)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq layers (vla-get-Layers doc))
  (vlax-for layer layers
    (vl-catch-all-apply 'vla-put-Lock (list layer :vlax-false))
  )
  (setq space (vla-get-ModelSpace doc))
  (setq items nil)
  (vlax-for item space
    (setq items (cons item items))
  )
  (setq deleted 0)
  (foreach item items
    (setq result (vl-catch-all-apply 'vla-Delete (list item)))
    (if (not (vl-catch-all-error-p result))
      (setq deleted (+ deleted 1))
    )
  )
  deleted
)

(defun swtitle-stm-park-block (name / backup)
  (if (swcad-title-block-exists-p name)
    (progn
      (setq backup (swcad-title-unique-block-name (strcat name "_STM_BACKUP")))
      (swcad-title-rename-block-definition name backup)
    )
    T
  )
)

(defun swtitle-stm-block-begin (name)
  (entmake
    (list
      '(0 . "BLOCK")
      (cons 2 name)
      '(70 . 0)
      (cons 10 (list 0.0 0.0 0.0))
    )
  )
)

(defun swtitle-stm-line (start end)
  (entmakex
    (list
      '(0 . "LINE")
      '(8 . "0")
      (cons 10 (append start (list 0.0)))
      (cons 11 (append end (list 0.0)))
    )
  )
)

(defun swtitle-stm-create-source-frame (sheet / dims width height name insert)
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq width (car dims))
  (setq height (cadr dims))
  (setq name (strcat "SWCAD_SOURCE_FRAME_" sheet "_NOATTR"))
  (swtitle-stm-park-block name)
  (if (swtitle-stm-block-begin name)
    (progn
      (swtitle-stm-line (list 0.0 0.0) (list width 0.0))
      (swtitle-stm-line (list width 0.0) (list width height))
      (swtitle-stm-line (list width height) (list 0.0 height))
      (swtitle-stm-line (list 0.0 height) (list 0.0 0.0))
      (entmake '((0 . "ENDBLK")))
      (setq insert
        (entmakex
          (list
            '(0 . "INSERT")
            '(8 . "0")
            (cons 2 name)
            (cons 10 (list 0.0 0.0 0.0))
            '(41 . 1.0)
            '(42 . 1.0)
            '(43 . 1.0)
            '(50 . 0.0)
          )
        )
      )
      (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) 1)
      insert
    )
    nil
  )
)

(defun swtitle-stm-target-title-count ()
  (length (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name)))
)

(defun swtitle-stm-target-frame-count (frame-name)
  (length (swcad-title-inserts-by-effective-name frame-name))
)

(defun swtitle-stm-summary-value (summary key)
  (itoa (swcad-title-fast-summary-value summary key))
)

(defun swtitle-stm-summary-valid-p (summary)
  (and
    (= (swcad-title-fast-summary-value summary "source-title-count") 0)
    (= (swcad-title-fast-summary-value summary "source-frame-count") 1)
    (= (swcad-title-fast-summary-value summary "frame-only-count") 1)
  )
)

(defun swtitle-stm-write-summary (handle prefix summary)
  (swtitle-stm-write-line handle (strcat prefix " source-title-count: " (swtitle-stm-summary-value summary "source-title-count")))
  (swtitle-stm-write-line handle (strcat prefix " source-frame-count: " (swtitle-stm-summary-value summary "source-frame-count")))
  (swtitle-stm-write-line handle (strcat prefix " frame-only-count: " (swtitle-stm-summary-value summary "frame-only-count")))
)

(defun swtitle-stm-run (/ log-path handle load-result load-ok mode sheet frame-name cleared source-frame source-bbox setup-summary setup-valid definition-before prepare-result prepare-status definition-after definition-ready convert-result convert-status final-summary source-preserved target-title-count target-frame-count raw-risk result-pass)
  (setq log-path (swtitle-stm-env-value "SWCAD_STM_LOG" (swtitle-stm-path "work/swtitle_source_title_missing_common_probe.txt")))
  (setq log-path (vl-string-translate "\\" "/" log-path))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-stm-write-line handle "SWTITLE common source-title-missing fixture probe")
      (setq load-result
        (vl-catch-all-apply
          'load
          (list (swtitle-stm-path "src/tools/gmtitle/swcad_title_scale.lsp"))
        )
      )
      (setq load-ok (not (vl-catch-all-error-p load-result)))
      (if load-ok
        (progn
          (setq *swcad-title-debug-log-handle* handle)
          (setq *swcad-title-debug-log-path* log-path)
          (swtitle-stm-write-line handle "Load result: OK")
          (swtitle-stm-write-line handle (strcat "Loaded version: " *swcad-title-scale-version*))
          (setq mode (swtitle-stm-mode))
          (setq sheet (swtitle-stm-sheet))
          (setq frame-name (swcad-title-target-frame-block-name-for-sheet sheet))
          (swtitle-stm-write-line handle (strcat "Fixture mode: " mode))
          (swtitle-stm-write-line handle (strcat "Fixture sheet: " sheet))
          (swtitle-stm-write-line handle (strcat "Expected target frame: " frame-name))
          (swtitle-stm-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (setq cleared (swtitle-stm-clear-model-space))
          (swtitle-stm-park-block frame-name)
          (setq source-frame (swtitle-stm-create-source-frame sheet))
          (setq source-bbox (if source-frame (swcad-title-safe-bbox source-frame) nil))
          (setq setup-summary (swcad-title-fast-sheet-summary))
          (setq setup-valid (and source-frame (swtitle-stm-summary-valid-p setup-summary)))
          (setq definition-before (swcad-title-title-missing-outline-definition-status))
          (swtitle-stm-write-line handle (strcat "Cleared model objects: " (itoa cleared)))
          (swtitle-stm-write-line handle (strcat "Source frame handle: " (if source-frame (swcad-title-ename-handle source-frame) "<none>")))
          (swtitle-stm-write-line handle (strcat "Source frame bbox: " (swcad-title-bbox-string source-bbox)))
          (swtitle-stm-write-summary handle "Before" setup-summary)
          (swtitle-stm-write-line handle (strcat "Before definition status: " definition-before))
          (swtitle-stm-write-line handle (strcat "Before target title count: " (itoa (swtitle-stm-target-title-count))))
          (swtitle-stm-write-line handle (strcat "Before target frame count: " (itoa (swtitle-stm-target-frame-count frame-name))))

          (setq prepare-status "<not-run>")
          (setq definition-after definition-before)
          (setq definition-ready nil)
          (setq convert-status "<not-run>")
          (if (member mode '("PREPARE" "SCRIPT_GUARD"))
            (progn
              (setq prepare-result (vl-catch-all-apply 'swcad-title-prepare-title-missing-outline-definition nil))
              (setq prepare-status
                (if (vl-catch-all-error-p prepare-result)
                  (strcat "ERROR - " (vl-catch-all-error-message prepare-result))
                  (swtitle-stm-status-value)
                )
              )
              (setq definition-after (swcad-title-title-missing-outline-definition-status))
              (setq definition-ready (swcad-title-title-missing-outline-definition-ready-p))
              (swtitle-stm-write-line handle (strcat "Prepare status: " prepare-status))
              (swtitle-stm-write-line handle (strcat "After definition status: " definition-after))
              (swtitle-stm-write-line handle (strcat "After definition ready: " (if definition-ready "yes" "no")))
              (setq raw-risk (swcad-title-frame-definition-raw-bbox-risk-record frame-name))
              (swtitle-stm-write-line handle (strcat "After definition raw bbox risk: " (if raw-risk "yes" "no")))
            )
          )
          (if (equal mode "SCRIPT_GUARD")
            (progn
              (setq convert-result (vl-catch-all-apply 'swcad-title-transfer-title-missing-outline-apply nil))
              (setq convert-status
                (if (vl-catch-all-error-p convert-result)
                  (strcat "ERROR - " (vl-catch-all-error-message convert-result))
                  (swtitle-stm-status-value)
                )
              )
              (swtitle-stm-write-line handle (strcat "Convert status: " convert-status))
            )
          )

          (setq final-summary (swcad-title-fast-sheet-summary))
          (setq source-preserved (and source-frame (entget source-frame) (swtitle-stm-summary-valid-p final-summary)))
          (setq target-title-count (swtitle-stm-target-title-count))
          (setq target-frame-count (swtitle-stm-target-frame-count frame-name))
          (swtitle-stm-write-summary handle "After" final-summary)
          (swtitle-stm-write-line handle (strcat "Source frame preserved: " (if source-preserved "yes" "no")))
          (swtitle-stm-write-line handle (strcat "After target title count: " (itoa target-title-count)))
          (swtitle-stm-write-line handle (strcat "After target frame count: " (itoa target-frame-count)))

          (setq result-pass
            (cond
              ((equal mode "GAP")
                (and setup-valid (equal definition-before "missing") source-preserved (= target-title-count 0) (= target-frame-count 0))
              )
              ((equal mode "PREPARE")
                (and setup-valid (equal prepare-status "OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED") definition-ready source-preserved (= target-title-count 0) (= target-frame-count 0))
              )
              ((equal mode "SCRIPT_GUARD")
                (and setup-valid (equal prepare-status "OK_TITLE_MISSING_OUTLINE_DEFINITION_IMPORTED") definition-ready (equal convert-status "ABORT_INTERACTIVE_GMTITLE_SCRIPT_ACTIVE") source-preserved (= target-title-count 0) (= target-frame-count 0))
              )
              (T nil)
            )
          )
          (swtitle-stm-write-line handle (strcat "Fixture result: " (if result-pass "PASS" "FAIL")))
        )
        (swtitle-stm-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-stm-write-line handle "No drawing data was saved.")
      (swtitle-stm-write-line handle "Runtime check completed: yes")
      (setq *swcad-title-debug-log-handle* nil)
      (close handle)
    )
  )
  (princ)
)

(swtitle-stm-run)
