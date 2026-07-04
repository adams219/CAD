;;; Synthetic read-only-ish probe for duplicate GMTITLE target pair detection.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LSP
;;;   SWCAD_COMPARE_LABEL
;;;   SWCAD_COMPARE_LOG
;;; This script modifies only the copied probe DWG and does not save it.

(vl-load-com)

(defun swtitle-duppair-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-duppair-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-duppair-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-duppair-symbol-present-p (symbol-name / found symbol value)
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

(defun swtitle-duppair-delete-existing-inserts (block-name / ss index ename)
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

(defun swtitle-duppair-ensure-frame-block (/ name)
  (setq name "DR_A3_Outline")
  (if (not (tblsearch "BLOCK" name))
    (progn
      (entmake (list '(0 . "BLOCK") (cons 2 name) '(70 . 0) '(10 0.0 0.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 0.0 0.0 0.0) (11 420.0 0.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 420.0 0.0 0.0) (11 420.0 297.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 420.0 297.0 0.0) (11 0.0 297.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 0.0 297.0 0.0) (11 0.0 0.0 0.0)))
      (entmake '((0 . "ENDBLK")))
    )
  )
  name
)

(defun swtitle-duppair-ensure-title-block (/ name)
  (setq name "DR_titlea_3rd")
  (if (not (tblsearch "BLOCK" name))
    (progn
      (entmake (list '(0 . "BLOCK") (cons 2 name) '(70 . 0) '(10 0.0 0.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 0.0 0.0 0.0) (11 180.0 0.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 180.0 0.0 0.0) (11 180.0 42.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 180.0 42.0 0.0) (11 0.0 42.0 0.0)))
      (entmake '((0 . "LINE") (8 . "0") (10 0.0 42.0 0.0) (11 0.0 0.0 0.0)))
      (entmake '((0 . "ENDBLK")))
    )
  )
  name
)

(defun swtitle-duppair-insert-block (name point / ename)
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

(defun swtitle-duppair-create-fixture (/ frame-name title-name frame1 title1 frame2 title2)
  (setq frame-name (swtitle-duppair-ensure-frame-block))
  (setq title-name (swtitle-duppair-ensure-title-block))
  (swtitle-duppair-delete-existing-inserts frame-name)
  (swtitle-duppair-delete-existing-inserts title-name)
  (setq frame1 (swtitle-duppair-insert-block frame-name '(0.0 0.0 0.0)))
  (setq title1 (swtitle-duppair-insert-block title-name '(230.0 10.0 0.0)))
  (setq frame2 (swtitle-duppair-insert-block frame-name '(0.0 0.0 0.0)))
  (setq title2 (swtitle-duppair-insert-block title-name '(230.0 10.0 0.0)))
  (if (swtitle-duppair-symbol-present-p "SWCAD-TITLE-MARK-NATIVE-EXEMPLAR-PAIR")
    (progn
      (swcad-title-mark-native-exemplar-pair title1 frame1 frame-name "native-apply")
      (swcad-title-mark-native-exemplar-pair title2 frame2 frame-name "native-upgrade")
    )
  )
  (list frame1 title1 frame2 title2)
)

(defun swtitle-duppair-main (/ root lsp-path log-path label handle load-result load-ok version-value fixture records first keep discard pass)
  (setq root (swtitle-duppair-root))
  (setq lsp-path
    (swtitle-duppair-env-path
      "SWCAD_COMPARE_LSP"
      (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-duppair-env-path
      "SWCAD_COMPARE_LOG"
      (strcat root "/work/swtitle_duplicate_target_pair_compare_probe.txt")
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
      (swtitle-duppair-write-line handle "SWTITLE duplicate target pair comparison probe")
      (swtitle-duppair-write-line handle (strcat "Label: " label))
      (swtitle-duppair-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-duppair-write-line handle "Load result: OK")
        (swtitle-duppair-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-duppair-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-duppair-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-duppair-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (if load-ok
        (progn
          (setq fixture (swtitle-duppair-create-fixture))
          (swtitle-duppair-write-line
            handle
            (strcat
              "Fixture handles frame/title/apply + frame/title/upgrade: "
              (swcad-title-ename-handle (car fixture))
              "/"
              (swcad-title-ename-handle (cadr fixture))
              " + "
              (swcad-title-ename-handle (nth 2 fixture))
              "/"
              (swcad-title-ename-handle (nth 3 fixture))
            )
          )
          (swtitle-duppair-write-line
            handle
            (strcat
              "Duplicate function present: "
              (if (swtitle-duppair-symbol-present-p "SWCAD-TITLE-DUPLICATE-TARGET-PAIR-RECORDS") "yes" "no")
            )
          )
          (if (swtitle-duppair-symbol-present-p "SWCAD-TITLE-DUPLICATE-TARGET-PAIR-RECORDS")
            (progn
              (setq records (swcad-title-duplicate-target-pair-records))
              (swtitle-duppair-write-line handle (strcat "Duplicate target pair count: " (itoa (length records))))
              (if records
                (progn
                  (setq first (car records))
                  (setq keep (cadr first))
                  (setq discard (caddr first))
                  (swtitle-duppair-write-line
                    handle
                    (strcat
                      "Keep frame/title role: "
                      (swcad-title-ename-handle (cadr keep))
                      "/"
                      (swcad-title-ename-handle (car keep))
                      " "
                      (swcad-title-exemplar-role (cadr keep))
                      "/"
                      (swcad-title-exemplar-role (car keep))
                    )
                  )
                  (swtitle-duppair-write-line
                    handle
                    (strcat
                      "Discard frame/title role: "
                      (swcad-title-ename-handle (cadr discard))
                      "/"
                      (swcad-title-ename-handle (car discard))
                      " "
                      (swcad-title-exemplar-role (cadr discard))
                      "/"
                      (swcad-title-exemplar-role (car discard))
                    )
                  )
                )
              )
              (setq pass
                (and
                  (= (length records) 1)
                  (equal (strcase (swcad-title-exemplar-role (cadr keep))) "NATIVE-UPGRADE")
                  (equal (strcase (swcad-title-exemplar-role (cadr discard))) "NATIVE-APPLY")
                )
              )
              (swtitle-duppair-write-line handle (strcat "Duplicate target pair probe passed: " (if pass "yes" "no")))
            )
            (swtitle-duppair-write-line handle "Duplicate target pair probe passed: no-function")
          )
        )
      )
      (swtitle-duppair-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-duppair-main)
