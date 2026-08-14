;;; Synthetic probe for the SWTITLECONVERT native-adoption gate.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LSP
;;;   SWCAD_COMPARE_LABEL
;;;   SWCAD_COMPARE_LOG
;;; This script modifies only the copied probe DWG and does not save it.

(vl-load-com)

(defun swtitle-adopt-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-adopt-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-adopt-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-adopt-symbol-present-p (symbol-name / found symbol value)
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

(defun swtitle-adopt-delete-inserts (block-name / ss index ename)
  (setq ss (ssget "_X" (list '(0 . "INSERT") (cons 2 block-name))))
  (setq index 0)
  (if ss
    (while (< index (sslength ss))
      (setq ename (ssname ss index))
      (vl-catch-all-apply 'entdel (list ename))
      (setq index (+ index 1))
    )
  )
)

(defun swtitle-adopt-delete-all-inserts (/ ss index ename)
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

(defun swtitle-adopt-ensure-rect-block (name width height /)
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

(defun swtitle-adopt-insert-block (name point /)
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

(defun swtitle-adopt-create-fixture (/ source-frame-name source-title-name target-frame-name target-title-name source-frame source-title target-frame target-title)
  (setq source-frame-name "SWTEST_A3_FRAME")
  (setq source-title-name "SWTEST_FTAP_TITLE")
  (setq target-frame-name "DR_A3_Outline")
  (setq target-title-name "DR_titlea_3rd")
  (swtitle-adopt-delete-all-inserts)
  (swtitle-adopt-ensure-rect-block source-frame-name 420.0 297.0)
  (swtitle-adopt-ensure-rect-block source-title-name 180.0 42.0)
  (swtitle-adopt-ensure-rect-block target-frame-name 420.0 297.0)
  (swtitle-adopt-ensure-rect-block target-title-name 180.0 42.0)
  (swtitle-adopt-delete-inserts source-frame-name)
  (swtitle-adopt-delete-inserts source-title-name)
  (swtitle-adopt-delete-inserts target-frame-name)
  (swtitle-adopt-delete-inserts target-title-name)
  (setq source-frame (swtitle-adopt-insert-block source-frame-name '(0.0 0.0 0.0)))
  (setq source-title (swtitle-adopt-insert-block source-title-name '(230.0 10.0 0.0)))
  (setq target-frame (swcad-title-insert-block-reference target-frame-name 0.0 0.0))
  (setq target-title (swcad-title-insert-block-reference target-title-name 230.0 10.0))
  (if (swtitle-adopt-symbol-present-p "SWCAD-TITLE-MARK-NATIVE-EXEMPLAR-PAIR")
    (swcad-title-mark-native-exemplar-pair target-title target-frame target-frame-name "native-apply")
  )
  (list source-frame source-title target-frame target-title)
)

(defun swtitle-adopt-main (/ root lsp-path log-path label handle load-result load-ok version-value fixture source-count-before source-count-after target-count-before target-count-after target-object target-attr-pairs target-missing-tags adopt-func-present apply-result status danger pass)
  (setq root (swtitle-adopt-root))
  (setq lsp-path
    (swtitle-adopt-env-path
      "SWCAD_COMPARE_LSP"
      (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-adopt-env-path
      "SWCAD_COMPARE_LOG"
      (strcat root "/work/swtitle_adoption_gate_compare_probe.txt")
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
      (swtitle-adopt-write-line handle "SWTITLE native adoption gate comparison probe")
      (swtitle-adopt-write-line handle (strcat "Label: " label))
      (swtitle-adopt-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-adopt-write-line handle "Load result: OK")
        (swtitle-adopt-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-adopt-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-adopt-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-adopt-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (if load-ok
        (progn
          (setq fixture (swtitle-adopt-create-fixture))
          (swtitle-adopt-write-line
            handle
            (strcat
              "Fixture handles source-frame/source-title + target-frame/target-title: "
              (swcad-title-ename-handle (car fixture))
              "/"
              (swcad-title-ename-handle (cadr fixture))
              " + "
              (swcad-title-ename-handle (nth 2 fixture))
              "/"
              (swcad-title-ename-handle (nth 3 fixture))
            )
          )
          (setq adopt-func-present (swtitle-adopt-symbol-present-p "SWCAD-TITLE-ADOPTABLE-TARGET-PAIR-FOR-FRAME-BBOX"))
          (swtitle-adopt-write-line handle (strcat "Adoption function present: " (if adopt-func-present "yes" "no")))
          (setq target-object (swcad-title-safe-vla-object (nth 3 fixture)))
          (setq target-attr-pairs (if target-object (swcad-title-title-attribute-pairs target-object) nil))
          (setq target-missing-tags (swcad-title-missing-template-tags target-attr-pairs))
          (swtitle-adopt-write-line handle (strcat "Target title attribute count before transfer: " (itoa (length target-attr-pairs))))
          (swtitle-adopt-write-line handle (strcat "Target title missing tag count before transfer: " (itoa (length target-missing-tags))))
          (setq source-count-before (swcad-title-source-title-count))
          (setq target-count-before (swcad-title-count-inserts-by-effective-name "DR_titlea_3rd"))
          (setq *swtitle-adoption-probe-danger-action* "<none>")
          (defun swcad-title-run-native-gmtitle-prefer-commandline (frame-block placement-point /)
            (setq *swtitle-adoption-probe-danger-action* "RUN_NATIVE_GMTITLE")
            (list nil nil nil)
          )
          (setq *swcad-title-batch-mode* T)
          (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-apply nil))
          (setq *swcad-title-batch-mode* nil)
          (setq status
            (if (boundp '*swcad-title-last-apply-status*)
              (if *swcad-title-last-apply-status* *swcad-title-last-apply-status* "<none>")
              "<missing>"
            )
          )
          (setq source-count-after (swcad-title-source-title-count))
          (setq target-count-after (swcad-title-count-inserts-by-effective-name "DR_titlea_3rd"))
          (setq danger *swtitle-adoption-probe-danger-action*)
          (if (vl-catch-all-error-p apply-result)
            (swtitle-adopt-write-line handle (strcat "Transfer apply result: ERROR - " (vl-catch-all-error-message apply-result)))
            (swtitle-adopt-write-line handle "Transfer apply result: OK")
          )
          (swtitle-adopt-write-line handle (strcat "Status after transfer: " status))
          (swtitle-adopt-write-line handle (strcat "Danger action: " danger))
          (swtitle-adopt-write-line handle (strcat "Source title count before/after: " (itoa source-count-before) "/" (itoa source-count-after)))
          (swtitle-adopt-write-line handle (strcat "Target title count before/after: " (itoa target-count-before) "/" (itoa target-count-after)))
          (setq pass
            (and
              adopt-func-present
              (> (length target-attr-pairs) 0)
              (= (length target-missing-tags) 0)
              (equal status "ADOPTED_EXISTING_NATIVE_GMTITLE_TRANSFER")
              (equal danger "<none>")
              (= source-count-after 0)
              (= target-count-after target-count-before)
            )
          )
          (swtitle-adopt-write-line handle (strcat "Adoption gate probe passed: " (if pass "yes" "no")))
        )
      )
      (swtitle-adopt-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-adopt-main)
