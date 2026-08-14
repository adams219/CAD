;;; A4 native exemplar read-only probe.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT and SWCAD_A4_NATIVE_LOG.
;;; This probe runs on a copied DWG and does not save the drawing.

(vl-load-com)

(defun swtitle-a4native-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-a4native-path (relative)
  (strcat (swtitle-a4native-root) "/" relative)
)

(defun swtitle-a4native-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-a4native-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-a4native-count-line (handle label counts)
  (swtitle-a4native-write-line handle label)
  (if counts
    (foreach item counts
      (swtitle-a4native-write-line handle (strcat "  " (car item) ": " (itoa (cdr item))))
    )
    (swtitle-a4native-write-line handle "  <none>")
  )
)

(defun swtitle-a4native-bbox-near-value-p (a b tol)
  (and
    (numberp a)
    (numberp b)
    (<= (abs (- a b)) tol)
  )
)

(defun swtitle-a4native-raw-a4-definition-warning (bbox / tol)
  (setq tol 2.0)
  (if
    (and
      bbox
      (swtitle-a4native-bbox-near-value-p (car bbox) 0.0 tol)
      (swtitle-a4native-bbox-near-value-p (cadr bbox) 0.0 tol)
      (swtitle-a4native-bbox-near-value-p (caddr bbox) 210.0 tol)
      (swtitle-a4native-bbox-near-value-p (cadddr bbox) 297.0 tol)
    )
    nil
    (strcat
      "definition raw bbox does not match A4 (0,0)-(210,297): "
      (swcad-title-bbox-string bbox)
    )
  )
)

