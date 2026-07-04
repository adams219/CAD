;;; A4 DR_A4_Outline normalization probe.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT, SWCAD_A4_NORM_LOG, and
;;; SWCAD_A4_NORM_STRATEGY. This probe runs on a copied DWG and does not save.

(vl-load-com)

(defun swtitle-a4norm-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-a4norm-path (relative)
  (strcat (swtitle-a4norm-root) "/" relative)
)

(defun swtitle-a4norm-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-a4norm-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-a4norm-outside-a4-p (bbox / tol)
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

(defun swtitle-a4norm-bbox-near-value-p (a b tol)
  (and
    (numberp a)
    (numberp b)
    (<= (abs (- a b)) tol)
  )
)

(defun swtitle-a4norm-raw-a4-match-warning (bbox / tol)
  (setq tol 2.0)
  (if
    (and
      bbox
      (swtitle-a4norm-bbox-near-value-p (car bbox) 0.0 tol)
      (swtitle-a4norm-bbox-near-value-p (cadr bbox) 0.0 tol)
      (swtitle-a4norm-bbox-near-value-p (caddr bbox) 210.0 tol)
      (swtitle-a4norm-bbox-near-value-p (cadddr bbox) 297.0 tol)
    )
    nil
    (strcat
      "raw bbox does not match the expected visible A4 frame; expected about (0,0)-(210,297), got "
      (swcad-title-bbox-string bbox)
    )
  )
)

(defun swtitle-a4norm-record (ename / data etype layer handle child bbox outside area)
  (setq data (if ename (entget ename '("*")) nil))
  (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
  (setq layer (swcad-title-string (swcad-title-dxf-value data 8)))
  (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
  (setq child (swcad-title-string (swcad-title-dxf-value data 2)))
  (setq bbox (swcad-title-safe-bbox ename))
  (setq outside (swtitle-a4norm-outside-a4-p bbox))
  (setq area (if bbox (swcad-title-bbox-area bbox) 0.0))
  (list handle etype layer child bbox outside area)
)

(defun swtitle-a4norm-direct-records (block-name / block result item ename)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if block
    (vlax-for item block
      (setq ename (swcad-title-vla-object->ename item))
      (if ename
        (setq result (append result (list (swtitle-a4norm-record ename))))
      )
    )
  )
  result
)

(defun swtitle-a4norm-insert-child-names (records / result rec child)
  (setq result nil)
  (foreach rec records
    (if (equal (nth 1 rec) "INSERT")
      (progn
        (setq child (nth 3 rec))
        (if
          (and
            child
            (> (strlen child) 0)
            (not (member child result))
          )
          (setq result (append result (list child)))
        )
      )
    )
  )
  result
)

(defun swtitle-a4norm-print-records (handle label records / index rec)
  (swtitle-a4norm-write-line handle label)
  (if records
    (progn
      (setq index 1)
      (foreach rec records
        (swtitle-a4norm-write-line
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
    (swtitle-a4norm-write-line handle "  <none>")
  )
)

(defun swtitle-a4norm-print-nested-records (handle label records / children child child-records)
  (swtitle-a4norm-write-line handle label)
  (setq children (swtitle-a4norm-insert-child-names records))
  (if children
    (foreach child children
      (if (swcad-title-block-exists-p child)
        (progn
          (setq child-records (swtitle-a4norm-direct-records child))
          (swtitle-a4norm-print-records
            handle
            (strcat "  Nested child block " child " records:")
            child-records
          )
        )
        (swtitle-a4norm-write-line
          handle
          (strcat "  Nested child block " child " records: <definition missing>")
        )
      )
    )
    (swtitle-a4norm-write-line handle "  <no direct INSERT children>")
  )
)

(defun swtitle-a4norm-skip-handles (strategy records / result rec etype outside area expected-area)
  (setq result nil)
  (setq expected-area (* 210.0 297.0))
  (foreach rec records
    (setq etype (nth 1 rec))
    (setq outside (nth 5 rec))
    (setq area (nth 6 rec))
    (cond
      ((equal strategy "huge-insert")
        (if
          (and
            (equal etype "INSERT")
            (> area (* expected-area 1.6))
          )
          (setq result (append result (list (nth 0 rec))))
        )
      )
      ((equal strategy "direct-outside")
        (if outside
          (setq result (append result (list (nth 0 rec))))
        )
      )
      ((equal strategy "nested-direct-outside")
        (if
          (and
            outside
            (not (equal etype "INSERT"))
          )
          (setq result (append result (list (nth 0 rec))))
        )
      )
    )
  )
  result
)

(defun swtitle-a4norm-rebuild-nested-outside (handle records / children child child-records skip-handles rebuild)
  (setq children (swtitle-a4norm-insert-child-names records))
  (if children
    (foreach child children
      (if (swcad-title-block-exists-p child)
        (progn
          (setq child-records (swtitle-a4norm-direct-records child))
          (setq skip-handles (swtitle-a4norm-skip-handles "direct-outside" child-records))
          (swtitle-a4norm-write-line
            handle
            (strcat
              "Nested child "
              child
              " direct-outside skip handles: "
              (swcad-title-list-string skip-handles)
            )
          )
          (if skip-handles
            (progn
              (setq rebuild (swcad-title-rebuild-block-definition-skipping-handles child skip-handles))
              (swtitle-a4norm-write-line
                handle
                (strcat
                  "Nested child "
                  child
                  " rebuild result: ok="
                  (if (car rebuild) "yes" "no")
                  ", backup="
                  (cadr rebuild)
                  ", copied="
                  (itoa (nth 2 rebuild))
                  ", skipped="
                  (itoa (nth 3 rebuild))
                  ", retargeted="
                  (itoa (nth 4 rebuild))
                  ", failed="
                  (itoa (nth 5 rebuild))
                )
              )
            )
            (swtitle-a4norm-write-line
              handle
              (strcat "Nested child " child " rebuild result: skipped, no outside handles")
            )
          )
        )
        (swtitle-a4norm-write-line
          handle
          (strcat "Nested child " child " rebuild result: skipped, definition missing")
        )
      )
    )
    (swtitle-a4norm-write-line handle "Nested rebuild result: skipped, no direct INSERT children")
  )
)

(defun swtitle-a4norm-print-measure (handle label frame-name / def-raw def-risk test raw effective geometry raw-warning strict-warning)
  (setq def-raw (swcad-title-block-definition-raw-bbox frame-name))
  (setq def-risk (swcad-title-frame-definition-raw-bbox-risk-record frame-name))
  (swtitle-a4norm-write-line handle (strcat label " definition raw bbox: " (swcad-title-bbox-string def-raw)))
  (swtitle-a4norm-write-line handle (strcat label " definition raw risk: " (if def-risk (caddr def-risk) "<none>")))
  (setq test (swcad-title-insert-block-reference frame-name 0.0 0.0))
  (if test
    (progn
      (setq raw (swcad-title-safe-bbox test))
      (setq effective (swcad-title-frame-reference-effective-bbox test frame-name))
      (setq geometry (swcad-title-frame-bbox-size-warning-for-block frame-name effective))
      (setq raw-warning (swcad-title-frame-reference-raw-selection-warning test frame-name effective))
      (setq strict-warning (swtitle-a4norm-raw-a4-match-warning raw))
      (swtitle-a4norm-write-line handle (strcat label " test raw bbox: " (swcad-title-bbox-string raw)))
      (swtitle-a4norm-write-line handle (strcat label " test effective bbox: " (swcad-title-bbox-string effective)))
      (swtitle-a4norm-write-line handle (strcat label " geometry warning: " (if geometry geometry "<none>")))
      (swtitle-a4norm-write-line handle (strcat label " raw selection warning: " (if raw-warning raw-warning "<none>")))
      (swtitle-a4norm-write-line handle (strcat label " strict A4 raw match warning: " (if strict-warning strict-warning "<none>")))
      (swcad-title-delete-ename test)
      (list def-risk geometry raw-warning strict-warning)
    )
    (progn
      (swtitle-a4norm-write-line handle (strcat label " test insert: <failed>"))
      (list def-risk "insert-failed" "insert-failed" "insert-failed")
    )
  )
)

(defun swtitle-a4norm-run (/ log-path handle load-result load-ok version strategy frame imported before-records skip-handles rebuild after-records after-measure safe-p)
  (setq log-path (getenv "SWCAD_A4_NORM_LOG"))
  (if (or (not log-path) (= (strlen log-path) 0))
    (setq log-path (swtitle-a4norm-path "work/swtitle_a4_outline_normalization_probe_260705.txt"))
  )
  (setq log-path (vl-string-translate "\\" "/" log-path))
  (setq strategy (getenv "SWCAD_A4_NORM_STRATEGY"))
  (if (or (not strategy) (= (strlen strategy) 0))
    (setq strategy "none")
  )
  (setq strategy (strcase strategy T))
  (setq load-result
    (vl-catch-all-apply
      'load
      (list (swtitle-a4norm-path "src/tools/gmtitle/swcad_title_scale.lsp"))
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (setq *swcad-title-debug-log-handle* handle)
      (setq *swcad-title-debug-log-path* log-path)
      (swtitle-a4norm-write-line handle "SWTITLE A4 outline normalization probe")
      (swtitle-a4norm-write-line handle (strcat "Strategy: " strategy))
      (if load-ok
        (swtitle-a4norm-write-line handle "Load result: OK")
        (swtitle-a4norm-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (if load-ok
        (progn
          (setq version *swcad-title-scale-version*)
          (swtitle-a4norm-write-line handle (strcat "Loaded version: " version))
          (swtitle-a4norm-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swtitle-a4norm-write-line handle (strcat "CTAB: " (getvar "CTAB")))
          (setq frame "DR_A4_Outline")
          (setq imported
            (if (swcad-title-block-exists-p frame)
              "already-exists"
              (if (swcad-title-import-clean-frame-definition frame) "imported" "failed")
            )
          )
          (swtitle-a4norm-write-line handle (strcat "Definition import status: " imported))
          (if (swcad-title-block-exists-p frame)
            (progn
              (setq before-records (swtitle-a4norm-direct-records frame))
              (swtitle-a4norm-print-records handle "Before direct DR_A4_Outline records:" before-records)
              (swtitle-a4norm-print-nested-records handle "Before nested DR_A4_Outline child records:" before-records)
              (swtitle-a4norm-print-measure handle "Before" frame)
              (setq skip-handles (swtitle-a4norm-skip-handles strategy before-records))
              (swtitle-a4norm-write-line handle (strcat "Skip handles: " (swcad-title-list-string skip-handles)))
              (if (and skip-handles (not (equal strategy "none")))
                (progn
                  (setq rebuild (swcad-title-rebuild-block-definition-skipping-handles frame skip-handles))
                  (swtitle-a4norm-write-line
                    handle
                    (strcat
                      "Rebuild result: ok="
                      (if (car rebuild) "yes" "no")
                      ", backup="
                      (cadr rebuild)
                      ", copied="
                      (itoa (nth 2 rebuild))
                      ", skipped="
                      (itoa (nth 3 rebuild))
                      ", retargeted="
                      (itoa (nth 4 rebuild))
                      ", failed="
                      (itoa (nth 5 rebuild))
                    )
                  )
                )
                (swtitle-a4norm-write-line handle "Rebuild result: skipped by strategy")
              )
              (if (or (equal strategy "nested-outside") (equal strategy "nested-direct-outside"))
                (swtitle-a4norm-rebuild-nested-outside handle before-records)
              )
              (setq after-records (swtitle-a4norm-direct-records frame))
              (swtitle-a4norm-print-records handle "After direct DR_A4_Outline records:" after-records)
              (swtitle-a4norm-print-nested-records handle "After nested DR_A4_Outline child records:" after-records)
              (setq after-measure (swtitle-a4norm-print-measure handle "After" frame))
              (setq safe-p
                (and
                  (not (car after-measure))
                  (not (cadr after-measure))
                  (not (caddr after-measure))
                  (not (cadddr after-measure))
                )
              )
              (swtitle-a4norm-write-line handle (strcat "Normalization safe for A4 frame-only conversion: " (if safe-p "yes" "no")))
            )
            (swtitle-a4norm-write-line handle "DR_A4_Outline definition is missing after import attempt.")
          )
        )
      )
      (swtitle-a4norm-write-line handle "Runtime check completed: yes")
      (setq *swcad-title-debug-log-handle* nil)
      (close handle)
    )
  )
  (princ)
)

(swtitle-a4norm-run)
