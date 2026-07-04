;;; Synthetic comparison probe for native-format frame embedded title cleanup.
;;;
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_EMBEDCMP_LSP
;;;   SWCAD_EMBEDCMP_LABEL
;;;   SWCAD_EMBEDCMP_LOG
;;;   SWCAD_EMBEDCMP_CLEAN
;;;
;;; The fixture creates DR_A2/A3/A4 frame definitions that contain title-like
;;; geometry in the frame definition itself, with no separate DR_titlea_3rd
;;; insert. This isolates the A3/A4 problem where the paper frame already
;;; carries title geometry before conversion.

(defun swtitle-embedcmp-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-embedcmp-path (relative)
  (strcat (swtitle-embedcmp-root) "/" relative)
)

(defun swtitle-embedcmp-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-embedcmp-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-embedcmp-point (x y)
  (list x y 0.0)
)

(defun swtitle-embedcmp-entmake-line (p1 p2)
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

(defun swtitle-embedcmp-entmake-text (point text height)
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

(defun swtitle-embedcmp-block-begin (name)
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

(defun swtitle-embedcmp-block-end ()
  (entmake
    (list
      '(0 . "ENDBLK")
      '(100 . "AcDbEntity")
      '(8 . "0")
      '(100 . "AcDbBlockEnd")
    )
  )
)

(defun swtitle-embedcmp-entmake-insert (name point)
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

(defun swtitle-embedcmp-delete-inserts (name / enames ename)
  (setq enames (swcad-title-inserts-by-effective-name name))
  (foreach ename enames
    (swcad-title-delete-ename ename)
  )
)

(defun swtitle-embedcmp-reset-frame-block (name)
  (if (swcad-title-block-exists-p name)
    (progn
      (swtitle-embedcmp-delete-inserts name)
      (swcad-title-delete-block-definition name)
    )
  )
)

(defun swtitle-embedcmp-create-frame-block (frame-name / sheet dims width height region left bottom right top)
  (swtitle-embedcmp-reset-frame-block frame-name)
  (setq sheet (swcad-title-sheet-size-from-block-name frame-name))
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq width (if dims (car dims) 420.0))
  (setq height (if dims (cadr dims) 297.0))
  (setq region (swcad-title-frame-embedded-title-region-for-block frame-name))
  (setq left (if region (car region) (- width 200.0)))
  (setq bottom (if region (cadr region) 0.0))
  (setq right (if region (min (caddr region) (- width 10.0)) width))
  (setq top (if region (min (cadddr region) 70.0) 60.0))
  (if (swtitle-embedcmp-block-begin frame-name)
    (progn
      ;; Protected outer frame and coordinate marks.
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point 0.0 0.0) (swtitle-embedcmp-point width 0.0))
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point width 0.0) (swtitle-embedcmp-point width height))
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point width height) (swtitle-embedcmp-point 0.0 height))
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point 0.0 height) (swtitle-embedcmp-point 0.0 0.0))
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point 40.0 0.0) (swtitle-embedcmp-point 40.0 8.0))
      (swtitle-embedcmp-entmake-text (swtitle-embedcmp-point 42.0 2.0) "1" 2.5)
      ;; Title-like geometry inside the frame definition.
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point left bottom) (swtitle-embedcmp-point right bottom))
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point right bottom) (swtitle-embedcmp-point right top))
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point right top) (swtitle-embedcmp-point left top))
      (swtitle-embedcmp-entmake-line (swtitle-embedcmp-point left top) (swtitle-embedcmp-point left bottom))
      (swtitle-embedcmp-entmake-text
        (swtitle-embedcmp-point (+ left 8.0) (+ bottom 14.0))
        (strcat "Built-in title geometry " sheet)
        3.0
      )
      (swtitle-embedcmp-block-end)
      T
    )
    nil
  )
)

(defun swtitle-embedcmp-create-fixture (/ frame x)
  (setq x 0.0)
  (foreach frame '("DR_A2_Outline" "DR_A3_Outline" "DR_A4_Outline")
    (swtitle-embedcmp-create-frame-block frame)
    (swtitle-embedcmp-entmake-insert frame (swtitle-embedcmp-point x 0.0))
    (setq x (+ x 700.0))
  )
)

