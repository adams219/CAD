;;; Synthetic probe for SWTITLESTATUS A3 frame guidance.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LSP
;;;   SWCAD_COMPARE_LABEL
;;;   SWCAD_COMPARE_LOG
;;; This script modifies only the copied probe DWG and does not save it.

(vl-load-com)

(defun swtitle-a3guide-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-a3guide-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-a3guide-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-a3guide-symbol-present-p (symbol-name / found symbol value)
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

(defun swtitle-a3guide-delete-all-inserts (/ ss index ename)
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

(defun swtitle-a3guide-ensure-rect-block (name width height /)
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

(defun swtitle-a3guide-insert-block (name point /)
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

(defun swtitle-a3guide-create-fixture (/ frame-name title-name frame title)
  (setq frame-name "DR_A3_Outline")
  (setq title-name "DR_titlea_3rd")
  (swtitle-a3guide-delete-all-inserts)
  (swtitle-a3guide-ensure-rect-block frame-name 420.0 297.0)
  (swtitle-a3guide-ensure-rect-block title-name 180.0 42.0)
  (setq frame (swtitle-a3guide-insert-block frame-name '(0.0 0.0 0.0)))
  (setq title (swtitle-a3guide-insert-block title-name '(230.0 10.0 0.0)))
  (if (swtitle-a3guide-symbol-present-p "SWCAD-TITLE-MARK-NATIVE-EXEMPLAR-PAIR")
    (swcad-title-mark-native-exemplar-pair title frame frame-name "clone")
  )
  (list frame title)
)

(defun swtitle-a3guide-file-contains-p (path pattern / handle line found)
  (setq found nil)
  (setq handle (open path "r"))
  (if handle
    (progn
      (while (and (not found) (setq line (read-line handle)))
        (if (vl-string-search pattern line)
          (setq found T)
        )
      )
      (close handle)
    )
  )
  found
)

(defun swtitle-a3guide-main (/ root lsp-path log-path label handle load-result load-ok version-value fixture frame title suffix status-result status-value structure-log candidate-count frame-note-found supplement-found pass)
  (setq root (swtitle-a3guide-root))
  (setq lsp-path
    (swtitle-a3guide-env-path
      "SWCAD_COMPARE_LSP"
      (strcat root "/src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-a3guide-env-path
      "SWCAD_COMPARE_LOG"
      (strcat root "/work/swtitle_a3_status_guidance_probe.txt")
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
      (swtitle-a3guide-write-line handle "SWTITLE A3 status guidance probe")
      (swtitle-a3guide-write-line handle (strcat "Label: " label))
      (swtitle-a3guide-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-a3guide-write-line handle "Load result: OK")
        (swtitle-a3guide-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-a3guide-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-a3guide-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (swtitle-a3guide-write-line handle (strcat "CTAB: " (getvar "CTAB")))
      (if load-ok
        (progn
          (setq suffix "_a3_status_guidance_probe")
          (setq *swcad-title-log-file-suffix* suffix)
          (setq fixture (swtitle-a3guide-create-fixture))
          (setq frame (car fixture))
          (setq title (cadr fixture))
          (swtitle-a3guide-write-line
            handle
            (strcat
              "Fixture frame/title handles: "
              (swcad-title-ename-handle frame)
              "/"
              (swcad-title-ename-handle title)
            )
          )
          (setq candidate-count (length (swcad-title-a3a4-native-upgrade-candidate-records)))
          (swtitle-a3guide-write-line handle (strcat "A3/A4 candidate count before SWTITLESTATUS: " (itoa candidate-count)))
          (setq status-result (vl-catch-all-apply 'c:SWTITLESTATUS nil))
          (if (vl-catch-all-error-p status-result)
            (swtitle-a3guide-write-line handle (strcat "SWTITLESTATUS result: ERROR - " (vl-catch-all-error-message status-result)))
            (swtitle-a3guide-write-line handle "SWTITLESTATUS result: OK")
          )
          (setq status-value
            (if (boundp '*swcad-title-last-apply-status*)
              (if *swcad-title-last-apply-status* *swcad-title-last-apply-status* "<none>")
              "<missing>"
            )
          )
          (swtitle-a3guide-write-line handle (strcat "Status after SWTITLESTATUS: " status-value))
          (setq structure-log (swcad-title-work-log-path "swcad_title_structure_diagnosis_last.txt"))
          (swtitle-a3guide-write-line handle (strcat "Structure log: " structure-log))
          (setq frame-note-found
            (swtitle-a3guide-file-contains-p
              structure-log
              "A3 도면틀 참고: DR_A3_Outline은 native GMTITLE에서도 INSERT/block 참조"
            )
          )
          (setq supplement-found
            (swtitle-a3guide-file-contains-p
              structure-log
              "A3 판단 보충: 도면틀이 block처럼 보이는 현상 자체보다 복제/shared-native-link 후보"
            )
          )
          (swtitle-a3guide-write-line handle (strcat "A3 frame guidance note found: " (if frame-note-found "yes" "no")))
          (swtitle-a3guide-write-line handle (strcat "A3 native-candidate supplement found: " (if supplement-found "yes" "no")))
          (setq pass
            (and
              (= candidate-count 1)
              frame-note-found
              supplement-found
            )
          )
          (swtitle-a3guide-write-line handle (strcat "A3 status guidance probe passed: " (if pass "yes" "no")))
        )
      )
      (swtitle-a3guide-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-a3guide-main)
