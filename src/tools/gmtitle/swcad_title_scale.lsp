;;; Read-only title-block and scale diagnostic module.
;;;
;;; Standalone test workflow:
;;;   APPLOAD this file directly, then run SWTITLEDEBUG, SWTITLESCAN,
;;;   or SWSCALESCAN.
;;;
;;; SWTITLEDEBUG prints raw information from a selected GM TITLE / FTAP
;;; candidate object. It does not modify the drawing.
;;; SWSCALESCAN compares title-block scale candidates with dimension
;;; DIMLFAC values. It does not modify the drawing.

(vl-load-com)

(setq *swcad-title-scale-version* "260626-1530")
(setq *swcad-title-scale-loaded* T)
(setq *swcad-title-debug-log-path* nil)
(setq *swcad-title-debug-log-handle* nil)

(defun swcad-title-princ-line (text)
  (princ (strcat "\n" text))
  (if *swcad-title-debug-log-handle*
    (write-line text *swcad-title-debug-log-handle*)
  )
)

(defun swcad-title-debug-log-path (/ home)
  (swcad-title-work-log-path "swcad_title_debug_last.txt")
)

(defun swcad-title-work-log-path (filename / home)
  (setq home (getenv "USERPROFILE"))
  (if home
    (strcat
      (vl-string-translate "\\" "/" home)
      "/Documents/CAD tool/work/"
      filename
    )
    filename
  )
)

(defun swcad-title-open-log (filename header / handle path)
  (setq path (swcad-title-work-log-path filename))
  (setq handle (open path "w"))
  (setq *swcad-title-debug-log-path* path)
  (setq *swcad-title-debug-log-handle* handle)
  (if handle
    (write-line header handle)
  )
)

(defun swcad-title-open-debug-log ()
  (swcad-title-open-log "swcad_title_debug_last.txt" "SWTITLEDEBUG log")
)

(defun swcad-title-open-scan-log ()
  (swcad-title-open-log "swcad_title_scan_last.txt" "SWTITLESCAN log")
)

(defun swcad-title-open-scale-log ()
  (swcad-title-open-log "swcad_scale_scan_last.txt" "SWSCALESCAN log")
)

(defun swcad-title-close-log ()
  (if *swcad-title-debug-log-handle*
    (progn
      (close *swcad-title-debug-log-handle*)
      (setq *swcad-title-debug-log-handle* nil)
    )
  )
  (if *swcad-title-debug-log-path*
    (princ (strcat "\nSWTITLE log: " *swcad-title-debug-log-path*))
  )
)

(defun swcad-title-string (value)
  (cond
    ((= (type value) 'STR) value)
    ((not value) "")
    (T (vl-princ-to-string value))
  )
)

(defun swcad-title-code-value-line (prefix pair)
  (swcad-title-princ-line
    (strcat
      prefix
      " "
      (swcad-title-string (car pair))
      " = "
      (swcad-title-string (cdr pair))
    )
  )
)

(defun swcad-title-dxf-value (data code)
  (cdr (assoc code data))
)

(defun swcad-title-list-add-unique (value values)
  (if (member value values)
    values
    (append values (list value))
  )
)

(defun swcad-title-string-p (value / typ typtext)
  (setq typ (type value))
  (setq typtext (strcase (vl-princ-to-string typ)))
  (or
    (equal typ 'STR)
    (equal typ "STR")
    (equal typtext "STR")
    (equal typtext "'STR")
    (equal typ 'STRING)
    (equal typ "STRING")
    (equal typtext "STRING")
    (equal typtext "'STRING")
  )
)

(defun swcad-title-safe-string (value)
  (if (swcad-title-string-p value) value nil)
)

(defun swcad-title-number-string (value)
  (if (numberp value)
    (rtos (float value) 2 8)
    (swcad-title-string value)
  )
)

(defun swcad-title-list-string (values / result item)
  (setq result "")
  (foreach item values
    (setq result
      (if (= result "")
        (swcad-title-string item)
        (strcat result ", " (swcad-title-string item))
      )
    )
  )
  (if (= result "") "<none>" result)
)

(defun swcad-title-number-list-string (values / result item)
  (setq result "")
  (foreach item values
    (setq result
      (if (= result "")
        (swcad-title-number-string item)
        (strcat result ", " (swcad-title-number-string item))
      )
    )
  )
  (if (= result "") "<none>" result)
)

(defun swcad-title-float-in-list-p (value values / found item)
  (setq found nil)
  (if (numberp value)
    (foreach item values
      (if (and (numberp item) (equal (float value) (float item) 1e-8))
        (setq found T)
      )
    )
  )
  found
)

(defun swcad-title-list-add-unique-float (value values)
  (if (swcad-title-float-in-list-p value values)
    values
    (append values (list (float value)))
  )
)

(defun swcad-title-count-add (key counts / pair result found)
  (setq result nil)
  (setq found nil)
  (foreach pair counts
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons key (+ (cdr pair) 1)))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key 1)))
  )
)

