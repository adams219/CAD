;;; Read-only synthetic comparison probe for DR frame style normalization.
;;; The PowerShell wrapper sets:
;;;   SWCAD_TOOL_ROOT
;;;   SWCAD_COMPARE_LSP
;;;   SWCAD_COMPARE_LABEL
;;;   SWCAD_COMPARE_LOG
;;;   SWCAD_STYLECMP_SHEETS
;;; This script creates an unsaved fixture in a copied DWG.

(defun swtitle-stylecmp-root (/ root)
  (setq root (getenv "SWCAD_TOOL_ROOT"))
  (if (or (not root) (= (strlen root) 0))
    (setq root "C:/Users/DR-DESIGN/Documents/CAD tool")
  )
  (vl-string-translate "\\" "/" root)
)

(defun swtitle-stylecmp-path (relative)
  (strcat (swtitle-stylecmp-root) "/" relative)
)

(defun swtitle-stylecmp-env-path (name fallback / value)
  (setq value (getenv name))
  (if (or (not value) (= (strlen value) 0))
    (setq value fallback)
  )
  (vl-string-translate "\\" "/" value)
)

(defun swtitle-stylecmp-write-line (handle text)
  (write-line (if text text "") handle)
)

(defun swtitle-stylecmp-symbol-present-p (symbol-name / found symbol value)
  (setq found (atoms-family 1 (list (strcase symbol-name))))
  (if found
    (progn
      (setq symbol (read symbol-name))
      (setq value (vl-catch-all-apply 'eval (list symbol)))
      (if (vl-catch-all-error-p value)
        nil
        (if value T nil)
      )
    )
    nil
  )
)

(defun swtitle-stylecmp-status-value ()
  (if (boundp '*swcad-title-last-apply-status*)
    (if *swcad-title-last-apply-status*
      *swcad-title-last-apply-status*
      "<none>"
    )
    "<status variable missing>"
  )
)

(defun swtitle-stylecmp-point (x y)
  (list x y 0.0)
)

(defun swtitle-stylecmp-entmake-line (p1 p2)
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

(defun swtitle-stylecmp-entmake-text (point text height)
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

(defun swtitle-stylecmp-entmake-insert (name point)
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
  (entlast)
)

(defun swtitle-stylecmp-block-begin (name)
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

(defun swtitle-stylecmp-block-end ()
  (entmake
    (list
      '(0 . "ENDBLK")
      '(100 . "AcDbEntity")
      '(8 . "0")
      '(100 . "AcDbBlockEnd")
    )
  )
)

(defun swtitle-stylecmp-park-existing-block (name / backup)
  (if (swcad-title-block-exists-p name)
    (progn
      (setq backup (swcad-title-unique-block-name name))
      (if (swcad-title-rename-block-definition name backup)
        backup
        nil
      )
    )
    nil
  )
)

(defun swtitle-stylecmp-requested-sheets (/ value upper result)
  (setq value (getenv "SWCAD_STYLECMP_SHEETS"))
  (if (or (not value) (= (strlen value) 0))
    (setq value "A3")
  )
  (setq upper (strcase value))
  (cond
    ((or (equal upper "ALL") (equal upper "A2,A3,A4"))
      '("A2" "A3" "A4")
    )
    (T
      (setq result nil)
      (if (wcmatch upper "*A2*")
        (setq result (append result (list "A2")))
      )
      (if (wcmatch upper "*A3*")
        (setq result (append result (list "A3")))
      )
      (if (wcmatch upper "*A4*")
        (setq result (append result (list "A4")))
      )
      (if result result '("A3"))
    )
  )
)

(defun swtitle-stylecmp-frame-name-for-sheet (sheet)
  (strcat "DR_" (strcase (swcad-title-string sheet)) "_Outline")
)

(defun swtitle-stylecmp-frame-insert-x (sheet)
  (cond
    ((equal (strcase (swcad-title-string sheet)) "A2") 0.0)
    ((equal (strcase (swcad-title-string sheet)) "A3") 700.0)
    ((equal (strcase (swcad-title-string sheet)) "A4") 1200.0)
    (T 0.0)
  )
)

(defun swtitle-stylecmp-create-title-block (/ name)
  (setq name "DR_titlea_3rd")
  (if (not (swcad-title-block-exists-p name))
    (progn
      (swtitle-stylecmp-block-begin name)
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 0.0 0.0) (swtitle-stylecmp-point 180.0 0.0))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 180.0 0.0) (swtitle-stylecmp-point 180.0 42.0))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 180.0 42.0) (swtitle-stylecmp-point 0.0 42.0))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 0.0 42.0) (swtitle-stylecmp-point 0.0 0.0))
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point 8.0 12.0) "DR_titlea_3rd fixture" 3.0)
      (swtitle-stylecmp-block-end)
    )
  )
  T
)

