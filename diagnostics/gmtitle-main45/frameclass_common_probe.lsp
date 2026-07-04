;;; Tracked synthetic frame-definition classification probe for main45.
;;; The PowerShell wrapper sets SWCAD_TOOL_ROOT, SWCAD_FRAMECLASS_SCENARIO,
;;; and optionally SWCAD_FRAMECLASS_LSP.
;;; This script creates synthetic DR_A2/A3/A4 block definitions in a copied DWG.
;;; It does not save the drawing.

(defun swtitle-frameclass-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-frameclass-path (relative)
  (strcat (swtitle-frameclass-root) "/" relative)
)

(defun swtitle-frameclass-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-frameclass-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-frameclass-scenario ()
  (setq scenario (getenv "SWCAD_FRAMECLASS_SCENARIO"))
  (if (or (not scenario) (= (strlen scenario) 0))
    (setq scenario "mixed")
  )
  (strcase scenario)
)

(defun swtitle-frameclass-point (x y)
  (list x y 0.0)
)

(defun swtitle-frameclass-entmake-line (p1 p2)
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
)

(defun swtitle-frameclass-entmake-text (point text height)
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
)

(defun swtitle-frameclass-entmake-insert (name point)
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
)

(defun swtitle-frameclass-block-begin (name)
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

(defun swtitle-frameclass-block-end ()
  (entmake
    (list
      '(0 . "ENDBLK")
      '(100 . "AcDbEntity")
      '(8 . "0")
      '(100 . "AcDbBlockEnd")
    )
  )
)

(defun swtitle-frameclass-create-child-block (name / ok)
  (setq ok nil)
  (if (not (swcad-title-block-exists-p name))
    (progn
      (if (swtitle-frameclass-block-begin name)
        (progn
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point 0.0 0.0) (swtitle-frameclass-point 28.0 0.0))
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point 28.0 0.0) (swtitle-frameclass-point 28.0 12.0))
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point 28.0 12.0) (swtitle-frameclass-point 0.0 12.0))
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point 0.0 12.0) (swtitle-frameclass-point 0.0 0.0))
          (swtitle-frameclass-entmake-text (swtitle-frameclass-point 2.0 3.0) "SW NOTE SOURCE" 2.5)
          (swtitle-frameclass-block-end)
          (setq ok T)
        )
      )
    )
    (setq ok T)
  )
  ok
)

(defun swtitle-frameclass-title-point (frame-name / region)
  (setq region (swcad-title-frame-embedded-title-region-for-block frame-name))
  (if region
    (swtitle-frameclass-point
      (/ (+ (car region) (caddr region)) 2.0)
      (/ (+ (cadr region) (cadddr region)) 2.0)
    )
    (swtitle-frameclass-point 10.0 10.0)
  )
)

(defun swtitle-frameclass-create-frame-block (frame-name mode / sheet dims width height title-point child-name)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-name))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq width (if dims (car dims) 420.0))
  (setq height (if dims (cadr dims) 297.0))
  (setq title-point (swtitle-frameclass-title-point frame-name))
  (if (not (swcad-title-block-exists-p frame-name))
    (progn
      (setq child-name (strcat "9_SW_NOTE_" sheet "_FRAMECLASS_PROBE"))
      (if (equal mode "source")
        (swtitle-frameclass-create-child-block child-name)
      )
      (if (swtitle-frameclass-block-begin frame-name)
        (progn
          ;; Frame edges should be protected and not counted as title residue.
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point 0.0 0.0) (swtitle-frameclass-point width 0.0))
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point width 0.0) (swtitle-frameclass-point width height))
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point width height) (swtitle-frameclass-point 0.0 height))
          (swtitle-frameclass-entmake-line (swtitle-frameclass-point 0.0 height) (swtitle-frameclass-point 0.0 0.0))
          (cond
            ((equal mode "native")
              (swtitle-frameclass-entmake-text title-point "Native title-like geometry" 3.0)
            )
            ((equal mode "source")
              (swtitle-frameclass-entmake-insert child-name title-point)
            )
          )
          (swtitle-frameclass-block-end)
          T
        )
        nil
      )
    )
    nil
  )
)

(defun swtitle-frameclass-mode-for (scenario frame-name)
  (cond
    ((equal scenario "MIXED")
      (cond
        ((equal frame-name "DR_A2_Outline") "outline")
        ((equal frame-name "DR_A3_Outline") "native")
        ((equal frame-name "DR_A4_Outline") "source")
        (T "outline")
      )
    )
    ((equal scenario "ALL_CONTAMINATED") "source")
    ((equal scenario "ALL_NATIVE") "native")
    (T "outline")
  )
)

(defun swtitle-frameclass-record-classes (records / result record)
  (setq result nil)
  (foreach record records
    (setq result (append result (list (cons (car record) (cadr record)))))
  )
  result
)

(defun swtitle-frameclass-count-records-by-frame (records / result frame pair)
  (setq result nil)
  (foreach record records
    (setq frame (car record))
    (setq pair (assoc frame result))
    (if pair
      (setq result (subst (cons frame (+ 1 (cdr pair))) pair result))
      (setq result (append result (list (cons frame 1))))
    )
  )
  result
)

(defun swtitle-frameclass-write-counts (handle label counts)
  (swtitle-frameclass-write-line handle label)
  (if counts
    (foreach pair counts
      (swtitle-frameclass-write-line handle (strcat "  " (car pair) ": " (itoa (cdr pair))))
    )
    (swtitle-frameclass-write-line handle "  <none>")
  )
)

