;;; Read-only synthetic probe for sheet-residue cleanup protection.
;;;
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_RESIDUE_LSP
;;;   SWCAD_RESIDUE_LABEL
;;;   SWCAD_RESIDUE_LOG
;;;
;;; The probe creates temporary entities far from the real drawing, then calls
;;; swcad-title-source-sheet-residue-records. It verifies that likely sheet
;;; residue is selected while real notes/balloons/BOM-like blocks are preserved.

(defun swtitle-residue-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-residue-path (relative)
  (strcat (swtitle-residue-root) "/" relative)
)

(defun swtitle-residue-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-residue-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-residue-point (x y)
  (list x y 0.0)
)

(defun swtitle-residue-entmake-line (p1 p2 / before after)
  (setq before (entlast))
  (entmake
    (list
      '(0 . "LINE")
      '(100 . "AcDbEntity")
      '(8 . "0")
      '(100 . "AcDbLine")
      (cons 10 p1)
      (cons 11 p2)
    )
  )
  (setq after (entlast))
  (if (eq before after) nil after)
)

(defun swtitle-residue-entmake-text (point text height / before after)
  (setq before (entlast))
  (entmake
    (list
      '(0 . "TEXT")
      '(100 . "AcDbEntity")
      '(8 . "0")
      '(100 . "AcDbText")
      (cons 10 point)
      (cons 40 height)
      (cons 1 text)
      '(50 . 0.0)
      '(7 . "Standard")
      '(72 . 0)
      '(73 . 0)
    )
  )
  (setq after (entlast))
  (if (eq before after) nil after)
)

(defun swtitle-residue-block-begin (name)
  (entmake
    (list
      '(0 . "BLOCK")
      '(100 . "AcDbEntity")
      '(8 . "0")
      '(100 . "AcDbBlockBegin")
      (cons 2 name)
      '(70 . 0)
      '(10 0.0 0.0 0.0)
    )
  )
)

(defun swtitle-residue-block-end ()
  (entmake
    (list
      '(0 . "ENDBLK")
      '(100 . "AcDbEntity")
      '(100 . "AcDbBlockEnd")
    )
  )
)

(defun swtitle-residue-create-block (name width height)
  (if (not (swcad-title-block-exists-p name))
    (progn
      (swtitle-residue-block-begin name)
      (swtitle-residue-entmake-line (swtitle-residue-point 0.0 0.0) (swtitle-residue-point width 0.0))
      (swtitle-residue-entmake-line (swtitle-residue-point width 0.0) (swtitle-residue-point width height))
      (swtitle-residue-entmake-line (swtitle-residue-point width height) (swtitle-residue-point 0.0 height))
      (swtitle-residue-entmake-line (swtitle-residue-point 0.0 height) (swtitle-residue-point 0.0 0.0))
      (swtitle-residue-block-end)
    )
  )
  T
)

(defun swtitle-residue-entmake-insert (name point / before after)
  (setq before (entlast))
  (entmake
    (list
      '(0 . "INSERT")
      '(100 . "AcDbEntity")
      '(8 . "0")
      '(100 . "AcDbBlockReference")
      (cons 2 name)
      (cons 10 point)
      '(41 . 1.0)
      '(42 . 1.0)
      '(43 . 1.0)
      '(50 . 0.0)
    )
  )
  (setq after (entlast))
  (if (eq before after) nil after)
)

(defun swtitle-residue-record-has-handle-p (records handle / found record)
  (setq found nil)
  (foreach record records
    (if (equal (strcase (swcad-title-string (car record))) (strcase (swcad-title-string handle)))
      (setq found T)
    )
  )
  found
)