(defun swtitle-a4native-outside-a4-definition-p (bbox / tol)
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

(defun swtitle-a4native-direct-record (ename / data etype layer handle child bbox outside area)
  (setq data (if ename (entget ename '("*")) nil))
  (setq etype (swcad-title-string (swcad-title-dxf-value data 0)))
  (setq layer (swcad-title-string (swcad-title-dxf-value data 8)))
  (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
  (setq child (swcad-title-string (swcad-title-dxf-value data 2)))
  (setq bbox (swcad-title-safe-bbox ename))
  (setq outside (swtitle-a4native-outside-a4-definition-p bbox))
  (setq area (if bbox (swcad-title-bbox-area bbox) 0.0))
  (list handle etype layer child bbox outside area)
)

(defun swtitle-a4native-direct-records (block-name / block result item ename)
  (setq block (swcad-title-block-definition-object block-name))
  (setq result nil)
  (if block
    (vlax-for item block
      (setq ename (swcad-title-vla-object->ename item))
      (if ename
        (setq result (append result (list (swtitle-a4native-direct-record ename))))
      )
    )
  )
  result
)

(defun swtitle-a4native-print-records (handle label records / index rec)
  (swtitle-a4native-write-line handle label)
  (if records
    (progn
      (setq index 1)
      (foreach rec records
        (swtitle-a4native-write-line
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
    (swtitle-a4native-write-line handle "  <none>")
  )
)

(defun swtitle-a4native-print-definition (handle frame-name / exists records raw risk strict test test-raw test-effective geometry raw-warning minor-native-outside)
  (setq exists (swcad-title-block-exists-p frame-name))
  (swtitle-a4native-write-line handle (strcat "Definition exists: " (if exists "yes" "no")))
  (if exists
    (progn
      (setq records (swtitle-a4native-direct-records frame-name))
      (swtitle-a4native-print-records handle "Direct DR_A4_Outline definition records:" records)
      (setq raw (swcad-title-block-definition-raw-bbox frame-name))
      (setq risk (swcad-title-frame-definition-raw-bbox-risk-record frame-name))
      (setq strict (swtitle-a4native-raw-a4-definition-warning raw))
      (swtitle-a4native-write-line handle (strcat "Definition raw bbox: " (swcad-title-bbox-string raw)))
      (swtitle-a4native-write-line handle (strcat "Definition raw risk: " (if risk (caddr risk) "<none>")))
      (swtitle-a4native-write-line handle (strcat "Definition strict A4 warning: " (if strict strict "<none>")))
      (setq test (swcad-title-insert-block-reference frame-name 0.0 0.0))
      (if test
        (progn
          (setq test-raw (swcad-title-safe-bbox test))
          (setq test-effective (swcad-title-frame-reference-effective-bbox test frame-name))
          (setq geometry (swcad-title-frame-bbox-size-warning-for-block frame-name test-effective))
          (setq raw-warning (swcad-title-frame-reference-raw-selection-warning test frame-name test-effective))
          (swtitle-a4native-write-line handle (strcat "Definition test insert raw bbox: " (swcad-title-bbox-string test-raw)))
          (swtitle-a4native-write-line handle (strcat "Definition test insert effective bbox: " (swcad-title-bbox-string test-effective)))
          (swtitle-a4native-write-line handle (strcat "Definition test insert geometry warning: " (if geometry geometry "<none>")))
          (swtitle-a4native-write-line handle (strcat "Definition test insert raw selection warning: " (if raw-warning raw-warning "<none>")))
          (swcad-title-delete-ename test)
        )
        (swtitle-a4native-write-line handle "Definition test insert: <failed>")
      )
      (setq minor-native-outside
        (and
          (not risk)
          strict
          (not geometry)
          (not raw-warning)
        )
      )
      (swtitle-a4native-write-line
        handle
        (strcat
          "Definition minor native outside markers: "
          (if minor-native-outside "yes" "no")
        )
      )
      (list
        (and (not risk) (not strict) (not geometry) (not raw-warning))
        minor-native-outside
        risk
        strict
        geometry
        raw-warning
      )
    )
    nil
  )
)

(defun swtitle-a4native-print-frame-inserts (handle frame-name / frames index frame data handle-text raw effective geometry raw-warning apps kinds role warning-count)
  (setq frames (swcad-title-inserts-by-effective-name frame-name))
  (setq warning-count 0)
  (swtitle-a4native-write-line handle (strcat "Visible DR_A4_Outline frame inserts: " (itoa (length frames))))
  (setq index 1)
  (foreach frame frames
    (setq data (entget frame '("*")))
    (setq handle-text (swcad-title-string (swcad-title-dxf-value data 5)))
    (setq raw (swcad-title-safe-bbox frame))
    (setq effective (swcad-title-frame-reference-effective-bbox frame frame-name))
    (setq geometry (swcad-title-frame-bbox-size-warning-for-block frame-name effective))
    (setq raw-warning (swcad-title-frame-reference-raw-selection-warning frame frame-name effective))
    (setq apps (swcad-title-xdata-app-names frame))
    (setq kinds (swcad-title-native-link-target-kinds frame))
    (setq role (swcad-title-exemplar-role frame))
    (if (or geometry raw-warning)
      (setq warning-count (+ warning-count 1))
    )
    (swtitle-a4native-write-line
      handle
      (strcat
        "  Frame #"
        (itoa index)
        ": handle="
        handle-text
        ", role="
        (swcad-title-role-display role)
        ", raw-bbox="
        (swcad-title-bbox-string raw)
        ", effective-bbox="
        (swcad-title-bbox-string effective)
      )
    )
    (swtitle-a4native-write-line handle (strcat "    geometry warning: " (if geometry geometry "<none>")))
    (swtitle-a4native-write-line handle (strcat "    raw selection warning: " (if raw-warning raw-warning "<none>")))
    (swtitle-a4native-write-line handle (strcat "    xdata apps: " (swcad-title-list-string apps)))
    (swtitle-a4native-write-line handle (strcat "    native link target kinds: " (swcad-title-list-string kinds)))
    (setq index (+ index 1))
  )
  (list (length frames) warning-count)
)

(defun swtitle-a4native-native-pair-evidence (frame-name / frame-records titles result title title-bbox frame-record frame-ename frame-block frame-bbox title-role frame-role kinds pair-trusted target)
  (setq target (strcase (swcad-title-string frame-name)))
  (setq frame-records (swcad-title-frame-records))
  (setq titles
    (vl-sort
      (swcad-title-inserts-by-effective-name (swcad-title-target-title-block-name))
      '(lambda (a b)
        (< (swcad-title-bbox-min-x a) (swcad-title-bbox-min-x b))
      )
    )
  )
  (setq result nil)
  (foreach title titles
    (if
      (and
        (not result)
        (swcad-title-usable-native-example-title-p title)
      )
      (progn
        (setq title-bbox (swcad-title-safe-bbox title))
        (setq frame-record (if title-bbox (swcad-title-nearest-frame-record-for-block title-bbox frame-records frame-name) nil))
        (setq frame-ename (if frame-record (car frame-record) nil))
        (setq frame-block (if frame-record (cadr frame-record) ""))
        (setq frame-bbox (if frame-record (cadddr frame-record) nil))
        (setq title-role (swcad-title-exemplar-role title))
        (setq frame-role (if frame-ename (swcad-title-exemplar-role frame-ename) ""))
        (setq kinds (swcad-title-native-link-target-kinds title))
        (setq pair-trusted
          (if frame-ename
            (swcad-title-trusted-native-exemplar-pair-p title frame-ename frame-name)
            nil
          )
        )
        (if
          (and
            frame-ename
            frame-bbox
            (equal (strcase (swcad-title-string frame-block)) target)
          )
          (setq result
            (list title frame-ename frame-block title-bbox frame-bbox kinds title-role frame-role pair-trusted)
          )
        )
      )
    )
  )
  result
)

(defun swtitle-a4native-print-native-pair-evidence (handle frame-name / evidence title frame frame-block title-bbox frame-bbox kinds title-role frame-role pair-trusted title-handle frame-handle geometry raw-warning status)
  (setq evidence (swtitle-a4native-native-pair-evidence frame-name))
  (if evidence
    (progn
      (setq title (nth 0 evidence))
      (setq frame (nth 1 evidence))
      (setq frame-block (nth 2 evidence))
      (setq title-bbox (nth 3 evidence))
      (setq frame-bbox (nth 4 evidence))
      (setq kinds (nth 5 evidence))
      (setq title-role (nth 6 evidence))
      (setq frame-role (nth 7 evidence))
      (setq pair-trusted (nth 8 evidence))
      (setq title-handle (swcad-title-string (swcad-title-dxf-value (entget title '("*")) 5)))
      (setq frame-handle (swcad-title-string (swcad-title-dxf-value (entget frame '("*")) 5)))
      (setq geometry (swcad-title-frame-bbox-size-warning-for-block frame-block frame-bbox))
      (setq raw-warning (swcad-title-frame-reference-raw-selection-warning frame frame-block frame-bbox))
      (swtitle-a4native-write-line handle "Native GMTITLE A4 pair evidence: yes")
      (swtitle-a4native-write-line
        handle
        (strcat
          "  title="
          title-handle
          ", frame="
          frame-handle
          ", frame-block="
          frame-block
          ", title-role="
          (if (> (strlen title-role) 0) title-role "<none>")
          ", frame-role="
          (if (> (strlen frame-role) 0) frame-role "<none>")
          ", trusted-marker="
          (if pair-trusted "yes" "no")
        )
      )
      (swtitle-a4native-write-line handle (strcat "  title native link target kinds: " (swcad-title-list-string kinds)))
      (swtitle-a4native-write-line handle (strcat "  title bbox: " (swcad-title-bbox-string title-bbox)))
      (swtitle-a4native-write-line handle (strcat "  frame bbox: " (swcad-title-bbox-string frame-bbox)))
      (swtitle-a4native-write-line handle (strcat "  frame geometry warning: " (if geometry geometry "<none>")))
      (swtitle-a4native-write-line handle (strcat "  frame raw selection warning: " (if raw-warning raw-warning "<none>")))
      (setq status (if (or geometry raw-warning) "warning" "ready"))
    )
    (progn
      (swtitle-a4native-write-line handle "Native GMTITLE A4 pair evidence: no")
      (swtitle-a4native-write-line handle "  A clean DR_A4_Outline frame alone is not enough; a nearby DR_titlea_3rd with native GMTITLE link evidence is required for this scratch comparison.")
      (setq status "missing")
    )
  )
  status
)

(defun swtitle-a4native-run (/ log-path handle load-result load-ok frame-name summary target-counts definition-status definition-result definition-safe definition-minor-native-outside frame-result frame-count frame-warning-count native-pair-status result)
  (setq log-path (getenv "SWCAD_A4_NATIVE_LOG"))
  (if (or (not log-path) (= (strlen log-path) 0))
    (setq log-path (swtitle-a4native-path "work/swtitle_a4_native_exemplar_probe_260705.txt"))
  )
  (setq log-path (vl-string-translate "\\" "/" log-path))
  (setq load-result
    (vl-catch-all-apply
      'load
      (list (swtitle-a4native-path "src/tools/gmtitle/swcad_title_scale.lsp"))
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (setq *swcad-title-debug-log-handle* handle)
      (setq *swcad-title-debug-log-path* log-path)
      (swtitle-a4native-write-line handle "SWTITLE source-title-missing native exemplar probe (A4-sized sample)")
      (if load-ok
        (swtitle-a4native-write-line handle "Load result: OK")
        (swtitle-a4native-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (if load-ok
        (progn
          (setq frame-name "DR_A4_Outline")
          (swtitle-a4native-write-line handle (strcat "Loaded version: " *swcad-title-scale-version*))
          (swtitle-a4native-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
          (swtitle-a4native-write-line handle (strcat "CTAB: " (getvar "CTAB")))
          (swtitle-a4native-write-line handle (strcat "DBMOD before checks: " (itoa (getvar "DBMOD"))))
          (setq summary (swcad-title-fast-sheet-summary))
          (setq target-counts (swcad-title-target-frame-sheet-counts))
          (swtitle-a4native-write-line handle (strcat "Source frame-only count: " (itoa (swcad-title-fast-summary-value summary "frame-only-count"))))
          (swtitle-a4native-count-line handle "Expected sheet counts:" (swcad-title-expected-sheet-counts-for-marker))
          (swtitle-a4native-count-line handle "Current target sheet counts:" target-counts)
          (setq definition-status (swcad-title-title-missing-outline-definition-status))
          (swtitle-a4native-write-line handle (strcat "A4 outline definition status: " definition-status))
          (setq definition-result (swtitle-a4native-print-definition handle frame-name))
          (setq definition-safe (if definition-result (car definition-result) nil))
          (setq definition-minor-native-outside (if definition-result (cadr definition-result) nil))
          (setq frame-result (swtitle-a4native-print-frame-inserts handle frame-name))
          (setq frame-count (car frame-result))
          (setq frame-warning-count (cadr frame-result))
          (setq native-pair-status (swtitle-a4native-print-native-pair-evidence handle frame-name))
          (setq result
            (cond
              ((not (swcad-title-block-exists-p frame-name)) "A4_NATIVE_EXEMPLAR_MISSING_DEFINITION")
              ((= frame-count 0) "A4_NATIVE_EXEMPLAR_MISSING_FRAME_INSERT")
              ((> frame-warning-count 0) "A4_NATIVE_EXEMPLAR_FRAME_WARNING")
              ((equal native-pair-status "missing") "A4_NATIVE_EXEMPLAR_MISSING_NATIVE_PAIR")
              ((equal native-pair-status "warning") "A4_NATIVE_EXEMPLAR_NATIVE_PAIR_WARNING")
              ((and (not definition-safe) definition-minor-native-outside) "A4_NATIVE_EXEMPLAR_READY_WITH_NATIVE_OUTSIDE_MARKERS")
              ((not definition-safe) "A4_NATIVE_EXEMPLAR_UNSAFE_DEFINITION")
              (T "A4_NATIVE_EXEMPLAR_READY_FOR_COMPARISON")
            )
          )
          (swtitle-a4native-write-line handle (strcat "Result: " result))
          (swtitle-a4native-write-line handle "No drawing data was saved.")
          (swtitle-a4native-write-line handle (strcat "DBMOD after checks: " (itoa (getvar "DBMOD"))))
        )
      )
      (swtitle-a4native-write-line handle "Runtime check completed: yes")
      (setq *swcad-title-debug-log-handle* nil)
      (close handle)
    )
  )
  (princ)
)

(swtitle-a4native-run)
