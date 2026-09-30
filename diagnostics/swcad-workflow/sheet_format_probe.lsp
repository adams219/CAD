;;; SWCADRUN SHEET_FORMAT probe (SOLIDWORKS default sheet format drawn with lines).
;;; Runs in GstarCAD /b on a work copy of a bound COLLECT drawing.
;;; Environment:
;;;   SWT_SF_LOG        log path
;;;   SWT_SF_LOADER     swcad_workflow_load.lsp
;;;   SWT_SF_MODE       RECOGNIZE (read only) or APPLY (runs the step)
;;;   SWT_SF_EXPECT     APPLY: OK or STOP
;;;   SWT_SF_FRAME_DIR  optional folder used instead of the GstarCAD Format folder
;;;                     for the DR frame file check (e.g. with a test DR_A0_Outline)

(vl-load-com)
(load (getenv "SWT_SF_LOADER"))

(setq *swt-sf-log* nil)

(defun swt-sf-line (parts / text part)
  (setq text "")
  (foreach part parts
    (setq text (strcat text (if (= text "") "" "|") (vl-string-translate "|\n\r\t" "/   " (vl-princ-to-string part))))
  )
  (write-line text *swt-sf-log*)
)

(defun swt-sf-check (label actual expected)
  (swt-sf-line (list (if (equal actual expected) "UNIT_OK" "UNIT_FAIL") label actual expected))
)

(defun swt-sf-recognize-all (/ items anchors records item)
  (setq items (swapp-swfmt-scan))
  (setq anchors nil)
  (foreach item items
    (if (and (swapp-swfmt-text-item-p item) (equal (nth 5 item) *swapp-swfmt-anchor-text*))
      (setq anchors (cons item anchors))
    )
  )
  (setq records (swapp-source-sheet-records-read))
  (mapcar '(lambda (a) (swapp-swfmt-recognize a items records)) anchors)
)

(defun swt-sf-sheet-by-stem (sheets stem / found sheet)
  (setq found nil)
  (foreach sheet sheets
    (if (and (not found) (equal (swapp-swfmt-value sheet "stem") stem)) (setq found sheet))
  )
  found
)

(defun swt-sf-value (sheet tag)
  (cdr (assoc tag (swapp-swfmt-value sheet "values")))
)

(defun swt-sf-dump (sheets / sheet value)
  (foreach sheet (vl-sort sheets '(lambda (a b) (< (swapp-swfmt-value a "stem") (swapp-swfmt-value b "stem"))))
    (swt-sf-line
      (list
        "SHEET" (swapp-swfmt-value sheet "stem") (swapp-swfmt-value sheet "status") (swapp-swfmt-value sheet "size")
        (length (swapp-swfmt-value sheet "enames")) (swapp-swfmt-value sheet "detail")
      )
    )
    (foreach value (swapp-swfmt-value sheet "values")
      (if (> (strlen (cdr value)) 0) (swt-sf-line (list "  VALUE" (car value) (cdr value))))
    )
    (foreach value (swapp-swfmt-value sheet "notes")
      (swt-sf-line (list "  NOTE" value))
    )
  )
)

;;; Known sheets of the 221216 set: the value in the 도면 번호 cell and the scale.
(defun swt-sf-known-values (sheets / sheet)
  (if (setq sheet (swt-sf-sheet-by-stem sheets "01-06-07-00_Bush Inner"))
    (progn
      (swt-sf-check "Bush Inner NR" (swt-sf-value sheet "GEN-TITLE-NR{23}") "Bush Inner")
      (swt-sf-check "Bush Inner DWG empty" (swt-sf-value sheet "GEN-TITLE-DWG{23}") nil)
      (swt-sf-check "Bush Inner SCA" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:1")
      (swt-sf-check "Bush Inner SIZ" (swt-sf-value sheet "GEN-TITLE-SIZ{6.7}") "A4")
    )
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "01-00-00-00_Brake Part"))
    (progn
      (swt-sf-check "Brake Part NR" (swt-sf-value sheet "GEN-TITLE-NR{23}") "Brake Part")
      (swt-sf-check "Brake Part SCA" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:10")
      (swt-sf-check "Brake Part SIZ" (swt-sf-value sheet "GEN-TITLE-SIZ{6.7}") "A3")
    )
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "00-00-00-00_221216_디알드라이브_감속기 성능 시험기_A3"))
    (progn
      ;; This 도면 번호 value is a two-line SOLIDWORKS note block.
      (swt-sf-check "assembly NR from a note block" (swt-sf-value sheet "GEN-TITLE-NR{23}") "221216_디알드라이브_감속기 성능 시험기_A3")
      (swt-sf-check "assembly SCA" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:20")
    )
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "02-09-15-00_Input Locking Unit Flange"))
    ;; The name runs past the title block's right line and the outer border.
    (swt-sf-check "long NR past the title box" (swt-sf-value sheet "GEN-TITLE-NR{23}") "Input Locking Unit Flange")
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "01-03-00-00_L-Jig"))
    (swt-sf-check "L-Jig SIZ" (swt-sf-value sheet "GEN-TITLE-SIZ{6.7}") "A1")
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "01-06-06-00_Bearing Unit Shaft"))
    (swt-sf-check "Bearing Unit Shaft SIZ" (swt-sf-value sheet "GEN-TITLE-SIZ{6.7}") "A2")
  )
)