(defun swtitle-stylecmp-create-frame-block (sheet / name child-name logo-name dims width height offset left bottom right top)
  (setq name (swtitle-stylecmp-frame-name-for-sheet sheet))
  (setq child-name (strcat "SWSTYLE_" (strcase (swcad-title-string sheet)) "_FRAME_CONTENT"))
  (setq logo-name (strcat "SWSTYLE_" (strcase (swcad-title-string sheet)) "_TITLE_LOGO"))
  (swtitle-stylecmp-park-existing-block name)
  (swtitle-stylecmp-park-existing-block child-name)
  (swtitle-stylecmp-park-existing-block logo-name)
  (setq dims (swcad-title-sheet-dimensions sheet))
  (setq width (if dims (car dims) 420.0))
  (setq height (if dims (cadr dims) 297.0))
  (setq offset (swcad-title-frame-only-title-offset sheet))
  (setq left (car offset))
  (setq bottom (cadr offset))
  (setq right (min width (+ left 180.0)))
  (setq top (min height (+ bottom 42.0)))
  (if (not (swcad-title-block-exists-p logo-name))
    (progn
      (swtitle-stylecmp-block-begin logo-name)
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 0.0 0.0) (swtitle-stylecmp-point 14.0 10.0))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 0.0 10.0) (swtitle-stylecmp-point 14.0 0.0))
      (swtitle-stylecmp-block-end)
    )
  )
  (if (not (swcad-title-block-exists-p child-name))
    (progn
      (swtitle-stylecmp-block-begin child-name)
      ;; Sheet outer frame and coordinate system must survive cleanup.
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 0.0 0.0) (swtitle-stylecmp-point width 0.0))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point width 0.0) (swtitle-stylecmp-point width height))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point width height) (swtitle-stylecmp-point 0.0 height))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point 0.0 height) (swtitle-stylecmp-point 0.0 0.0))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point (+ left 12.0) 0.0) (swtitle-stylecmp-point (+ left 12.0) 8.0))
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 10.0) 2.0) "1" 2.5)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point 12.0 (- height 18.0)) "Revision note" 3.0)
      ;; Native-format title-like geometry inside the frame definition.
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point left bottom) (swtitle-stylecmp-point right bottom))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point right bottom) (swtitle-stylecmp-point right top))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point right top) (swtitle-stylecmp-point left top))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point left top) (swtitle-stylecmp-point left bottom))
      (swtitle-stylecmp-entmake-line (swtitle-stylecmp-point (+ left 70.0) bottom) (swtitle-stylecmp-point (+ left 70.0) top))
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 5.0) (+ bottom 5.0)) "Edition" 3.0)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 35.0) (+ bottom 5.0)) "Sheet" 3.0)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 65.0) (+ bottom 5.0)) "Scale" 3.0)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 5.0) (+ bottom 18.0)) "Date" 3.0)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 45.0) (+ bottom 18.0)) "Article No./Reference" 8.0)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 5.0) (+ bottom 32.0)) "File No" 3.0)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 45.0) (+ bottom 32.0)) "File name" 3.0)
      ;; Its center is outside the old fixed region, but it visibly intersects the actual-title-derived region.
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point (+ left 5.0) (+ bottom 64.0)) "PARTIAL TITLE RESIDUE" 8.0)
      (swtitle-stylecmp-entmake-insert logo-name (swtitle-stylecmp-point (+ left 120.0) (+ bottom 12.0)))
      (swtitle-stylecmp-block-end)
    )
  )
  (if (not (swcad-title-block-exists-p name))
    (progn
      (swtitle-stylecmp-block-begin name)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point 0.0 0.0) "!GENTITLE-LL" 0.1)
      (swtitle-stylecmp-entmake-text (swtitle-stylecmp-point width height) "!GENTITLE-RU" 0.1)
      (swtitle-stylecmp-entmake-insert child-name (swtitle-stylecmp-point 0.0 0.0))
      (swtitle-stylecmp-block-end)
    )
  )
  T
)