(defun swtitle-embedcmp-count-records-by-frame (records / result frame pair)
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

(defun swtitle-embedcmp-write-counts (handle label counts)
  (swtitle-embedcmp-write-line handle label)
  (if counts
    (foreach pair counts
      (swtitle-embedcmp-write-line handle (strcat "  " (car pair) ": " (itoa (cdr pair))))
    )
    (swtitle-embedcmp-write-line handle "  <none>")
  )
)

(defun swtitle-embedcmp-clean-requested-p (/ value)
  (setq value (getenv "SWCAD_EMBEDCMP_CLEAN"))
  (and value (= (strcase value) "1"))
)

(defun swtitle-embedcmp-main (/ lsp-path log-path label handle load-result load-ok version-value class-records cleanup-records all-records next-action clean-result after-records pass)
  (setq lsp-path
    (swtitle-embedcmp-env-path
      "SWCAD_EMBEDCMP_LSP"
      (swtitle-embedcmp-path "src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-embedcmp-env-path
      "SWCAD_EMBEDCMP_LOG"
      (swtitle-embedcmp-path "work/swtitle_embedded_title_prepare_compare_probe.txt")
    )
  )
  (setq label (getenv "SWCAD_EMBEDCMP_LABEL"))
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
      (swtitle-embedcmp-write-line handle "SWTITLE embedded-title prepare comparison probe")
      (swtitle-embedcmp-write-line handle (strcat "Label: " label))
      (swtitle-embedcmp-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-embedcmp-write-line handle "Load result: OK")
        (swtitle-embedcmp-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-embedcmp-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-embedcmp-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (if load-ok
        (progn
          (swtitle-embedcmp-create-fixture)
          (setq class-records (swcad-title-frame-definition-class-records))
          (setq cleanup-records (swcad-title-frame-embedded-title-records))
          (setq all-records (swcad-title-frame-embedded-title-records-all))
          (swtitle-embedcmp-write-line handle "Frame definition classes:")
          (foreach record class-records
            (swtitle-embedcmp-write-line
              handle
              (strcat
                "  "
                (car record)
                ": class="
                (cadr record)
                ", embedded="
                (itoa (nth 3 record))
              )
            )
          )
          (swtitle-embedcmp-write-counts handle "Cleanup records by frame:" (swtitle-embedcmp-count-records-by-frame cleanup-records))
          (swtitle-embedcmp-write-counts handle "All embedded title-like records by frame:" (swtitle-embedcmp-count-records-by-frame all-records))
          (setq next-action (vl-catch-all-apply 'swcad-title-integrated-structure-diagnosis nil))
          (if (vl-catch-all-error-p next-action)
            (swtitle-embedcmp-write-line handle (strcat "Structure next action: ERROR - " (vl-catch-all-error-message next-action)))
            (swtitle-embedcmp-write-line handle (strcat "Structure next action: " next-action))
          )
          (if (swtitle-embedcmp-clean-requested-p)
            (progn
              (setq clean-result
                (vl-catch-all-apply
                  'swcad-title-frame-style-normalization-delete-records
                  (list cleanup-records)
                )
              )
              (if (vl-catch-all-error-p clean-result)
                (swtitle-embedcmp-write-line handle (strcat "Cleanup result: ERROR - " (vl-catch-all-error-message clean-result)))
                (progn
                  (setq after-records (swcad-title-frame-embedded-title-records))
                  (swtitle-embedcmp-write-line handle "Cleanup result: OK")
                  (swtitle-embedcmp-write-line handle (strcat "Cleanup deleted count: " (itoa (car clean-result))))
                  (swtitle-embedcmp-write-line handle (strcat "Cleanup record count after clean: " (itoa (length after-records))))
                )
              )
            )
          )
          (setq pass T)
        )
      )
      (swtitle-embedcmp-write-line handle (strcat "Runtime check completed: " (if (and load-ok pass) "yes" "no")))
      (close handle)
    )
  )
  (princ)
)

(swtitle-embedcmp-main)