(defun swt-sf-model-count (/ ss)
  (setq ss (ssget "_X" '((410 . "Model"))))
  (if ss (sslength ss) 0)
)

(defun swt-sf-swfmt-inserts (kind / result object name)
  (setq result nil)
  (foreach object (swapp-model-insert-objects)
    (setq name (strcase (swapp-reference-name object)))
    (if (wcmatch name (strcat "SWFMT_" kind "*")) (setq result (cons object result)))
  )
  result
)

(defun swt-sf-swfmt-definition-count (/ count block)
  (setq count 0)
  (foreach block (swapp-collection-items (vla-get-Blocks (swapp-doc)))
    (if (wcmatch (strcase (vla-get-Name block)) "SWFMT_*") (setq count (1+ count)))
  )
  count
)

(defun swt-sf-bbox-near-p (a b tol)
  (and a b
    (swapp-near (car a) (car b) tol) (swapp-near (cadr a) (cadr b) tol)
    (swapp-near (caddr a) (caddr b) tol) (swapp-near (cadddr a) (cadddr b) tol)
  )
)

(defun swt-sf-find-insert-by-bbox (objects bbox / found object)
  (setq found nil)
  (foreach object objects
    (if (and (not found) (swt-sf-bbox-near-p (swapp-object-bbox4 object) bbox 0.5)) (setq found object))
  )
  found
)

(defun swt-sf-attribute-alist (object / result att)
  (setq result nil)
  (foreach att (vlax-invoke object 'GetAttributes)
    (setq result (cons (cons (vla-get-TagString att) (vla-get-TextString att)) result))
  )
  result
)

(defun swt-sf-check-applied (sheets / ok-sheets frames titles sheet frame title attrs bad-values bad-frames bad-titles slot expected actual residue summary size)
  (setq ok-sheets sheets)
  (setq frames (swt-sf-swfmt-inserts "A"))
  (setq titles (swt-sf-swfmt-inserts "TITLE_"))
  (swt-sf-check "anchors left" (swapp-swfmt-anchor-count) 0)
  (swt-sf-check "SWFMT frame inserts" (length frames) (length ok-sheets))
  (swt-sf-check "SWFMT title inserts" (length titles) (length ok-sheets))
  (setq bad-frames 0 bad-titles 0 bad-values 0 residue 0)
  (foreach sheet ok-sheets
    (setq frame (swt-sf-find-insert-by-bbox frames (swapp-swfmt-value sheet "paper")))
    (setq title (swt-sf-find-insert-by-bbox titles (swapp-swfmt-value sheet "title")))
    (if (not frame) (progn (setq bad-frames (1+ bad-frames)) (swt-sf-line (list "NO_FRAME_AT_PAPER" (swapp-swfmt-value sheet "stem")))))
    (if (not title) (progn (setq bad-titles (1+ bad-titles)) (swt-sf-line (list "NO_TITLE_AT_BOX" (swapp-swfmt-value sheet "stem")))))
    (if frame
      (progn
        (setq size (swcad-title-sheet-size-from-block-name (swapp-reference-name frame)))
        (if (not (equal size (swapp-swfmt-value sheet "size")))
          (progn (setq bad-frames (1+ bad-frames)) (swt-sf-line (list "FRAME_SIZE" (swapp-swfmt-value sheet "stem") size)))
        )
        (if (swcad-title-source-sheet-residue-records (swapp-swfmt-value sheet "paper") nil (vlax-vla-object->ename frame))
          (setq residue (1+ residue))
        )
      )
    )
    (if title
      (progn
        (setq attrs (swt-sf-attribute-alist title))
        (foreach slot *swcad-title-transfer-template*
          (setq expected (swt-sf-value sheet (car slot)))
          (if (not expected) (setq expected ""))
          (setq actual (cdr (assoc (car slot) attrs)))
          (if (not (equal actual expected))
            (progn
              (setq bad-values (1+ bad-values))
              (swt-sf-line (list "ATTR_MISMATCH" (swapp-swfmt-value sheet "stem") (car slot) actual expected))
            )
          )
        )
      )
    )
  )
  (swt-sf-check "every sheet has its frame at the paper outline" bad-frames 0)
  (swt-sf-check "every sheet has its title at the title box" bad-titles 0)
  (swt-sf-check "title attributes equal the read values" bad-values 0)
  (swt-sf-check "no residue regions on SWFMT frames" residue 0)
  (setq summary (swcad-title-fast-sheet-summary))
  (swt-sf-check "TITLE step sees the titles" (swcad-title-fast-summary-value summary "source-title-count") (length ok-sheets))
  (swt-sf-check "TITLE step sees the frames" (swcad-title-fast-summary-value summary "source-frame-count") (length ok-sheets))
  (swt-sf-check "stage after SHEET_FORMAT" (swapp-workflow-stage) "TITLE")
  (swt-sf-check "state" (swapp-state-value "SHEET_FORMAT") "OK")
)

(defun swt-sf-main (/ mode sheets ok-count before-count before-anchors before-dimensions result after-count deleted)
  (setq *swt-sf-log* (open (getenv "SWT_SF_LOG") "w"))
  (setq mode (getenv "SWT_SF_MODE"))
  (if (and (getenv "SWT_SF_FRAME_DIR") (/= (getenv "SWT_SF_FRAME_DIR") ""))
    (setq *swapp-swfmt-frame-file-override* (getenv "SWT_SF_FRAME_DIR"))
  )
  (swt-sf-line (list "VERSION" *swapp-version* *swcad-title-scale-version* "DWG" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
  (setq sheets (swt-sf-recognize-all))
  (setq ok-count 0)
  (foreach result sheets (if (equal (swapp-swfmt-value result "status") "OK") (setq ok-count (1+ ok-count))))
  (swt-sf-line (list "RECOGNIZED" (length sheets) "OK" ok-count "SOURCE_RECORDS" (length (swapp-source-sheet-records-read))))
  (swt-sf-line (list "STAGE_BEFORE" (swapp-workflow-stage)))
  (swt-sf-dump sheets)
  (swt-sf-known-values sheets)
  (if (equal mode "APPLY")
    (progn
      (setq before-count (swt-sf-model-count))
      (setq before-anchors (swapp-swfmt-anchor-count))
      (setq before-dimensions (swapp-top-dimension-count))
      (setq result (swapp-convert-sheet-formats))
      (setq after-count (swt-sf-model-count))
      (swt-sf-line (list "APPLY_RESULT" result "MODEL_COUNT" before-count after-count))
      (if (equal (getenv "SWT_SF_EXPECT") "STOP")
        (progn
          (swt-sf-check "step stops" result nil)
          (swt-sf-check "nothing changed: model objects" after-count before-count)
          (swt-sf-check "nothing changed: anchors" (swapp-swfmt-anchor-count) before-anchors)
          (swt-sf-check "no SWFMT blocks made" (swt-sf-swfmt-definition-count) 0)
          (swt-sf-check "stage still SHEET_FORMAT" (swapp-workflow-stage) "SHEET_FORMAT")
        )
        (progn
          (swt-sf-check "step succeeds" result T)
          (setq deleted 0)
          (foreach result sheets (setq deleted (+ deleted (length (swapp-swfmt-value result "enames")))))
          (swt-sf-check "model objects: originals out, two inserts per sheet in" after-count (+ (- before-count deleted) (* 2 (length sheets))))
          (swt-sf-check "top dimensions unchanged" (swapp-top-dimension-count) before-dimensions)
          (swt-sf-check-applied sheets)
        )
      )
    )
  )
  (setq *swapp-swfmt-frame-file-override* nil)
  (write-line "Sheet format probe completed: yes" *swt-sf-log*)
  (close *swt-sf-log*)
  (princ)
)
