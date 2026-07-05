;;; Synthetic probe for the first-native transition gate.
;;; It proves that a marker-only A2 target pair is not accepted as a real native
;;; GMTITLE exemplar; the first native sheet still needs real GMTITLE internal
;;; link evidence.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LSP
;;;   SWCAD_COMPARE_LABEL
;;;   SWCAD_COMPARE_LOG
;;; This script modifies only the copied probe DWG and does not save it.

(vl-load-com)

(defun swtitle-postfirst-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-postfirst-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-postfirst-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-postfirst-ensure-rect-block (name width height /)
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

(defun swtitle-postfirst-insert-block (name point /)
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

(defun swtitle-postfirst-list-string (items / result item)
  (setq result "")
  (foreach item items
    (setq result
      (strcat
        result
        (if (> (strlen result) 0) ", " "")
        (if item (vl-princ-to-string item) "<nil>")
      )
    )
  )
  (if (> (strlen result) 0) result "<none>")
)

(defun swtitle-postfirst-create-a2-native-fixture (/ source source-ename source-handle source-bbox source-frame source-frame-ename source-frame-handle frame title)
  (setq source (car (swcad-title-source-title-candidates)))
  (setq source-ename (if source (car source) nil))
  (setq source-handle (if source-ename (swcad-title-ename-handle source-ename) "<none>"))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-handle (if source-frame-ename (swcad-title-ename-handle source-frame-ename) "<none>"))
  (if source-ename
    (vl-catch-all-apply 'entdel (list source-ename))
  )
  (if source-frame-ename
    (vl-catch-all-apply 'entdel (list source-frame-ename))
  )
  (swtitle-postfirst-ensure-rect-block "DR_A2_Outline" 594.0 420.0)
  (swtitle-postfirst-ensure-rect-block "DR_titlea_3rd" 180.0 42.0)
  (setq frame (swtitle-postfirst-insert-block "DR_A2_Outline" '(0.0 0.0 0.0)))
  (setq title (swtitle-postfirst-insert-block "DR_titlea_3rd" '(404.0 10.0 0.0)))
  (swcad-title-mark-native-exemplar-pair title frame "DR_A2_Outline" "native-apply")
  (list source-handle source-frame-handle frame title)
)

(defun swtitle-postfirst-main (/ root lsp-path log-path label handle load-result load-ok version-value bootstrap-record fixture summary missing selection status-result status-value source-count frame-only-count target-title-count target-frame-count target-pair-count native-like-count pass)
  (setq root (swtitle-postfirst-root))
  (setq lsp-path
    (swtitle-postfirst-env-path
      "SWCAD_COMPARE_LSP"
      (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-postfirst-env-path
      "SWCAD_COMPARE_LOG"
      (strcat root "/work/swtitle_post_first_native_transition_probe.txt")
    )
  )
  (setq label (getenv "SWCAD_COMPARE_LABEL"))
  (if (or (not label) (= (strlen label) 0))
    (setq label "<unnamed>")
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
      (swtitle-postfirst-write-line handle "SWTITLE post-first-native transition probe")
      (swtitle-postfirst-write-line handle (strcat "Label: " label))
      (swtitle-postfirst-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-postfirst-write-line handle "Load result: OK")
        (swtitle-postfirst-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-postfirst-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-postfirst-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-postfirst-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (if load-ok
        (progn
          (setq *swcad-title-log-file-suffix* "_post_first_native_transition_probe")
          (setq bootstrap-record (swcad-title-next-bootstrap-selection-record))
          (swtitle-postfirst-write-line
            handle
            (strcat
              "Bootstrap before fixture: "
              (if bootstrap-record
                (strcat (car bootstrap-record) " / " (cadr bootstrap-record) " / " (caddr bootstrap-record))
                "<none>"
              )
            )
          )
          (setq fixture (swtitle-postfirst-create-a2-native-fixture))
          (swtitle-postfirst-write-line
            handle
            (strcat
              "Deleted source title/frame handles: "
              (car fixture)
              "/"
              (cadr fixture)
            )
          )
          (swtitle-postfirst-write-line
            handle
            (strcat
              "Created A2 native target frame/title handles: "
              (swcad-title-ename-handle (nth 2 fixture))
              "/"
              (swcad-title-ename-handle (nth 3 fixture))
            )
          )
          (swtitle-postfirst-write-line
            handle
            (strcat
              "A2 marker-only title native-link kinds: "
              (swtitle-postfirst-list-string (swcad-title-native-link-target-kinds (nth 3 fixture)))
            )
          )
          (setq summary (swcad-title-fast-sheet-summary))
          (setq source-count (swcad-title-fast-summary-value summary "source-title-count"))
          (setq frame-only-count (swcad-title-fast-summary-value summary "frame-only-count"))
          (setq target-title-count (swcad-title-count-inserts-by-effective-name "DR_titlea_3rd"))
          (setq target-frame-count (+
            (swcad-title-count-inserts-by-effective-name "DR_A2_Outline")
            (swcad-title-count-inserts-by-effective-name "DR_A3_Outline")
            (swcad-title-count-inserts-by-effective-name "DR_A4_Outline")
          ))
          (setq target-pair-count (length (swcad-title-target-gmtitle-pair-records)))
          (setq native-like-count 0)
          (foreach record (swcad-title-target-gmtitle-pair-records)
            (if (swcad-title-target-pair-native-like-p record)
              (setq native-like-count (+ native-like-count 1))
            )
          )
          (setq missing (swcad-title-missing-required-native-frame-blocks summary))
          (setq selection (swcad-title-next-missing-native-selection-record summary missing))
          (swtitle-postfirst-write-line handle (strcat "Source title count after fixture: " (itoa source-count)))
          (swtitle-postfirst-write-line handle (strcat "Frame-only count after fixture: " (itoa frame-only-count)))
          (swtitle-postfirst-write-line handle (strcat "Target title count after fixture: " (itoa target-title-count)))
          (swtitle-postfirst-write-line handle (strcat "Target frame count after fixture: " (itoa target-frame-count)))
          (swtitle-postfirst-write-line handle (strcat "Target GMTITLE pair count after fixture: " (itoa target-pair-count)))
          (swtitle-postfirst-write-line handle (strcat "Native-like pair count after fixture: " (itoa native-like-count)))
          (swtitle-postfirst-write-line handle (strcat "Missing native frames after fixture: " (swtitle-postfirst-list-string missing)))
          (swtitle-postfirst-write-line
            handle
            (strcat
              "Next missing native selection after fixture: "
              (if selection
                (strcat (car selection) " / " (cadr selection) " / " (caddr selection) " / " (cadddr selection))
                "<none>"
              )
            )
          )
          (setq status-result (vl-catch-all-apply 'c:SWTITLESTATUS nil))
          (if (vl-catch-all-error-p status-result)
            (swtitle-postfirst-write-line handle (strcat "SWTITLESTATUS result: ERROR - " (vl-catch-all-error-message status-result)))
            (swtitle-postfirst-write-line handle "SWTITLESTATUS result: OK")
          )
          (setq status-value
            (if (boundp '*swcad-title-last-apply-status*)
              (if *swcad-title-last-apply-status* *swcad-title-last-apply-status* "<none>")
              "<missing>"
            )
          )
          (swtitle-postfirst-write-line handle (strcat "Status after SWTITLESTATUS: " status-value))
          (setq pass
            (and
              bootstrap-record
              (equal (cadr bootstrap-record) "DR_A2_Outline")
              (= source-count 12)
              (= frame-only-count 2)
              (= target-title-count 1)
              (= target-frame-count 1)
              (= target-pair-count 1)
              (= native-like-count 0)
              (member "DR_A3_Outline" missing)
              (member "DR_A4_Outline" missing)
              selection
              (equal (cadr selection) "DR_A3_Outline")
              (equal (caddr selection) "DR_titlea_3rd")
              (equal (cadddr selection) "title-sheet")
              (equal status-value "NEXT_CREATE_FIRST_NATIVE_GMTITLE")
            )
          )
          (swtitle-postfirst-write-line handle "Expected gate: marker-only A2 target is not accepted as the first native GMTITLE.")
          (swtitle-postfirst-write-line handle (strcat "Post-first-native marker gate probe passed: " (if pass "yes" "no")))
        )
      )
      (swtitle-postfirst-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-postfirst-main)