(defun swtitle-residue-main (/ lsp-path log-path label handle load-result load-ok version-value frame-bbox base-x base-y logo-line note-text small-note wide-note sheet-format bom-table records logo-h note-h small-h wide-h sheet-h bom-h pass)
  (setq lsp-path
    (swtitle-residue-env-path
      "SWCAD_RESIDUE_LSP"
      (swtitle-residue-path "src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-residue-env-path
      "SWCAD_RESIDUE_LOG"
      (swtitle-residue-path "work/swtitle_residue_protection_probe.txt")
    )
  )
  (setq label (getenv "SWCAD_RESIDUE_LABEL"))
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
      (swtitle-residue-write-line handle "SWTITLE sheet residue protection probe")
      (swtitle-residue-write-line handle (strcat "Label: " label))
      (swtitle-residue-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-residue-write-line handle "Load result: OK")
        (swtitle-residue-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-residue-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-residue-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (if load-ok
        (progn
          (setq base-x -10000.0)
          (setq base-y -10000.0)
          (setq frame-bbox (list base-x base-y (+ base-x 420.0) (+ base-y 297.0)))
          (swtitle-residue-create-block "SW_NOTE_BALLOON_PROBE" 10.0 10.0)
          (swtitle-residue-create-block "SW_NOTE_WIDE_SHEET_PROBE" 60.0 6.0)
          (swtitle-residue-create-block "SHEET_FORMAT_PROBE" 60.0 6.0)
          (swtitle-residue-create-block "BOM_TABLE_PROBE" 80.0 30.0)
          (setq logo-line (swtitle-residue-entmake-line (swtitle-residue-point (+ base-x 5.0) (+ base-y 5.0)) (swtitle-residue-point (+ base-x 25.0) (+ base-y 5.0))))
          (setq note-text (swtitle-residue-entmake-text (swtitle-residue-point (+ base-x 10.0) (+ base-y 14.0)) "REAL NOTE 5040" 2.5))
          (setq small-note (swtitle-residue-entmake-insert "SW_NOTE_BALLOON_PROBE" (swtitle-residue-point (+ base-x 315.0) (+ base-y 250.0))))
          (setq wide-note (swtitle-residue-entmake-insert "SW_NOTE_WIDE_SHEET_PROBE" (swtitle-residue-point (+ base-x 300.0) (+ base-y 260.0))))
          (setq sheet-format (swtitle-residue-entmake-insert "SHEET_FORMAT_PROBE" (swtitle-residue-point (+ base-x 20.0) (+ base-y 260.0))))
          (setq bom-table (swtitle-residue-entmake-insert "BOM_TABLE_PROBE" (swtitle-residue-point (+ base-x 150.0) (+ base-y 250.0))))
          (setq records (swcad-title-source-sheet-residue-records frame-bbox nil nil))
          (setq logo-h (swcad-title-ename-handle logo-line))
          (setq note-h (swcad-title-ename-handle note-text))
          (setq small-h (swcad-title-ename-handle small-note))
          (setq wide-h (swcad-title-ename-handle wide-note))
          (setq sheet-h (swcad-title-ename-handle sheet-format))
          (setq bom-h (swcad-title-ename-handle bom-table))
          (swtitle-residue-write-line handle (strcat "Residue candidate count: " (itoa (length records))))
          (swtitle-residue-write-line handle (strcat "bottom-left logo line candidate: " (if (swtitle-residue-record-has-handle-p records logo-h) "yes" "no")))
          (swtitle-residue-write-line handle (strcat "bottom-left real text preserved: " (if (swtitle-residue-record-has-handle-p records note-h) "no" "yes")))
          (swtitle-residue-write-line handle (strcat "upper small SW_NOTE balloon preserved: " (if (swtitle-residue-record-has-handle-p records small-h) "no" "yes")))
          (swtitle-residue-write-line handle (strcat "upper wide SW_NOTE residue candidate: " (if (swtitle-residue-record-has-handle-p records wide-h) "yes" "no")))
          (swtitle-residue-write-line handle (strcat "upper SHEET_FORMAT residue candidate: " (if (swtitle-residue-record-has-handle-p records sheet-h) "yes" "no")))
          (swtitle-residue-write-line handle (strcat "upper BOM-like insert preserved: " (if (swtitle-residue-record-has-handle-p records bom-h) "no" "yes")))
          (setq pass
            (and
              (swtitle-residue-record-has-handle-p records logo-h)
              (not (swtitle-residue-record-has-handle-p records note-h))
              (not (swtitle-residue-record-has-handle-p records small-h))
              (swtitle-residue-record-has-handle-p records wide-h)
              (swtitle-residue-record-has-handle-p records sheet-h)
              (not (swtitle-residue-record-has-handle-p records bom-h))
            )
          )
          (swtitle-residue-write-line handle (strcat "Residue protection passed: " (if pass "yes" "no")))
        )
      )
      (swtitle-residue-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-residue-main)
