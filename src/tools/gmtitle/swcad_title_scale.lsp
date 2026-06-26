;;; Read-only title-block and scale diagnostic module.
;;;
;;; Standalone test workflow:
;;;   APPLOAD this file directly, then run SWTITLEDEBUG.
;;;
;;; SWTITLEDEBUG prints raw information from a selected GM TITLE / FTAP
;;; candidate object. It does not modify the drawing.

(vl-load-com)

(setq *swcad-title-scale-version* "260626-1438")
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

(defun c:SWSCALESCAN ()
  (swcad-title-scale-not-ready "SWSCALESCAN")
)

(princ (strcat "\nswcad_title_scale.lsp ready " *swcad-title-scale-version*))
(princ "\nCommands: SWTITLEDEBUG, SWTITLESCAN, SWSCALESCAN")
(princ)
