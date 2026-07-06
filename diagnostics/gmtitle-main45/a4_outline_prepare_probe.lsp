;;; A4-sized source-title-missing DR_A4_Outline prepare sample probe.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT and SWCAD_A4_PREPARE_LOG.
;;; This probe runs on a copied DWG and does not save the drawing.

(defun swtitle-a4prep-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-a4prep-path (relative)
  (strcat (swtitle-a4prep-root) "/" relative)
)

(defun swtitle-a4prep-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-a4prep-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-a4prep-count-line (handle label counts)
  (swtitle-a4prep-write-line handle label)
  (if counts
    (foreach item counts
      (swtitle-a4prep-write-line handle (strcat "  " (car item) ": " (itoa (cdr item))))
    )
    (swtitle-a4prep-write-line handle "  <none>")
  )
)

(defun swtitle-a4prep-outside-a4-definition-p (bbox / tol)
  (setq tol 1.0)
  (and
    bbox
    (or
      (< (car bbox) (- tol))
      (< (cadr bbox) (- tol))
      (> (caddr bbox) (+ 210.0 tol))
      (> (cadddr bbox) (+ 297.0 tol))
    )
  )
)

(defun swtitle-a4prep-direct-record (ename / data etype layer handle child bbox outside area)
  (setq data (if ename (entget ename '("*")) nil))
  (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
  (setq layer (swcad-title-string (swcad-title-dxf-value data 8)))
  (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
  (setq child (swcad-title-string (swcad-title-dxf-value data 2)))
  (setq bbox (swcad-title-safe-bbox ename))
  (setq outside (swtitle-a4prep-outside-a4-definition-p bbox))
  (setq area (if bbox (swcad-title-bbox-area bbox) 0.0))
  (list handle etype layer child bbox outside area)
)

(defun swtitle-a4prep-direct-records (block-name / block result item ename)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if block
    (vlax-for item block
      (setq ename (swcad-title-vla-object->ename item))
      (if ename
        (setq result (append result (list (swtitle-a4prep-direct-record ename))))
      )
    )
  )
  result
)

(defun swtitle-a4prep-print-records (handle label records / index rec)
  (swtitle-a4prep-write-line handle label)
  (if records
    (progn
      (setq index 1)
      (foreach rec records
        (swtitle-a4prep-write-line
          handle
          (strcat
            "  #"
            (itoa index)
            " handle="
            (nth 0 rec)
            " type="
            (nth 1 rec)
            " layer="
            (nth 2 rec)
            (if (equal (nth 1 rec) "INSERT")
              (strcat " block=" (nth 3 rec))
              ""
            )
            " bbox="
            (swcad-title-bbox-string (nth 4 rec))
            " area="
            (swcad-title-number-string (nth 6 rec))
            (if (nth 5 rec) " OUTSIDE_A4" "")
          )
        )
        (setq index (+ index 1))
      )
    )
    (swtitle-a4prep-write-line handle "  <none>")
  )
)

(defun swtitle-a4prep-print-definition-details (handle label frame-name / exists records raw risk test test-raw test-effective geometry raw-warning)
  (swtitle-a4prep-write-line handle label)
  (setq exists (swcad-title-block-exists-p frame-name))
  (swtitle-a4prep-write-line handle (strcat "  Definition exists: " (if exists "yes" "no")))
  (if exists
    (progn
      (setq records (swtitle-a4prep-direct-records frame-name))
      (swtitle-a4prep-print-records handle "  Direct DR_A4_Outline definition records:" records)
      (setq raw (swcad-title-block-definition-raw-bbox frame-name))
      (setq risk (swcad-title-frame-definition-raw-bbox-risk-record frame-name))
      (swtitle-a4prep-write-line handle (strcat "  Definition raw bbox: " (swcad-title-bbox-string raw)))
      (swtitle-a4prep-write-line handle (strcat "  Definition raw risk: " (if risk (caddr risk) "<none>")))
      (setq test (swcad-title-insert-block-reference frame-name 0.0 0.0))
      (if test
        (progn
          (setq test-raw (swcad-title-safe-bbox test))
          (setq test-effective (swcad-title-frame-reference-effective-bbox test frame-name))
          (setq geometry (swcad-title-frame-bbox-size-warning-for-block frame-name test-effective))
          (setq raw-warning (swcad-title-frame-reference-raw-selection-warning test frame-name test-effective))
          (swtitle-a4prep-write-line handle (strcat "  Test insert raw bbox: " (swcad-title-bbox-string test-raw)))
          (swtitle-a4prep-write-line handle (strcat "  Test insert effective bbox: " (swcad-title-bbox-string test-effective)))
          (swtitle-a4prep-write-line handle (strcat "  Test insert geometry warning: " (if geometry geometry "<none>")))
          (swtitle-a4prep-write-line handle (strcat "  Test insert raw selection warning: " (if raw-warning raw-warning "<none>")))
          (swcad-title-delete-ename test)
        )
        (swtitle-a4prep-write-line handle "  Test insert: <failed>")
      )
    )
  )
)

(defun swtitle-a4prep-run (/ log-path handle load-result load-ok version before-status after-status before-counts after-counts before-target after-target prepare-result after-verify)
  (setq log-path (getenv "SWCAD_A4_PREPARE_LOG"))
  (if (or (not log-path) (= (strlen log-path) 0))
    (setq log-path (swtitle-a4prep-path "work/swtitle_a4_outline_prepare_probe_260705.txt"))
  )
  (setq log-path (vl-string-translate "\\" "/" log-path))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-a4prep-write-line handle "SWTITLE title-missing outline prepare probe (A4-sized sample)")
      (setq load-result
        (vl-catch-all-apply
          'load
          (list (swtitle-a4prep-path "src/tools/gmtitle/swcad_title_scale.lsp"))
        )
      )
      (setq load-ok (not (vl-catch-all-error-p load-result)))
      (if load-ok
        (progn
          (setq *swcad-title-debug-log-handle* handle)
          (setq *swcad-title-debug-log-path* log-path)
        )
      )
      (if load-ok
        (swtitle-a4prep-write-line handle "Load result: OK")
        (swtitle-a4prep-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (if load-ok
        (progn
          (swtitle-a4prep-write-line handle (strcat "Loaded version: " *swcad-title-scale-version*))
          (swtitle-a4prep-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swtitle-a4prep-write-line handle (strcat "CTAB: " (getvar "CTAB")))
          (setq before-status (swcad-title-title-missing-outline-definition-status))
          (setq before-counts (swcad-title-fast-sheet-summary))
          (setq before-target (swcad-title-target-frame-sheet-counts))
          (swtitle-a4prep-write-line handle (strcat "Before definition status: " before-status))
          (swtitle-a4prep-write-line handle (strcat "Before frame-only-count: " (itoa (swcad-title-fast-summary-value before-counts "frame-only-count"))))
          (swtitle-a4prep-count-line handle "Before target-sheet-counts:" before-target)
          (swtitle-a4prep-print-definition-details handle "Before DR_A4_Outline definition details:" "DR_A4_Outline")
          (setq prepare-result
            (vl-catch-all-apply
              'swcad-title-prepare-title-missing-outline-definition
              nil
            )
          )
          (if (vl-catch-all-error-p prepare-result)
            (swtitle-a4prep-write-line handle (strcat "Prepare result: ERROR - " (vl-catch-all-error-message prepare-result)))
            (swtitle-a4prep-write-line handle (strcat "Prepare result: OK status=" (swtitle-a4prep-status-value)))
          )
          (setq after-status (swcad-title-title-missing-outline-definition-status))
          (setq after-counts (swcad-title-fast-sheet-summary))
          (setq after-target (swcad-title-target-frame-sheet-counts))
          (swtitle-a4prep-write-line handle (strcat "After definition status: " after-status))
          (swtitle-a4prep-write-line handle (strcat "After frame-only-count: " (itoa (swcad-title-fast-summary-value after-counts "frame-only-count"))))
          (swtitle-a4prep-count-line handle "After target-sheet-counts:" after-target)
          (swtitle-a4prep-print-definition-details handle "After DR_A4_Outline definition details:" "DR_A4_Outline")
          (setq after-verify (vl-catch-all-apply 'swcad-title-native-frame-completion-check nil))
          (if (vl-catch-all-error-p after-verify)
            (swtitle-a4prep-write-line handle (strcat "Native check result: ERROR - " (vl-catch-all-error-message after-verify)))
            (swtitle-a4prep-write-line handle (strcat "Native check result: OK status=" (swtitle-a4prep-status-value)))
          )
        )
      )
      (swtitle-a4prep-write-line handle "Runtime check completed: yes")
      (setq *swcad-title-debug-log-handle* nil)
      (close handle)
    )
  )
  (princ)
)

(swtitle-a4prep-run)