(defun swtitle-frameclass-class (classes frame)
  (cdr (assoc frame classes))
)

(defun swtitle-frameclass-pass-p (scenario classes blockers cleanup-counts / pass)
  (setq pass T)
  (cond
    ((equal scenario "MIXED")
      (if (not (equal (swtitle-frameclass-class classes "DR_A2_Outline") "outline-only")) (setq pass nil))
      (if (not (equal (swtitle-frameclass-class classes "DR_A3_Outline") "native-format-with-title-geometry")) (setq pass nil))
      (if (not (equal (swtitle-frameclass-class classes "DR_A4_Outline") "source-contaminated")) (setq pass nil))
      (if (/= (length blockers) 1) (setq pass nil))
      (if (not (assoc "DR_A4_Outline" cleanup-counts)) (setq pass nil))
      (if (assoc "DR_A3_Outline" cleanup-counts) (setq pass nil))
    )
    ((equal scenario "ALL_CONTAMINATED")
      (foreach frame '("DR_A2_Outline" "DR_A3_Outline" "DR_A4_Outline")
        (if (not (equal (swtitle-frameclass-class classes frame) "source-contaminated")) (setq pass nil))
        (if (not (assoc frame cleanup-counts)) (setq pass nil))
      )
      (if (/= (length blockers) 3) (setq pass nil))
    )
    ((equal scenario "ALL_NATIVE")
      (foreach frame '("DR_A2_Outline" "DR_A3_Outline" "DR_A4_Outline")
        (if (not (equal (swtitle-frameclass-class classes frame) "native-format-with-title-geometry")) (setq pass nil))
        (if (assoc frame cleanup-counts) (setq pass nil))
      )
      (if (/= (length blockers) 0) (setq pass nil))
    )
  )
  pass
)

(defun swtitle-frameclass-main (/ scenario lsp-path log-path handle load-result load-ok version-value frame mode created records classes blockers cleanup-records cleanup-counts all-embedded all-embedded-counts pass)
  (setq scenario (swtitle-frameclass-scenario))
  (setq lsp-path
    (swtitle-frameclass-env-path
      "SWCAD_FRAMECLASS_LSP"
      (swtitle-frameclass-path "src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq load-result
    (vl-catch-all-apply
      'load
      (list lsp-path)
    )
  )
  (setq load-ok (not (vl-catch-all-error-p load-result)))
  (setq version-value
    (if (boundp '*swcad-title-scale-version*)
      *swcad-title-scale-version*
      "<version variable missing>"
    )
  )
  (setq log-path
    (swtitle-frameclass-path
      (strcat
        "work/swtitle_frameclass_common_probe_"
        (strcase scenario T)
        ".txt"
      )
    )
  )
  (setq handle (open log-path "w"))
  (if handle
    (progn
      (swtitle-frameclass-write-line handle "SWTITLE main45 synthetic common frame-definition probe")
      (swtitle-frameclass-write-line handle (strcat "Scenario: " scenario))
      (swtitle-frameclass-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-frameclass-write-line handle "Load result: OK")
        (swtitle-frameclass-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-frameclass-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-frameclass-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (if load-ok
        (progn
          (foreach frame '("DR_A2_Outline" "DR_A3_Outline" "DR_A4_Outline")
            (setq mode (swtitle-frameclass-mode-for scenario frame))
            (setq created (swtitle-frameclass-create-frame-block frame mode))
            (swtitle-frameclass-write-line
              handle
              (strcat "Fixture frame: " frame ", mode=" mode ", created=" (if created "yes" "no/pre-existing"))
            )
          )
          (setq records (swcad-title-frame-definition-class-records))
          (setq classes (swtitle-frameclass-record-classes records))
          (setq blockers (swcad-title-frame-definition-blocking-records))
          (setq cleanup-records (swcad-title-frame-embedded-title-records))
          (setq cleanup-counts (swtitle-frameclass-count-records-by-frame cleanup-records))
          (setq all-embedded (swcad-title-frame-embedded-title-records-all))
          (setq all-embedded-counts (swtitle-frameclass-count-records-by-frame all-embedded))
          (swtitle-frameclass-write-line handle "Frame definition classes:")
          (foreach record records
            (swtitle-frameclass-write-line
              handle
              (strcat
                "  "
                (car record)
                ": class="
                (cadr record)
                ", embedded="
                (itoa (nth 3 record))
                ", source-like="
                (if (nth 4 record) (swcad-title-list-string (nth 4 record)) "<none>")
              )
            )
          )
          (swtitle-frameclass-write-counts handle "Blocking frame definitions:" (swtitle-frameclass-count-records-by-frame blockers))
          (swtitle-frameclass-write-counts handle "Cleanup records by frame:" cleanup-counts)
          (swtitle-frameclass-write-counts handle "All embedded title-like records by frame:" all-embedded-counts)
          (setq pass (swtitle-frameclass-pass-p scenario classes blockers cleanup-counts))
          (swtitle-frameclass-write-line handle (strcat "Scenario result: " (if pass "PASS" "FAIL")))
        )
      )
      (swtitle-frameclass-write-line handle (strcat "Runtime check completed: " (if (and load-ok pass) "yes" "no")))
      (close handle)
    )
  )
  (princ)
)

(swtitle-frameclass-main)
