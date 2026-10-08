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

(defun swt-sf-recognize-all ()
  (swapp-swfmt-sheets (swapp-swfmt-scan) (swapp-source-sheet-records-read))
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

;;; A value as read from the title cells, before FILE NO / File Name come from the
;;; file name.
(defun swt-sf-cell-value (sheet tag)
  (cdr (assoc tag (swapp-swfmt-value sheet "cell-values")))
)

(defun swt-sf-dump (sheets / sheet value)
  (foreach sheet (vl-sort sheets '(lambda (a b) (< (swapp-swfmt-value a "stem") (swapp-swfmt-value b "stem"))))
    (swt-sf-line
      (list
        "SHEET" (swapp-swfmt-value sheet "stem") (swapp-swfmt-value sheet "status") (swapp-swfmt-value sheet "size")
        (if (swapp-swfmt-value sheet "scale") (swcad-title-scale-text (swapp-swfmt-value sheet "scale")) "")
        (length (swapp-swfmt-value sheet "enames")) (swapp-swfmt-value sheet "detail")
        (if (swapp-swfmt-value sheet "paper")
          (strcat (rtos (- (caddr (swapp-swfmt-value sheet "paper")) (car (swapp-swfmt-value sheet "paper"))) 2 1) "x"
                  (rtos (- (cadddr (swapp-swfmt-value sheet "paper")) (cadr (swapp-swfmt-value sheet "paper"))) 2 1))
          ""
        )
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
      (swt-sf-check "Bush Inner 도면 번호 cell" (swt-sf-cell-value sheet "GEN-TITLE-NR{23}") "Bush Inner")
      (swt-sf-check "Bush Inner 제목 cell empty" (swt-sf-cell-value sheet "GEN-TITLE-DWG{23}") nil)
      ;; FILE NO and File Name come from the file name (user decision 2026-10-08).
      (swt-sf-check "Bush Inner FILE NO" (swt-sf-value sheet "GEN-TITLE-NR{23}") "01-06-07-00")
      (swt-sf-check "Bush Inner File Name" (swt-sf-value sheet "GEN-TITLE-DWG{23}") "Bush Inner")
      (swt-sf-check "Bush Inner SCA" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:1")
      (swt-sf-check "Bush Inner SIZ" (swt-sf-value sheet "GEN-TITLE-SIZ{6.7}") "A4")
    )
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "01-00-00-00_Brake Part"))
    (progn
      (swt-sf-check "Brake Part FILE NO" (swt-sf-value sheet "GEN-TITLE-NR{23}") "01-00-00-00")
      (swt-sf-check "Brake Part File Name" (swt-sf-value sheet "GEN-TITLE-DWG{23}") "Brake Part")
      (swt-sf-check "Brake Part SCA" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:10")
      (swt-sf-check "Brake Part SIZ" (swt-sf-value sheet "GEN-TITLE-SIZ{6.7}") "A3")
    )
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "00-00-00-00_221216_디알드라이브_감속기 성능 시험기_A3"))
    (progn
      ;; This 도면 번호 value is a two-line SOLIDWORKS note block.
      (swt-sf-check "assembly 도면 번호 cell from a note block" (swt-sf-cell-value sheet "GEN-TITLE-NR{23}") "221216_디알드라이브_감속기 성능 시험기_A3")
      (swt-sf-check "assembly FILE NO" (swt-sf-value sheet "GEN-TITLE-NR{23}") "00-00-00-00")
      (swt-sf-check "assembly File Name keeps inner _" (swt-sf-value sheet "GEN-TITLE-DWG{23}") "221216_디알드라이브_감속기 성능 시험기_A3")
      (swt-sf-check "assembly SCA" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:20")
    )
  )
  (if (setq sheet (swt-sf-sheet-by-stem sheets "02-09-15-00_Input Locking Unit Flange"))
    ;; The name runs past the title block's right line and the outer border.
    (swt-sf-check "long 도면 번호 past the title box" (swt-sf-cell-value sheet "GEN-TITLE-NR{23}") "Input Locking Unit Flange")
  )
  ;; Custom-size sheets get an enlarged DR frame; the drawing stays 1:1.  These need
  ;; DR_A0_Outline (installed, or -TestA0Frame).
  (if (and (setq sheet (swt-sf-sheet-by-stem sheets "06-00-00-00_Base Frame")) (equal (swapp-swfmt-value sheet "status") "OK"))
    (progn
      (swt-sf-check "Base Frame frame" (list (swapp-swfmt-value sheet "size") (swapp-swfmt-value sheet "scale")) '("A0" 4.0))
      (swt-sf-check "Base Frame SCA is the frame scale" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:4")
    )
  )
  (if (and (setq sheet (swt-sf-sheet-by-stem sheets "07-00-00-00_Brake Base Plate")) (equal (swapp-swfmt-value sheet "status") "OK"))
    (progn
      (swt-sf-check "Brake Base Plate frame" (list (swapp-swfmt-value sheet "size") (swapp-swfmt-value sheet "scale")) '("A0" 2.0))
      (swt-sf-check "Brake Base Plate SCA is the frame scale" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:2")
    )
  )
  ;; 08 has no frame at all: a DR frame around its 2064 x 850 mm drawing, wider
  ;; than A0, so DR_A0 at 1:2, and no values but size and scale.
  (if (setq sheet (swt-sf-sheet-by-stem sheets "08-00-00-00_Drive Base Plate"))
    (progn
      (swt-sf-check "Drive Base Plate frameless" (swapp-swfmt-value sheet "frameless") T)
      (swt-sf-check "Drive Base Plate frame" (list (swapp-swfmt-value sheet "status") (swapp-swfmt-value sheet "size") (swapp-swfmt-value sheet "scale")) '("OK" "A0" 2.0))
      (swt-sf-check "Drive Base Plate SCA" (swt-sf-value sheet "GEN-TITLE-SCA{6.7}") "1:2")
      (swt-sf-check "Drive Base Plate FILE NO" (swt-sf-value sheet "GEN-TITLE-NR{23}") "08-00-00-00")
      (swt-sf-check "Drive Base Plate File Name" (swt-sf-value sheet "GEN-TITLE-DWG{23}") "Drive Base Plate")
      (swt-sf-check "Drive Base Plate no format entities" (swapp-swfmt-value sheet "enames") nil)
    )
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

;;; The frame insert of a paper: inserted at the paper's lower-left corner and covering
;;; the paper.  Its extents may reach a little past the paper: the two-letter zone
;;; letters of 06 (AA, AC, ...) are wider than the border band (up to 1.45 mm).
(defun swt-sf-find-frame-at-paper (objects paper / found object point bbox)
  (setq found nil)
  (foreach object objects
    (setq point (vlax-get object 'InsertionPoint))
    (setq bbox (swapp-object-bbox4 object))
    (if
      (and
        (not found) bbox
        (swapp-near (car point) (car paper) 0.5) (swapp-near (cadr point) (cadr paper) 0.5)
        (swapp-swfmt-inside-p paper bbox 0.5)
        (swapp-swfmt-inside-p bbox paper 5.0)
      )
      (setq found object)
    )
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
    (setq frame (swt-sf-find-frame-at-paper frames (swapp-swfmt-value sheet "paper")))
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
  ;; Layout names come from these stems; a dot inside a name is not an extension.
  (swt-sf-check "stem keeps an inner dot" (swapp-file-stem-value "01-06-11-00_B.P Housing Cover") "01-06-11-00_B.P Housing Cover")
  (swt-sf-check "stem drops folder and .DWG" (swapp-file-stem-value "C:\\x\\02-09-05-00_D.P Bearing Unit Shaft.DWG") "02-09-05-00_D.P Bearing Unit Shaft")
  (swt-sf-check "source stem from a path" (swapp-source-stem-from-path-or-name "C:/x/01-06-13-00_B.P Sensor Bracket.dwg" "") "01-06-13-00_B.P Sensor Bracket")
  (swt-sf-check "source stem from an XREF name" (swapp-source-stem-from-path-or-name "" "01-06-13-00_B.P Sensor Bracket") "01-06-13-00_B.P Sensor Bracket")
  (swt-sf-check "number split" (swapp-drawing-number-split "01-06-11-00_B.P Housing Cover") '("01-06-11-00" "B.P Housing Cover"))
  (swt-sf-check "number split, no number" (swapp-drawing-number-split "Drive Base Plate") nil)
  (swt-sf-check "file name tags keep a name without number" (swapp-swfmt-file-name-tags '(("GEN-TITLE-NR{23}" . "X")) "Drive Base Plate") '(("GEN-TITLE-NR{23}" . "X")))
  (swt-sf-check "layout name keeps an inner dot" (swapp-clean-layout-base-name "02-09-05-00_D.P Bearing Unit Shaft") "02-09-05-00_D.P Bearing Unit Shaft")
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