(defun swtitle-stylecmp-create-overlap-fixture-for-sheet (sheet / frame-name offset frame-x frame title)
  (setq frame-name (swtitle-stylecmp-frame-name-for-sheet sheet))
  (setq offset (swcad-title-frame-only-title-offset sheet))
  (setq frame-x (swtitle-stylecmp-frame-insert-x sheet))
  (swtitle-stylecmp-create-frame-block sheet)
  (swtitle-stylecmp-create-title-block)
  (setq frame (swtitle-stylecmp-entmake-insert frame-name (swtitle-stylecmp-point frame-x 0.0)))
  (setq title
    (swtitle-stylecmp-entmake-insert
      "DR_titlea_3rd"
      (swtitle-stylecmp-point (+ frame-x (car offset)) (cadr offset))
    )
  )
  (list sheet frame title)
)

(defun swtitle-stylecmp-create-overlap-fixture (/ result sheet)
  (setq result nil)
  (swtitle-stylecmp-park-existing-block "DR_titlea_3rd")
  (foreach sheet (swtitle-stylecmp-requested-sheets)
    (setq result (append result (list (swtitle-stylecmp-create-overlap-fixture-for-sheet sheet))))
  )
  result
)

(defun swtitle-stylecmp-write-fixture-handles (handle fixtures / fixture)
  (foreach fixture fixtures
    (swtitle-stylecmp-write-line
      handle
      (strcat
        "Fixture "
        (car fixture)
        " frame handle: "
        (swcad-title-ename-handle (cadr fixture))
      )
    )
    (swtitle-stylecmp-write-line
      handle
      (strcat
        "Fixture "
        (car fixture)
        " title handle: "
        (swcad-title-ename-handle (caddr fixture))
      )
    )
  )
)

