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

(defun swcad-title-princ-line (text)
  (princ (strcat "\n" text))
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
  (setq next (entnext ename))
  (if (not next)
    (swcad-title-princ-line "  No following entities.")
  )
  (while next
    (setq edata (entget next '("*")))
    (setq etype (swcad-title-dxf-value edata 0))
    (cond
      ((= etype "ATTRIB")
        (setq count (+ count 1))
        (swcad-title-princ-line "  ATTRIBUTE")
        (swcad-title-princ-line (strcat "    tag: " (swcad-title-string (swcad-title-dxf-value edata 2))))
        (swcad-title-princ-line (strcat "    value: " (swcad-title-string (swcad-title-dxf-value edata 1))))
        (swcad-title-princ-line (strcat "    layer: " (swcad-title-string (swcad-title-dxf-value edata 8))))
        (swcad-title-princ-line (strcat "    handle: " (swcad-title-string (swcad-title-dxf-value edata 5))))
      )
      ((= etype "SEQEND")
        (setq next nil)
      )
    )
    (if next
      (setq next (entnext next))
    )
  )
  (if (= count 0)
    (swcad-title-princ-line "  No attributes found.")
  )
)

(defun swcad-title-debug-entity (ename / data etype)
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
  (princ)
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

(defun c:SWTITLEDEBUG (/ picked ename)
  (swcad-title-princ-line "Select a GM TITLE / FTAP candidate object for read-only debug.")
  (setq picked (entsel "\nSelect title object: "))
  (if picked
    (progn
      (setq ename (car picked))
      (swcad-title-debug-entity ename)
    )
    (swcad-title-princ-line "Nothing selected.")
  )
  (princ)
)

(defun c:SWTITLESCAN ()
  (swcad-title-scale-not-ready "SWTITLESCAN")
)

(defun c:SWSCALESCAN ()
  (swcad-title-scale-not-ready "SWSCALESCAN")
)

(princ (strcat "\nswcad_title_scale.lsp ready " *swcad-title-scale-version*))
(princ "\nCommands: SWTITLEDEBUG, SWTITLESCAN, SWSCALESCAN")
(princ)