(defun swcad-title-print-counts (title counts / pair)
  (swcad-title-princ-line title)
  (if counts
    (foreach pair counts
      (swcad-title-princ-line
        (strcat
          "  "
          (swcad-title-string (car pair))
          " x "
          (itoa (cdr pair))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-insert-attributes (ename / next edata etype result)
  (setq result nil)
  (setq next (entnext ename))
  (while next
    (setq edata (entget next '("*")))
    (setq etype (swcad-title-dxf-value edata 0))
    (cond
      ((= etype "ATTRIB")
        (setq result (append result (list edata)))
      )
      ((= etype "SEQEND")
        (setq next nil)
      )
    )
    (if next
      (setq next (entnext next))
    )
  )
  result
)

(defun swcad-title-scale-tag-p (tag / upper)
  (setq upper (strcase (swcad-title-string tag)))
  (or
    (wcmatch upper "*GEN-TITLE-SCA*")
    (wcmatch upper "*TITLE*SCA*")
    (wcmatch upper "*SCALE*")
  )
)

(defun swcad-title-title-block-name-p (name / upper)
  (setq upper (strcase (swcad-title-string name)))
  (or
    (wcmatch upper "*TITLE*")
    (wcmatch upper "*GMTITLE*")
    (wcmatch upper "*FTAP*")
  )
)

(defun swcad-title-safe-vla-object (ename / result)
  (setq result (vl-catch-all-apply 'vlax-ename->vla-object (list ename)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-safe-vla-get (object property / result)
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vlax-get-property (list object property)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-print-basic-entity (ename data / object object-name)
  (setq object (swcad-title-safe-vla-object ename))
  (setq object-name (swcad-title-safe-vla-get object 'ObjectName))
  (swcad-title-princ-line "----- SWTITLEDEBUG BASIC -----")
  (swcad-title-princ-line (strcat "entity type: " (swcad-title-string (swcad-title-dxf-value data 0))))
  (swcad-title-princ-line (strcat "handle: " (swcad-title-string (swcad-title-dxf-value data 5))))
  (swcad-title-princ-line (strcat "layer: " (swcad-title-string (swcad-title-dxf-value data 8))))
  (swcad-title-princ-line (strcat "block name: " (swcad-title-string (swcad-title-dxf-value data 2))))
  (swcad-title-princ-line (strcat "vla object: " (swcad-title-string object-name)))
)

(defun swcad-title-print-data-section (title data / pair)
  (swcad-title-princ-line title)
  (foreach pair data
    (swcad-title-code-value-line "  DXF" pair)
  )
)

(defun swcad-title-print-xdata (ename / xdata pair)
  (setq xdata (entget ename '("*")))
  (swcad-title-princ-line "----- SWTITLEDEBUG XDATA / RAW ENTGET -----")
  (if xdata
    (foreach pair xdata
      (swcad-title-code-value-line "  DXF" pair)
    )
    (swcad-title-princ-line "  No entget data returned.")
  )
)

(defun swcad-title-print-insert-attributes (ename / next edata etype count)
  (swcad-title-princ-line "----- SWTITLEDEBUG ATTRIBUTES -----")
  (setq count 0)
  (foreach edata (swcad-title-insert-attributes ename)
    (setq count (+ count 1))
    (swcad-title-princ-line "  ATTRIBUTE")
    (swcad-title-princ-line (strcat "    tag: " (swcad-title-string (swcad-title-dxf-value edata 2))))
    (swcad-title-princ-line (strcat "    value: " (swcad-title-string (swcad-title-dxf-value edata 1))))
    (swcad-title-princ-line (strcat "    layer: " (swcad-title-string (swcad-title-dxf-value edata 8))))
    (swcad-title-princ-line (strcat "    handle: " (swcad-title-string (swcad-title-dxf-value edata 5))))
  )
  (if (= count 0)
    (progn
      (swcad-title-princ-line "  No following attributes.")
      (swcad-title-princ-line "  No attributes found.")
    )
  )
)

(defun swcad-title-debug-entity (ename / data etype)
  (swcad-title-open-debug-log)
  (setq data (entget ename))
  (setq etype (swcad-title-dxf-value data 0))
  (swcad-title-print-basic-entity ename data)
  (if (= etype "INSERT")
    (swcad-title-print-insert-attributes ename)
    (progn
      (swcad-title-princ-line "----- SWTITLEDEBUG ATTRIBUTES -----")
      (swcad-title-princ-line "  Selected entity is not an INSERT.")
    )
  )
  (swcad-title-print-data-section "----- SWTITLEDEBUG ENTGET -----" data)
  (swcad-title-print-xdata ename)
  (swcad-title-princ-line "----- SWTITLEDEBUG END -----")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-first-implied-selection (/ result ss)
  (setq result (vl-catch-all-apply 'ssget (list "_I")))
  (if (vl-catch-all-error-p result)
    nil
    (progn
      (setq ss result)
      (if (and ss (> (sslength ss) 0))
        (ssname ss 0)
        nil
      )
    )
  )
)

(defun swcad-title-scale-not-ready (command)
  (princ (strcat "\n" command " is reserved for read-only title/scale diagnostics."))
  (princ "\nImplementation plan:")
  (princ "\n  1. Read GMTITLE / ~FTAP title-block scale candidates.")
  (princ "\n  2. Compare entity override DIMLFAC values.")
  (princ "\n  3. Compare source dimension-style DIMLFAC values.")
  (princ "\n  4. Report OK, MIXED, MISSING, CONFLICT, or SUSPECT.")
  (princ "\nNo drawing data was changed.")
  (princ)
)

(defun swcad-title-print-candidate (edata attr / tag value)
  (setq tag (swcad-title-dxf-value attr 2))
  (setq value (swcad-title-dxf-value attr 1))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value edata 5))
      ", layout="
      (swcad-title-string (swcad-title-dxf-value edata 410))
      ", block="
      (swcad-title-string (swcad-title-dxf-value edata 2))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value edata 8))
      ", tag="
      (swcad-title-string tag)
      ", value="
      (swcad-title-string value)
      ", insert="
      (swcad-title-string (swcad-title-dxf-value edata 10))
    )
  )
)

(defun swcad-title-scan-insert (ename / edata attrs attr block found scale-count)
  (setq edata (entget ename '("*")))
  (setq attrs (swcad-title-insert-attributes ename))
  (setq block (swcad-title-dxf-value edata 2))
  (setq found nil)
  (setq scale-count 0)
  (foreach attr attrs
    (if (swcad-title-scale-tag-p (swcad-title-dxf-value attr 2))
      (progn
        (if (not found)
          (progn
            (setq found T)
            (setq *swcad-title-scan-title-insert-count* (+ *swcad-title-scan-title-insert-count* 1))
          )
        )
        (setq scale-count (+ scale-count 1))
        (setq *swcad-title-scan-scale-count* (+ *swcad-title-scan-scale-count* 1))
        (setq
          *swcad-title-scan-scale-values*
          (swcad-title-list-add-unique
            (swcad-title-string (swcad-title-dxf-value attr 1))
            *swcad-title-scan-scale-values*
          )
        )
        (swcad-title-print-candidate edata attr)
      )
    )
  )
  (if (and (swcad-title-title-block-name-p block) (= scale-count 0))
    (swcad-title-princ-line
      (strcat
        "  - handle="
        (swcad-title-string (swcad-title-dxf-value edata 5))
        ", layout="
        (swcad-title-string (swcad-title-dxf-value edata 410))
        ", block="
        (swcad-title-string block)
        ", scale=<missing>"
      )
    )
  )
  scale-count
)

(defun swcad-title-scale-text-to-dimlfac (text / cleaned pos left right numerator denominator value)
  (setq cleaned (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq pos (vl-string-search ":" cleaned))
  (cond
    (pos
      (setq left
        (if (> pos 0)
          (vl-string-trim " \t\r\n" (substr cleaned 1 pos))
          ""
        )
      )
      (setq right (vl-string-trim " \t\r\n" (substr cleaned (+ pos 2))))
      (setq numerator (atof left))
      (setq denominator (atof right))
      (if (and (> numerator 0.0) (> denominator 0.0))
        (/ numerator denominator)
        nil
      )
    )
    (T
      (setq value (atof cleaned))
      (if (> value 0.0) value nil)
    )
  )
)

(defun swcad-title-expected-dimlfac-values (scale-values / result item value)
  (setq result nil)
  (foreach item scale-values
    (setq value (swcad-title-scale-text-to-dimlfac item))
    (if (numberp value)
      (setq result (swcad-title-list-add-unique-float value result))
    )
  )
  result
)

(defun swcad-title-dxf-put (data code value)
  (if (assoc code data)
    (subst (cons code value) (assoc code data) data)
    (append data (list (cons code value)))
  )
)

(defun swcad-title-xdata-apps (data / xd)
  (setq xd (assoc -3 data))
  (if xd (cdr xd) nil)
)

(defun swcad-title-xdata-app-name (app)
  (if (and (listp app) (swcad-title-string-p (car app)))
    (car app)
    nil
  )
)

(defun swcad-title-acad-app (apps / result name)
  (foreach app apps
    (setq name (swcad-title-xdata-app-name app))
    (if (and (not result) name (equal name "ACAD"))
      (setq result app)
    )
  )
  result
)

(defun swcad-title-get-dstyle-overrides (data / apps acad pairs result item code valuepair)
  (setq apps (swcad-title-xdata-apps data))
  (setq acad (swcad-title-acad-app apps))
  (setq pairs (if acad (cdr acad) nil))
  (setq result nil)
  (while pairs
    (setq item (car pairs))
    (if (and (= (car item) 1000) (equal (cdr item) "DSTYLE"))
      (progn
        (setq pairs (cdr pairs))
        (if (and pairs (= (car (car pairs)) 1002) (equal (cdr (car pairs)) "{"))
          (setq pairs (cdr pairs))
        )
        (while (and pairs
                    (not (and (= (car (car pairs)) 1002)
                              (equal (cdr (car pairs)) "}"))))
          (if (and (= (car (car pairs)) 1070) (cdr pairs))
            (progn
              (setq code (cdr (car pairs)))
              (setq valuepair (cadr pairs))
              (setq result (swcad-title-dxf-put result code (cdr valuepair)))
              (setq pairs (cddr pairs))
            )
            (setq pairs (cdr pairs))
          )
        )
      )
    )
    (if pairs (setq pairs (cdr pairs)))
  )
  result
)

(defun swcad-title-dimstyle-or-override-value (data code / style styledata overrides)
  (setq overrides (swcad-title-get-dstyle-overrides data))
  (setq style (swcad-title-safe-string (cdr (assoc 3 data))))
  (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
  (cond
    ((assoc code overrides) (cdr (assoc code overrides)))
    ((and styledata (assoc code styledata)) (cdr (assoc code styledata)))
    (T nil)
  )
)

(defun swcad-title-dim-linear-scale (ename data / object value)
  (setq value (swcad-title-dimstyle-or-override-value data 144))
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    (progn
      (setq object (swcad-title-safe-vla-object ename))
      (setq value (swcad-title-safe-vla-get object 'LinearScaleFactor))
    )
  )
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    1.0
    (float value)
  )
)

(defun c:SWTITLESCAN (/ ss index ename total)
  (swcad-title-open-scan-log)
  (setq *swcad-title-scan-title-insert-count* 0)
  (setq *swcad-title-scan-scale-count* 0)
  (setq *swcad-title-scan-scale-values* nil)
  (swcad-title-princ-line "----- SWTITLESCAN read-only title scale scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa total)))
  (swcad-title-princ-line "Title scale candidates:")
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (swcad-title-scan-insert ename)
    (setq index (+ index 1))
  )
  (if (= *swcad-title-scan-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line
    (strcat "  title inserts with scale: " (itoa *swcad-title-scan-title-insert-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale attributes: " (itoa *swcad-title-scan-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale values: " (swcad-title-string *swcad-title-scan-scale-values*))
  )
  (swcad-title-princ-line
    (strcat
      "Result: "
      (if (> *swcad-title-scan-scale-count* 0)
        "OK_TITLE_SCALE_FOUND"
        "MISSING_TITLE_SCALE"
      )
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun c:SWTITLEDEBUG (/ picked ename)
  (setq ename (swcad-title-first-implied-selection))
  (if ename
    (progn
      (swcad-title-princ-line "Using first preselected object for read-only debug.")
      (swcad-title-debug-entity ename)
    )
    (progn
      (swcad-title-princ-line "Select a GM TITLE / FTAP candidate object for read-only debug.")
      (setq picked (entsel "\nSelect title object: "))
      (if picked
        (progn
          (setq ename (car picked))
          (swcad-title-debug-entity ename)
        )
        (swcad-title-princ-line "Nothing selected.")
      )
    )
  )
  (princ)
)

(defun c:SWSCALESCAN (/ insert-ss insert-index insert-total dim-ss dim-index dim-total ename data overrides style styledata override-value style-value effective-value expected-values effective-counts override-counts style-counts match-count mismatch-count mismatch-example-count match result)
  (swcad-title-open-scale-log)
  (setq *swcad-title-scan-title-insert-count* 0)
  (setq *swcad-title-scan-scale-count* 0)
  (setq *swcad-title-scan-scale-values* nil)
  (setq effective-counts nil)
  (setq override-counts nil)
  (setq style-counts nil)
  (setq match-count 0)
  (setq mismatch-count 0)
  (setq mismatch-example-count 0)
  (swcad-title-princ-line "----- SWSCALESCAN read-only title scale / DIMLFAC scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))

  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa insert-total)))
  (swcad-title-princ-line "Title scale candidates:")
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (swcad-title-scan-insert ename)
    (setq insert-index (+ insert-index 1))
  )
  (if (= *swcad-title-scan-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )

  (setq expected-values (swcad-title-expected-dimlfac-values *swcad-title-scan-scale-values*))
  (swcad-title-princ-line "Title scale summary:")
  (swcad-title-princ-line
    (strcat "  title inserts with scale: " (itoa *swcad-title-scan-title-insert-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale attributes: " (itoa *swcad-title-scan-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  title scale values: " (swcad-title-list-string *swcad-title-scan-scale-values*))
  )
  (swcad-title-princ-line
    (strcat "  expected DIMLFAC values: " (swcad-title-number-list-string expected-values))
  )

  (setq dim-ss (ssget "_X" '((0 . "DIMENSION"))))
  (setq dim-total (if dim-ss (sslength dim-ss) 0))
  (swcad-title-princ-line (strcat "DIMENSION count: " (itoa dim-total)))
  (swcad-title-princ-line "Dimension mismatch examples:")
  (setq dim-index 0)
  (while (< dim-index dim-total)
    (setq ename (ssname dim-ss dim-index))
    (setq data (entget ename '("*")))
    (setq overrides (swcad-title-get-dstyle-overrides data))
    (setq style (swcad-title-safe-string (cdr (assoc 3 data))))
    (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
    (setq override-value (cdr (assoc 144 overrides)))
    (setq style-value (if styledata (cdr (assoc 144 styledata)) nil))
    (setq effective-value (swcad-title-dim-linear-scale ename data))
    (setq effective-counts
      (swcad-title-count-add (swcad-title-number-string effective-value) effective-counts)
    )
    (if (numberp override-value)
      (setq override-counts
        (swcad-title-count-add (swcad-title-number-string override-value) override-counts)
      )
    )
    (setq style-counts
      (swcad-title-count-add
        (strcat
          (if style style "<no style>")
          " DIMLFAC="
          (if (numberp style-value) (swcad-title-number-string style-value) "<missing>")
        )
        style-counts
      )
    )
    (setq match (swcad-title-float-in-list-p effective-value expected-values))
    (if match
      (setq match-count (+ match-count 1))
      (progn
        (setq mismatch-count (+ mismatch-count 1))
        (if (< mismatch-example-count 12)
          (progn
            (setq mismatch-example-count (+ mismatch-example-count 1))
            (swcad-title-princ-line
              (strcat
                "  - handle="
                (swcad-title-string (cdr (assoc 5 data)))
                ", layout="
                (swcad-title-string (cdr (assoc 410 data)))
                ", style="
                (if style style "<no style>")
                ", override="
                (if (numberp override-value) (swcad-title-number-string override-value) "<none>")
                ", style DIMLFAC="
                (if (numberp style-value) (swcad-title-number-string style-value) "<missing>")
                ", effective="
                (swcad-title-number-string effective-value)
              )
            )
          )
        )
      )
    )
    (setq dim-index (+ dim-index 1))
  )
  (if (= mismatch-example-count 0)
    (swcad-title-princ-line "  <none>")
  )

  (swcad-title-print-counts "Effective DIMLFAC values:" effective-counts)
  (swcad-title-print-counts "Override DIMLFAC values:" override-counts)
  (swcad-title-print-counts "Style DIMLFAC values:" style-counts)
  (swcad-title-princ-line "Comparison summary:")
  (swcad-title-princ-line (strcat "  matching dimensions: " (itoa match-count)))
  (swcad-title-princ-line (strcat "  mismatching dimensions: " (itoa mismatch-count)))
  (setq result
    (cond
      ((= (length expected-values) 0) "MISSING_TITLE_SCALE")
      ((= dim-total 0) "NO_DIMENSIONS")
      ((= mismatch-count 0) "OK_DIMLFAC_MATCH")
      ((> match-count 0) "MIXED_DIMLFAC")
      (T "CONFLICT_DIMLFAC")
    )
  )
  (swcad-title-princ-line (strcat "Result: " result))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(princ (strcat "\nswcad_title_scale.lsp ready " *swcad-title-scale-version*))
(princ "\nCommands: SWTITLEDEBUG, SWTITLESCAN, SWSCALESCAN")
(princ)