(defun swtitle-stylecmp-write-class-records (handle / records record)
  (setq records (swcad-title-frame-definition-class-records))
  (swtitle-stylecmp-write-line handle "Frame definition classes:")
  (foreach record records
    (swtitle-stylecmp-write-line
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
)

(defun swtitle-stylecmp-clean-requested-p (/ value)
  (setq value (getenv "SWCAD_STYLECMP_CLEAN"))
  (and value (= (strcase value) "1"))
)

(defun swtitle-stylecmp-run-clean (/ independent-before protected-before clean-records delete-result after-records independent-after second-clean-records second-delete-result)
  (setq independent-before (swcad-title-frame-style-independent-residue-records))
  (setq protected-before (swcad-title-frame-style-protected-records))
  (setq clean-records (swcad-title-frame-style-normalization-entity-records))
  (setq delete-result (swcad-title-frame-style-normalization-delete-records clean-records))
  (vla-Regen (swcad-title-doc) 1)
  (setq after-records (swcad-title-frame-style-normalization-records))
  (setq independent-after (swcad-title-frame-style-independent-residue-records))
  (setq second-clean-records (swcad-title-frame-style-normalization-entity-records))
  (setq second-delete-result (swcad-title-frame-style-normalization-delete-records second-clean-records))
  (list clean-records delete-result after-records independent-before protected-before independent-after second-clean-records second-delete-result)
)

(defun swtitle-stylecmp-definition-text-present-p (wanted / found blocks block item ename data etype text)
  (setq found nil)
  (setq blocks (vla-get-Blocks (swcad-title-doc)))
  (vlax-for block blocks
    (if (wcmatch (strcase (vla-get-Name block)) "SWSTYLE_*_FRAME_CONTENT")
      (vlax-for item block
        (setq ename (swcad-title-vla-object->ename item))
        (setq data (if ename (entget ename '("*")) nil))
        (setq etype (strcase (swcad-title-string (swcad-title-dxf-value data 0))))
        (if (member etype '("TEXT" "MTEXT" "ATTDEF"))
          (progn
            (setq text (swcad-title-text-entity-value data))
            (if (equal (strcase (swcad-title-string text)) (strcase (swcad-title-string wanted)))
              (setq found T)
            )
          )
        )
      )
    )
  )
  found
)

(defun swtitle-stylecmp-write-clean-records (handle records / index record ename object)
  (swtitle-stylecmp-write-line handle "Style-normalization clean entity records:")
  (if records
    (progn
      (setq index 1)
      (foreach record records
        (setq ename (nth 2 record))
        (setq object (if ename (swcad-title-safe-vla-object ename) nil))
        (swtitle-stylecmp-write-line
          handle
          (strcat
            "  #"
            (itoa index)
            " owner="
            (cadr record)
            ", handle="
            (nth 3 record)
            ", type="
            (swcad-title-string (nth 4 record))
            ", object="
            (if object "yes" "no")
          )
        )
        (setq index (+ index 1))
      )
    )
    (swtitle-stylecmp-write-line handle "  <none>")
  )
)

(defun swtitle-stylecmp-direct-delete-first-record (records / record object result)
  (setq record (car records))
  (if record
    (progn
      (setq object (swcad-title-safe-vla-object (nth 2 record)))
      (if object
        (progn
          (setq result (vl-catch-all-apply 'vla-Delete (list object)))
          (if (vl-catch-all-error-p result)
            (strcat "ERROR - " (vl-catch-all-error-message result))
            "OK"
          )
        )
        "NO_OBJECT"
      )
    )
    "NO_RECORD"
  )
)

(defun swtitle-stylecmp-main (/ lsp-path log-path label handle load-result load-ok version-value fixture-result fixture class-result style-present style-record-result style-records clean-result clean-records clean-delete-result clean-after-records independent-before protected-before independent-after second-clean-records second-delete-result status-result status-ok verify-result verify-ok)
  (setq lsp-path
    (swtitle-stylecmp-env-path
      "SWCAD_COMPARE_LSP"
      (swtitle-stylecmp-path "src/tools/gmtitle/swcad_title_scale.lsp")
    )
  )
  (setq log-path
    (swtitle-stylecmp-env-path
      "SWCAD_COMPARE_LOG"
      (swtitle-stylecmp-path "work/swtitle_style_normalization_compare_probe.txt")
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
      (swtitle-stylecmp-write-line handle "SWTITLE DR frame style-normalization synthetic comparison probe")
      (swtitle-stylecmp-write-line handle (strcat "Label: " label))
      (swtitle-stylecmp-write-line handle (strcat "LSP path: " lsp-path))
      (if load-ok
        (swtitle-stylecmp-write-line handle "Load result: OK")
        (swtitle-stylecmp-write-line handle (strcat "Load result: ERROR - " (vl-catch-all-error-message load-result)))
      )
      (swtitle-stylecmp-write-line handle (strcat "Loaded version: " version-value))
      (swtitle-stylecmp-write-line handle (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
      (if load-ok
        (progn
          (setq fixture-result (vl-catch-all-apply 'swtitle-stylecmp-create-overlap-fixture nil))
          (if (vl-catch-all-error-p fixture-result)
            (progn
              (swtitle-stylecmp-write-line handle (strcat "Fixture result: ERROR - " (vl-catch-all-error-message fixture-result)))
            )
            (progn
              (setq fixture fixture-result)
              (swtitle-stylecmp-write-line handle "Fixture result: OK")
              (swtitle-stylecmp-write-fixture-handles handle fixture)
              (setq class-result (vl-catch-all-apply 'swtitle-stylecmp-write-class-records (list handle)))
              (if (vl-catch-all-error-p class-result)
                (swtitle-stylecmp-write-line handle (strcat "Class write result: ERROR - " (vl-catch-all-error-message class-result)))
                (swtitle-stylecmp-write-line handle "Class write result: OK")
              )
              (setq style-present (swtitle-stylecmp-symbol-present-p "SWCAD-TITLE-FRAME-STYLE-NORMALIZATION-RECORDS"))
              (swtitle-stylecmp-write-line handle (strcat "Style function present: " (if style-present "yes" "no")))
              (if style-present
                (progn
                  (setq style-record-result (vl-catch-all-apply 'swcad-title-frame-style-normalization-records nil))
                  (if (vl-catch-all-error-p style-record-result)
                    (swtitle-stylecmp-write-line handle (strcat "Style-normalization result: ERROR - " (vl-catch-all-error-message style-record-result)))
                    (progn
                      (setq style-records style-record-result)
                      (swtitle-stylecmp-write-line handle "Style-normalization result: OK")
                      (swtitle-stylecmp-write-line handle (strcat "Style-normalization record count: " (itoa (length style-records))))
                      (foreach record style-records
                        (swtitle-stylecmp-write-line
                          handle
                          (strcat
                            "  style-record frame="
                            (car record)
                            ", frame-handle="
                            (nth 2 record)
                            ", title-handle="
                            (nth 4 record)
                            ", overlap="
                            (swcad-title-bbox-string (nth 8 record))
                          )
                        )
                      )
                    )
                  )
                )
                (swtitle-stylecmp-write-line handle "Style-normalization record count: <unavailable>")
              )
              (if (and style-present (swtitle-stylecmp-clean-requested-p))
                (progn
                  (setq clean-records (swcad-title-frame-style-normalization-entity-records))
                  (swtitle-stylecmp-write-clean-records handle clean-records)
                  (swtitle-stylecmp-write-line handle (strcat "Direct vla-Delete first clean record: " (swtitle-stylecmp-direct-delete-first-record clean-records)))
                  (setq clean-result
                    (vl-catch-all-apply
                      'swtitle-stylecmp-run-clean
                      nil
                    )
                  )
                  (if (vl-catch-all-error-p clean-result)
                    (swtitle-stylecmp-write-line handle (strcat "Style-normalization clean result: ERROR - " (vl-catch-all-error-message clean-result)))
                    (progn
                      (swtitle-stylecmp-write-line handle "Style-normalization clean result: OK")
                      (swtitle-stylecmp-write-line handle (strcat "Style-normalization clean entity count: " (itoa (length (car clean-result)))))
                      (swtitle-stylecmp-write-line handle (strcat "Style-normalization deleted count: " (itoa (car (cadr clean-result)))))
                      (swtitle-stylecmp-write-line handle (strcat "Style-normalization record count after clean: " (itoa (length (caddr clean-result)))))
                      (setq independent-before (nth 3 clean-result))
                      (setq protected-before (nth 4 clean-result))
                      (setq independent-after (nth 5 clean-result))
                      (setq second-clean-records (nth 6 clean-result))
                      (setq second-delete-result (nth 7 clean-result))
                      (swtitle-stylecmp-write-line handle (strcat "Independent residue count before clean: " (itoa (length independent-before))))
                      (swtitle-stylecmp-write-line handle (strcat "Protected frame entity count before clean: " (itoa (length protected-before))))
                      (swtitle-stylecmp-write-line handle (strcat "Independent residue count after clean: " (itoa (length independent-after))))
                      (swtitle-stylecmp-write-line handle (strcat "Second clean entity count: " (itoa (length second-clean-records))))
                      (swtitle-stylecmp-write-line handle (strcat "Second clean deleted count: " (itoa (car second-delete-result))))
                      (swtitle-stylecmp-write-line handle (strcat "Preserved revision text: " (if (swtitle-stylecmp-definition-text-present-p "Revision note") "yes" "no")))
                      (swtitle-stylecmp-write-line handle (strcat "Preserved coordinate text: " (if (swtitle-stylecmp-definition-text-present-p "1") "yes" "no")))
                    )
                  )
                )
              )
              (setq status-result (vl-catch-all-apply 'c:SWTITLESTATUS nil))
              (setq status-ok (not (vl-catch-all-error-p status-result)))
              (if status-ok
                (swtitle-stylecmp-write-line handle "Run SWTITLESTATUS: ok")
                (swtitle-stylecmp-write-line handle (strcat "Run SWTITLESTATUS: error - " (vl-catch-all-error-message status-result)))
              )
              (swtitle-stylecmp-write-line handle (strcat "Status after SWTITLESTATUS: " (swtitle-stylecmp-status-value)))
              (setq verify-result (vl-catch-all-apply 'c:SWTITLEVERIFY nil))
              (setq verify-ok (not (vl-catch-all-error-p verify-result)))
              (if verify-ok
                (swtitle-stylecmp-write-line handle "Run SWTITLEVERIFY: ok")
                (swtitle-stylecmp-write-line handle (strcat "Run SWTITLEVERIFY: error - " (vl-catch-all-error-message verify-result)))
              )
              (swtitle-stylecmp-write-line handle (strcat "Status after SWTITLEVERIFY: " (swtitle-stylecmp-status-value)))
            )
          )
        )
      )
      (swtitle-stylecmp-write-line handle "Runtime check completed: yes")
      (close handle)
    )
  )
  (princ)
)

(swtitle-stylecmp-main)
