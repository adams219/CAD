;;; Read-only title-block and scale diagnostic module.
;;;
;;; Standalone test workflow:
;;;   APPLOAD this file directly, then run SWTITLEDEBUG, SWTITLESCAN,
;;;   SWTITLETEXTSCAN, SWTITLETRANSFERPREVIEW, SWTITLETRANSFERAPPLY,
;;;   SWTITLETRANSFERBATCH, or SWSCALESCAN.
;;;
;;; SWTITLEDEBUG prints raw information from a selected GM TITLE / FTAP
;;; candidate object. It does not modify the drawing.
;;; SWTITLETEXTSCAN lists title-block attributes and loose TEXT/MTEXT
;;; found in title-block bounds. It does not modify the drawing.
;;; SWTITLETRANSFERPREVIEW maps loose title-block text to GM TITLE
;;; attribute tags. It does not modify the drawing.
;;; SWTITLETRANSFERAPPLY extracts old loose/block title text, runs native
;;; GMTITLE for the user to place a real DR frame/title, fills its
;;; attributes, then removes the selected old SOLIDWORKS title content.
;;; SWSCALESCAN compares title-block scale candidates with dimension
;;; DIMLFAC values. It does not modify the drawing.

(vl-load-com)

(setq *swcad-title-scale-version* "260629-native-batch")
(setq *swcad-title-scale-loaded* T)
(setq *swcad-title-debug-log-path* nil)
(setq *swcad-title-debug-log-handle* nil)
(setq *swcad-title-batch-mode* nil)
(setq *swcad-title-last-apply-status* nil)
(setq *swcad-title-target-frame-block-name* "DR_A3_Outline")
(setq *swcad-title-target-title-block-name* "DR_titlea_3rd")

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

(defun swcad-title-work-root-path (/ home)
  (setq home (getenv "USERPROFILE"))
  (if home
    (strcat
      (vl-string-translate "\\" "/" home)
      "/Documents/CAD tool/work/"
    )
    ""
  )
)

(defun swcad-title-current-dwg-full-path ()
  (vl-string-translate "\\" "/" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME")))
)

(defun swcad-title-string-prefix-p (prefix value)
  (and
    prefix
    value
    (<= (strlen prefix) (strlen value))
    (equal
      (strcase prefix)
      (strcase (substr value 1 (strlen prefix)))
    )
  )
)

(defun swcad-title-current-dwg-in-work-p ()
  (swcad-title-string-prefix-p
    (swcad-title-work-root-path)
    (swcad-title-current-dwg-full-path)
  )
)

(defun swcad-title-print-work-copy-status ()
  (swcad-title-princ-line
    (strcat
      "Work-folder test copy: "
      (if (swcad-title-current-dwg-in-work-p) "yes" "no")
    )
  )
)

(defun swcad-title-apply-work-copy-confirmed-p (/ answer)
  (if (swcad-title-current-dwg-in-work-p)
    T
    (progn
      (swcad-title-princ-line "WARNING: current DWG is outside the work test folder.")
      (swcad-title-princ-line "No SOLIDWORKS title/frame content will be removed unless you explicitly confirm this non-work file.")
      (setq answer
        (getstring
          T
          "\nCurrent DWG is outside work. Type EDIT to continue, or press Enter to abort: "
        )
      )
      (equal (strcase answer) "EDIT")
    )
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

(defun swcad-title-open-text-log ()
  (swcad-title-open-log "swcad_title_text_scan_last.txt" "SWTITLETEXTSCAN log")
)

(defun swcad-title-open-transfer-log ()
  (swcad-title-open-log "swcad_title_transfer_preview_last.txt" "SWTITLETRANSFERPREVIEW log")
)

(defun swcad-title-open-apply-log ()
  (swcad-title-open-log "swcad_title_transfer_apply_last.txt" "SWTITLETRANSFERAPPLY log")
)

(defun swcad-title-apply-result (status)
  (setq *swcad-title-last-apply-status* status)
  (swcad-title-princ-line (strcat "Result: " status))
)

(defun swcad-title-open-gmtitle-verify-log ()
  (swcad-title-open-log "swcad_title_gmtitle_verify_last.txt" "SWTITLEGMTITLEVERIFY log")
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

(defun swcad-title-point-string (point)
  (if (and (listp point) (>= (length point) 2))
    (strcat
      "("
      (swcad-title-number-string (car point))
      ", "
      (swcad-title-number-string (cadr point))
      (if (caddr point)
        (strcat ", " (swcad-title-number-string (caddr point)))
        ""
      )
      ")"
    )
    (swcad-title-string point)
  )
)

(defun swcad-title-bbox-string (bbox)
  (if (and (listp bbox) (= (length bbox) 4))
    (strcat
      "("
      (swcad-title-number-string (car bbox))
      ", "
      (swcad-title-number-string (cadr bbox))
      ") - ("
      (swcad-title-number-string (caddr bbox))
      ", "
      (swcad-title-number-string (cadddr bbox))
      ")"
    )
    "<none>"
  )
)

(defun swcad-title-safe-bbox (ename / object result minpt maxpt minlist maxlist)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (progn
      (setq result (vl-catch-all-apply 'vla-GetBoundingBox (list object 'minpt 'maxpt)))
      (if (vl-catch-all-error-p result)
        nil
        (progn
          (setq minlist (vlax-safearray->list minpt))
          (setq maxlist (vlax-safearray->list maxpt))
          (list (car minlist) (cadr minlist) (car maxlist) (cadr maxlist))
        )
      )
    )
    nil
  )
)

(defun swcad-title-expand-bbox (bbox margin)
  (if bbox
    (list
      (- (car bbox) margin)
      (- (cadr bbox) margin)
      (+ (caddr bbox) margin)
      (+ (cadddr bbox) margin)
    )
    nil
  )
)

(defun swcad-title-point-in-bbox-p (point bbox)
  (and
    point
    bbox
    (>= (car point) (car bbox))
    (<= (car point) (caddr bbox))
    (>= (cadr point) (cadr bbox))
    (<= (cadr point) (cadddr bbox))
  )
)

(defun swcad-title-point-in-bboxes-p (point bboxes / found bbox)
  (setq found nil)
  (foreach bbox bboxes
    (if (swcad-title-point-in-bbox-p point bbox)
      (setq found T)
    )
  )
  found
)

(defun swcad-title-bbox-area (bbox)
  (if bbox
    (* (- (caddr bbox) (car bbox)) (- (cadddr bbox) (cadr bbox)))
    0.0
  )
)

(defun swcad-title-bbox-width (bbox)
  (if bbox
    (- (caddr bbox) (car bbox))
    0.0
  )
)

(defun swcad-title-bbox-height (bbox)
  (if bbox
    (- (cadddr bbox) (cadr bbox))
    0.0
  )
)

(defun swcad-title-abs (value)
  (if (< value 0.0)
    (- 0.0 value)
    value
  )
)

(defun swcad-title-near-p (a b tolerance)
  (<= (swcad-title-abs (- (float a) (float b))) tolerance)
)

(defun swcad-title-bbox-intersects-p (a b)
  (and
    a
    b
    (<= (car a) (caddr b))
    (>= (caddr a) (car b))
    (<= (cadr a) (cadddr b))
    (>= (cadddr a) (cadr b))
  )
)

(defun swcad-title-bbox-contains-bbox-p (outer inner margin)
  (and
    outer
    inner
    (<= (- (car outer) margin) (car inner))
    (<= (- (cadr outer) margin) (cadr inner))
    (>= (+ (caddr outer) margin) (caddr inner))
    (>= (+ (cadddr outer) margin) (cadddr inner))
  )
)

(setq *swcad-title-transfer-template*
  '(
    ("GEN-TITLE-QTY{10}" 25.75 37.50 "quantity")
    ("GEN-TITLE-MAT1{10}" 32.81333128 37.60265511 "material")
    ("GEN-TITLE-NAME{10}" 6.00361982 21.70382822 "name")
    ("GEN-TITLE-CHKM{10}" 35.81333128 21.60265511 "checked")
    ("GEN-TITLE-APPM{21.7}" 64.86238219 21.70382822 "approved")
    ("GEN-TITLE-DATE{11.7}" 93.48807325 21.53210663 "date")
    ("GEN-TITLE-SCA{6.7}" 163.48807325 21.53210663 "scale")
    ("GEN-TITLE-DWG{23}" 56.00 12.50 "drawing")
    ("GEN-TITLE-NR{23}" 56.00 2.70 "drawing-number")
    ("GEN-TITLE-REV{5}" 148.48807325 1.53210663 "revision")
    ("GEN-TITLE-SIZ{6.7}" 163.48807325 1.53210663 "sheet-size")
  )
)

(defun swcad-title-distance2 (x1 y1 x2 y2 / dx dy)
  (setq dx (- x1 x2))
  (setq dy (- y1 y2))
  (+ (* dx dx) (* dy dy))
)

(defun swcad-title-transfer-best-slot (point bbox / relx rely best bestdist dist slot)
  (setq best nil)
  (setq bestdist nil)
  (if (and point bbox)
    (progn
      (setq relx (- (car point) (car bbox)))
      (setq rely (- (cadr point) (cadr bbox)))
      (foreach slot *swcad-title-transfer-template*
        (setq dist (swcad-title-distance2 relx rely (cadr slot) (caddr slot)))
        (if (or (not bestdist) (< dist bestdist))
          (progn
            (setq best slot)
            (setq bestdist dist)
          )
        )
      )
      (if best
        (list best (sqrt bestdist) relx rely)
        nil
      )
    )
    nil
  )
)

(defun swcad-title-assoc-put (key value alist / result found pair)
  (setq result nil)
  (setq found nil)
  (foreach pair alist
    (if (equal key (car pair))
      (progn
        (setq result (append result (list (cons key value))))
        (setq found T)
      )
      (setq result (append result (list pair)))
    )
  )
  (if found
    result
    (append result (list (cons key value)))
  )
)

(defun swcad-title-doc ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun swcad-title-modelspace ()
  (vla-get-ModelSpace (swcad-title-doc))
)

(defun swcad-title-document-read-only-p (/ doc value)
  (setq doc (swcad-title-doc))
  (setq value (swcad-title-safe-vla-get doc 'ReadOnly))
  (cond
    ((not value) nil)
    ((equal value :vlax-false) nil)
    ((equal value 0) nil)
    (T T)
  )
)

(defun swcad-title-block-exists-p (block-name)
  (if (tblsearch "BLOCK" block-name) T nil)
)

(defun swcad-title-find-block-by-pattern (pattern / item name upper result)
  (setq result nil)
  (setq item (tblnext "BLOCK" T))
  (while (and item (not result))
    (setq name (cdr (assoc 2 item)))
    (setq upper (strcase (swcad-title-string name)))
    (if (and
          name
          (/= (substr name 1 1) "*")
          (wcmatch upper pattern)
        )
      (setq result name)
    )
    (setq item (tblnext "BLOCK"))
  )
  result
)

(defun swcad-title-target-frame-block-name ()
  *swcad-title-target-frame-block-name*
)

(defun swcad-title-target-title-block-name ()
  *swcad-title-target-title-block-name*
)

(defun swcad-title-vla-block-name (object / name)
  (setq name (swcad-title-safe-vla-get object 'EffectiveName))
  (if (not name)
    (setq name (swcad-title-safe-vla-get object 'Name))
  )
  (swcad-title-string name)
)

(defun swcad-title-attribute-tag (attribute / value)
  (setq value (vl-catch-all-apply 'vla-get-TagString (list attribute)))
  (if (vl-catch-all-error-p value) "" value)
)

(defun swcad-title-attribute-set-value (attribute value)
  (vl-catch-all-apply 'vla-put-TextString (list attribute (swcad-title-string value)))
)

(defun swcad-title-get-insert-attributes (insert-object / result)
  (setq result (vl-catch-all-apply 'vlax-invoke (list insert-object 'GetAttributes)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swcad-title-set-insert-attributes (insert-object values / attrs attr tag pair count)
  (setq attrs (swcad-title-get-insert-attributes insert-object))
  (setq count 0)
  (foreach attr attrs
    (setq tag (swcad-title-attribute-tag attr))
    (setq pair (assoc tag values))
    (if pair
      (progn
        (swcad-title-attribute-set-value attr (cdr pair))
        (setq count (+ count 1))
      )
    )
  )
  (vl-catch-all-apply 'vla-Update (list insert-object))
  count
)

(defun swcad-title-delete-ename (ename)
  (if ename
    (entdel ename)
  )
)

(defun swcad-title-delete-vla-object (object)
  (if object
    (vl-catch-all-apply 'vla-Delete (list object))
  )
)

(defun swcad-title-internal-gentitle-marker-entity-p (ename / data type text)
  (setq data (entget ename))
  (setq type (strcase (swcad-title-string (cdr (assoc 0 data)))))
  (and
    (member type '("TEXT" "MTEXT"))
    (progn
      (setq text
        (strcase
          (vl-string-trim
            " \t\r\n"
            (swcad-title-string (cdr (assoc 1 data)))
          )
        )
      )
      T
    )
    (wcmatch text "!GENTITLE-*")
  )
)

(defun swcad-title-internal-frame-marker-enames (block-name / block ename data targets guard)
  (setq block (tblobjname "BLOCK" block-name))
  (setq targets nil)
  (if block
    (progn
      (setq ename (entnext block))
      (setq guard 0)
      (while (and ename (< guard 1000))
        (setq data (entget ename))
        (if (= (strcase (swcad-title-string (cdr (assoc 0 data)))) "ENDBLK")
          (setq ename nil)
          (progn
            (if (swcad-title-internal-gentitle-marker-entity-p ename)
              (setq targets (cons ename targets))
            )
            (setq ename (entnext ename))
          )
        )
        (setq guard (+ guard 1))
      )
    )
  )
  (reverse targets)
)

(defun swcad-title-delete-internal-frame-marker-texts (block-name / targets ename result count)
  (setq targets (swcad-title-internal-frame-marker-enames block-name))
  (setq count 0)
  (foreach ename targets
    (setq result (entdel ename))
    (if result
      (setq count (+ count 1))
    )
  )
  (if (> count 0)
    (progn
      (entupd (tblobjname "BLOCK" block-name))
      (vl-catch-all-apply 'vla-Regen (list (swcad-title-doc) 1))
    )
  )
  count
)

(defun swcad-title-delete-handle (handle / ename)
  (setq ename (handent (swcad-title-string handle)))
  (swcad-title-delete-ename ename)
)

(defun swcad-title-block-text-record-p (record / handle)
  (setq handle (strcase (swcad-title-string (nth 3 record))))
  (wcmatch handle "BLOCK:*")
)

(defun swcad-title-delete-text-record (record)
  (if (swcad-title-block-text-record-p record)
    nil
    (progn
      (swcad-title-delete-handle (nth 3 record))
      T
    )
  )
)

(defun swcad-title-delete-handle-list (handles / handle count)
  (setq count 0)
  (foreach handle handles
    (if (swcad-title-delete-handle handle)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-delete-ename-list (enames / ename count)
  (setq count 0)
  (foreach ename enames
    (if (swcad-title-delete-ename ename)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-frame-cleanup-entity-type-p (etype)
  (member
    (strcase (swcad-title-string etype))
    '("LINE" "LWPOLYLINE" "POLYLINE" "2DPOLYLINE" "HATCH" "SOLID" "TRACE" "WIPEOUT")
  )
)

(defun swcad-title-sheet-size-value (values / pair)
  (setq pair (assoc "GEN-TITLE-SIZ{6.7}" values))
  (if pair
    (vl-string-trim " \t\r\n" (strcase (swcad-title-string (cdr pair))))
    ""
  )
)

(defun swcad-title-sheet-dimensions (sheet-size / value)
  (setq value (strcase (swcad-title-string sheet-size)))
  (cond
    ((wcmatch value "*A0*") '(1189.0 841.0))
    ((wcmatch value "*A1*") '(841.0 594.0))
    ((wcmatch value "*A2*") '(594.0 420.0))
    ((wcmatch value "*A3*") '(420.0 297.0))
    ((wcmatch value "*A4*") '(210.0 297.0))
    (T nil)
  )
)

(defun swcad-title-inferred-source-frame-bbox (source-bbox values / dims width height frame-max-x frame-min-y)
  (setq dims (swcad-title-sheet-dimensions (swcad-title-sheet-size-value values)))
  (if (and source-bbox dims)
    (progn
      (setq width (car dims))
      (setq height (cadr dims))
      (setq frame-max-x (+ (caddr source-bbox) 10.0))
      (setq frame-min-y (- (cadr source-bbox) 10.0))
      (list
        (- frame-max-x width)
        frame-min-y
        frame-max-x
        (+ frame-min-y height)
      )
    )
    nil
  )
)

(defun swcad-title-source-title-graphic-handles (source-bbox / ss index total ename data etype bbox handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq etype (swcad-title-dxf-value data 0))
    (setq bbox (swcad-title-safe-bbox ename))
    (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
    (if
      (and
        (> (strlen handle) 0)
        (swcad-title-frame-cleanup-entity-type-p etype)
        (swcad-title-bbox-intersects-p bbox (swcad-title-expand-bbox source-bbox 1.0))
      )
      (setq result (swcad-title-list-add-unique handle result))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-frame-edge-graphic-p (bbox frame-bbox / tolerance frame-width frame-height width height near-left near-right near-bottom near-top full-box long-horizontal long-vertical)
  (if (and bbox frame-bbox)
    (progn
      (setq tolerance 2.5)
      (setq frame-width (swcad-title-bbox-width frame-bbox))
      (setq frame-height (swcad-title-bbox-height frame-bbox))
      (setq width (swcad-title-bbox-width bbox))
      (setq height (swcad-title-bbox-height bbox))
      (setq near-left (and (swcad-title-near-p (car bbox) (car frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (car frame-bbox) tolerance)))
      (setq near-right (and (swcad-title-near-p (car bbox) (caddr frame-bbox) tolerance) (swcad-title-near-p (caddr bbox) (caddr frame-bbox) tolerance)))
      (setq near-bottom (and (swcad-title-near-p (cadr bbox) (cadr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadr frame-bbox) tolerance)))
      (setq near-top (and (swcad-title-near-p (cadr bbox) (cadddr frame-bbox) tolerance) (swcad-title-near-p (cadddr bbox) (cadddr frame-bbox) tolerance)))
      (setq full-box
        (and
          (swcad-title-near-p (car bbox) (car frame-bbox) tolerance)
          (swcad-title-near-p (cadr bbox) (cadr frame-bbox) tolerance)
          (swcad-title-near-p (caddr bbox) (caddr frame-bbox) tolerance)
          (swcad-title-near-p (cadddr bbox) (cadddr frame-bbox) tolerance)
        )
      )
      (setq long-horizontal (>= width (* frame-width 0.25)))
      (setq long-vertical (>= height (* frame-height 0.25)))
      (and
        (swcad-title-bbox-contains-bbox-p (swcad-title-expand-bbox frame-bbox tolerance) bbox 0.0)
        (or
          full-box
          (and long-horizontal (or near-bottom near-top))
          (and long-vertical (or near-left near-right))
        )
      )
    )
    nil
  )
)

(defun swcad-title-source-frame-graphic-handles (frame-bbox source-bbox / ss index total ename data etype bbox handle result)
  (setq result nil)
  (if frame-bbox
    (progn
      (setq ss (ssget "_X" '((0 . "LINE,LWPOLYLINE,POLYLINE,2DPOLYLINE,HATCH,SOLID,TRACE,WIPEOUT"))))
      (setq total (if ss (sslength ss) 0))
      (setq index 0)
      (while (< index total)
        (setq ename (ssname ss index))
        (setq data (entget ename '("*")))
        (setq etype (swcad-title-dxf-value data 0))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq handle (swcad-title-string (swcad-title-dxf-value data 5)))
        (if
          (and
            (> (strlen handle) 0)
            (swcad-title-frame-cleanup-entity-type-p etype)
            (not (swcad-title-bbox-intersects-p bbox (swcad-title-expand-bbox source-bbox 1.0)))
            (swcad-title-frame-edge-graphic-p bbox frame-bbox)
          )
          (setq result (swcad-title-list-add-unique handle result))
        )
        (setq index (+ index 1))
      )
    )
  )
  result
)

(defun swcad-title-transfer-values (mappings / result pair preview)
  (setq result nil)
  (foreach pair mappings
    (setq preview (cdr pair))
    (setq result
      (swcad-title-assoc-put
        (car pair)
        (nth 2 preview)
        result
      )
    )
  )
  result
)

(defun swcad-title-transfer-build-mappings (source-bbox source-ename maxdist / records mappings unmapped duplicates record preview tag existing duplicate-count unmapped-count mapped-count)
  (setq records (swcad-title-transfer-text-records source-bbox source-ename))
  (setq mappings nil)
  (setq unmapped nil)
  (setq duplicates nil)
  (setq mapped-count 0)
  (setq duplicate-count 0)
  (setq unmapped-count 0)
  (foreach record records
    (setq preview (swcad-title-transfer-preview-record record source-bbox))
    (if (and preview (<= (nth 5 preview) maxdist))
      (progn
        (setq tag (car preview))
        (setq existing (assoc tag mappings))
        (if existing
          (progn
            (setq duplicates (append duplicates (list record)))
            (setq duplicate-count (+ duplicate-count 1))
          )
          (progn
            (setq mappings (swcad-title-assoc-put tag preview mappings))
            (setq mapped-count (+ mapped-count 1))
          )
        )
      )
      (progn
        (setq unmapped (append unmapped (list record)))
        (setq unmapped-count (+ unmapped-count 1))
      )
    )
  )
  (list mappings records unmapped duplicates mapped-count unmapped-count duplicate-count)
)

(defun swcad-title-char-code (text)
  (if (and text (> (strlen text) 0))
    (ascii text)
    0
  )
)

(defun swcad-title-digit-or-dot-p (text / code)
  (setq code (swcad-title-char-code text))
  (or
    (and (>= code 48) (<= code 57))
    (= text ".")
  )
)

(defun swcad-title-space-p (text / code)
  (setq code (swcad-title-char-code text))
  (or (= code 9) (= code 10) (= code 13) (= code 32))
)

(defun swcad-title-scale-only-text-p (text / index len ch ok)
  (setq index 1)
  (setq len (strlen text))
  (setq ok (> len 0))
  (while (and ok (<= index len))
    (setq ch (substr text index 1))
    (if (not (or (swcad-title-digit-or-dot-p ch) (swcad-title-space-p ch) (= ch ":")))
      (setq ok nil)
    )
    (setq index (+ index 1))
  )
  ok
)

(defun swcad-title-extract-ratio-text (text / raw len colon left-end left-start right-start right-end left right)
  (setq raw (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq len (strlen raw))
  (setq colon (vl-string-search ":" raw))
  (setq left nil)
  (setq right nil)
  (if colon
    (progn
      (setq left-end colon)
      (while (and (> left-end 0) (swcad-title-space-p (substr raw left-end 1)))
        (setq left-end (- left-end 1))
      )
      (setq left-start left-end)
      (while (and (> left-start 0) (swcad-title-digit-or-dot-p (substr raw left-start 1)))
        (setq left-start (- left-start 1))
      )
      (if (> left-end left-start)
        (setq left (substr raw (+ left-start 1) (- left-end left-start)))
      )

      (setq right-start (+ colon 2))
      (while (and (<= right-start len) (swcad-title-space-p (substr raw right-start 1)))
        (setq right-start (+ right-start 1))
      )
      (setq right-end right-start)
      (while (and (<= right-end len) (swcad-title-digit-or-dot-p (substr raw right-end 1)))
        (setq right-end (+ right-end 1))
      )
      (if (> right-end right-start)
        (setq right (substr raw right-start (- right-end right-start)))
      )
    )
  )
  (if (and left right (> (atof left) 0.0) (> (atof right) 0.0))
    (strcat left ":" right)
    nil
  )
)

(defun swcad-title-scale-text-candidate (text / cleaned upper ratio)
  (setq cleaned (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq upper (strcase cleaned))
  (setq ratio (swcad-title-extract-ratio-text cleaned))
  (if (and
        ratio
        (or
          (swcad-title-scale-only-text-p cleaned)
          (vl-string-search "SCALE" upper)
          (vl-string-search "SCA" upper)
          (<= (strlen cleaned) 16)
        )
      )
    ratio
    nil
  )
)

(defun swcad-title-insert-attributes (ename / data next edata etype result)
  (setq result nil)
  (setq data (entget ename))
  (if (= (swcad-title-dxf-value data 66) 1)
    (progn
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
          ((not (= etype "ATTRIB"))
            (setq next nil)
          )
        )
        (if next
          (setq next (entnext next))
        )
      )
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

(defun swcad-title-native-target-title-name-p (name)
  (equal
    (strcase (swcad-title-string name))
    (strcase (swcad-title-target-title-block-name))
  )
)

(defun swcad-title-native-target-frame-name-p (name)
  (equal
    (strcase (swcad-title-string name))
    (strcase (swcad-title-target-frame-block-name))
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

(defun swcad-title-block-definition-object (block-name / blocks result)
  (if (and block-name (swcad-title-block-exists-p block-name))
    (progn
      (setq blocks (vla-get-Blocks (swcad-title-doc)))
      (setq result (vl-catch-all-apply 'vla-Item (list blocks block-name)))
      (if (vl-catch-all-error-p result)
        nil
        result
      )
    )
    nil
  )
)

(defun swcad-title-block-definition-count (block-name / block count item)
  (setq block (swcad-title-block-definition-object block-name))
  (if block
    (progn
      (setq count 0)
      (vlax-for item block
        (setq count (+ count 1))
      )
      count
    )
    nil
  )
)

(defun swcad-title-effective-insert-name (ename / object name)
  (setq object (swcad-title-safe-vla-object ename))
  (if object
    (setq name (swcad-title-vla-block-name object))
    (setq name (swcad-title-dxf-value (entget ename '("*")) 2))
  )
  (swcad-title-string name)
)

(defun swcad-title-find-insert-by-effective-name (block-name / target ss index total ename found)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq found nil)
  (while (and (< index total) (not found))
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq found ename)
    )
    (setq index (+ index 1))
  )
  found
)

(defun swcad-title-count-inserts-by-effective-name (block-name / target ss index total ename count)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq count 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq count (+ count 1))
    )
    (setq index (+ index 1))
  )
  count
)

(defun swcad-title-inserts-by-effective-name (block-name / target ss index total ename result)
  (setq target (strcase (swcad-title-string block-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq result nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (if (equal (strcase (swcad-title-effective-insert-name ename)) target)
      (setq result (append result (list ename)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-attribute-value (attribute / value)
  (setq value (vl-catch-all-apply 'vla-get-TextString (list attribute)))
  (if (vl-catch-all-error-p value) "" value)
)

(defun swcad-title-title-attribute-pairs (insert-object / attrs attr result)
  (setq attrs (swcad-title-get-insert-attributes insert-object))
  (setq result nil)
  (foreach attr attrs
    (setq result
      (append
        result
        (list
          (cons
            (swcad-title-attribute-tag attr)
            (swcad-title-attribute-value attr)
          )
        )
      )
    )
  )
  result
)

(defun swcad-title-missing-template-tags (attr-pairs / missing slot tag)
  (setq missing nil)
  (foreach slot *swcad-title-transfer-template*
    (setq tag (car slot))
    (if (not (assoc tag attr-pairs))
      (setq missing (append missing (list tag)))
    )
  )
  missing
)

(defun swcad-title-nonempty-attribute-count (attr-pairs / count pair value)
  (setq count 0)
  (foreach pair attr-pairs
    (setq value (vl-string-trim " \t\r\n" (swcad-title-string (cdr pair))))
    (if (> (strlen value) 0)
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-xdata-records (ename / data result pair item)
  (setq data (entget ename '("*")))
  (setq result nil)
  (foreach pair data
    (if (and (listp pair) (= (car pair) -3))
      (foreach item (cdr pair)
        (if (listp item)
          (setq result (append result (list item)))
        )
      )
    )
  )
  result
)

(defun swcad-title-xdata-record-app-name (record)
  (if (and (listp record) (= (type (car record)) 'STR))
    (car record)
    ""
  )
)

(defun swcad-title-xdata-handle-values (record / result pair value)
  (setq result nil)
  (foreach pair (cdr record)
    (if (and (listp pair) (member (car pair) '(1000 1005)))
      (progn
        (setq value (swcad-title-string (cdr pair)))
        (if (and (> (strlen value) 0) (handent value))
          (setq result (append result (list value)))
        )
      )
    )
  )
  result
)

(defun swcad-title-gmtitle-native-xdata-info (title-ename / records record app handles found-handles)
  (setq records (swcad-title-xdata-records title-ename))
  (setq found-handles nil)
  (foreach record records
    (setq app (strcase (swcad-title-xdata-record-app-name record)))
    (if (equal app "GENIUS_GENOREF_13")
      (progn
        (setq handles (swcad-title-xdata-handle-values record))
        (foreach handle handles
          (if (not (member handle found-handles))
            (setq found-handles (append found-handles (list handle)))
          )
        )
      )
    )
  )
  found-handles
)

(defun swcad-title-other-title-like-inserts (target-name / target ss index total ename name data result)
  (setq target (strcase (swcad-title-string target-name)))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (setq result nil)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq name (swcad-title-effective-insert-name ename))
    (if
      (and
        (/= (strcase (swcad-title-string name)) target)
        (swcad-title-title-block-name-p name)
      )
      (progn
        (setq data (entget ename '("*")))
        (setq result
          (append
            result
            (list
              (list
                (swcad-title-string (swcad-title-dxf-value data 5))
                name
                (swcad-title-safe-bbox ename)
              )
            )
          )
        )
      )
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-print-attribute-pairs (attr-pairs / pair)
  (foreach pair attr-pairs
    (swcad-title-princ-line
      (strcat
        "  "
        (car pair)
        " = \""
        (swcad-title-string (cdr pair))
        "\""
      )
    )
  )
)

(defun swcad-title-print-string-list (label values / value)
  (swcad-title-princ-line label)
  (if values
    (foreach value values
      (swcad-title-princ-line (strcat "  - " (swcad-title-string value)))
    )
    (swcad-title-princ-line "  <none>")
  )
)

(defun swcad-title-gmtitle-verify (/ frame-name title-name frame-count title-enames title-count title-index title-ename title-data title-object title-bbox attr-pairs missing-tags nonempty-attrs native-handles other-title-inserts filedia cmddia status record any-missing-tags any-empty-attrs any-missing-native-xdata)
  (swcad-title-open-gmtitle-verify-log)
  (setq frame-name (swcad-title-target-frame-block-name))
  (setq title-name (swcad-title-target-title-block-name))
  (setq frame-count (swcad-title-count-inserts-by-effective-name frame-name))
  (setq title-enames (swcad-title-inserts-by-effective-name title-name))
  (setq title-count (length title-enames))
  (setq other-title-inserts (swcad-title-other-title-like-inserts title-name))
  (setq filedia (getvar "FILEDIA"))
  (setq cmddia (getvar "CMDDIA"))
  (setq any-missing-tags nil)
  (setq any-empty-attrs nil)
  (setq any-missing-native-xdata nil)
  (swcad-title-princ-line "----- SWTITLEGMTITLEVERIFY read-only GMTITLE transfer verification -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA: " (swcad-title-string filedia) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA: " (swcad-title-string cmddia) " (not changed)"))
  (swcad-title-princ-line (strcat "Target frame block: " frame-name ", inserts=" (itoa frame-count)))
  (swcad-title-princ-line (strcat "Target title block: " title-name ", inserts=" (itoa title-count)))
  (if title-enames
    (progn
      (setq title-index 1)
      (foreach title-ename title-enames
        (setq title-data (entget title-ename '("*")))
        (setq title-object (swcad-title-safe-vla-object title-ename))
        (setq title-bbox (swcad-title-safe-bbox title-ename))
        (setq attr-pairs (if title-object (swcad-title-title-attribute-pairs title-object) nil))
        (setq missing-tags (swcad-title-missing-template-tags attr-pairs))
        (setq nonempty-attrs (swcad-title-nonempty-attribute-count attr-pairs))
        (setq native-handles (swcad-title-gmtitle-native-xdata-info title-ename))
        (if missing-tags
          (setq any-missing-tags T)
        )
        (if (= nonempty-attrs 0)
          (setq any-empty-attrs T)
        )
        (if (not native-handles)
          (setq any-missing-native-xdata T)
        )
        (swcad-title-princ-line
          (strcat
            "Title insert #"
            (itoa title-index)
            ": handle="
            (swcad-title-string (swcad-title-dxf-value title-data 5))
            ", bbox="
            (swcad-title-bbox-string title-bbox)
          )
        )
        (swcad-title-princ-line (strcat "Title attributes: " (itoa (length attr-pairs))))
        (swcad-title-print-attribute-pairs attr-pairs)
        (swcad-title-princ-line (strcat "Non-empty title attributes: " (itoa nonempty-attrs)))
        (swcad-title-print-string-list "Missing expected title tags:" missing-tags)
        (swcad-title-print-string-list "Native GMTITLE GENIUS_GENOREF_13 handle links:" native-handles)
        (setq title-index (+ title-index 1))
      )
    )
    (swcad-title-princ-line "Title inserts: <missing>")
  )
  (swcad-title-princ-line "Other title-like inserts that are not the target GMTITLE block:")
  (if other-title-inserts
    (foreach record other-title-inserts
      (swcad-title-princ-line
        (strcat
          "  - handle="
          (car record)
          ", block="
          (cadr record)
          ", bbox="
          (swcad-title-bbox-string (caddr record))
        )
      )
    )
    (swcad-title-princ-line "  <none>")
  )
  (setq status
    (cond
      ((or (/= filedia 1) (/= cmddia 1)) "WARN_FILEDIA_OR_CMDDIA_NOT_1")
      ((= frame-count 0) "FAIL_MISSING_TARGET_FRAME")
      ((= title-count 0) "FAIL_MISSING_TARGET_TITLE")
      (any-missing-tags "FAIL_MISSING_EXPECTED_ATTRIBUTES")
      (any-empty-attrs "WARN_TITLE_ATTRIBUTES_EMPTY")
      (any-missing-native-xdata "WARN_NATIVE_GMTITLE_XDATA_NOT_FOUND")
      (other-title-inserts "WARN_OTHER_TITLE_LIKE_INSERTS_REMAIN")
      (T "OK_VERIFY_GMTITLE_READY_FOR_MANUAL_DOUBLE_CLICK_CHECK")
    )
  )
  (swcad-title-princ-line (strcat "Result: " status))
  (swcad-title-princ-line "Manual final check still required: double-click the title block and confirm the GMTITLE table editor opens.")
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-insert-handle-list (/ ss total index ename data handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq handle (strcase (swcad-title-string (swcad-title-dxf-value data 5))))
    (if (> (strlen handle) 0)
      (setq result (append result (list handle)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-new-insert-enames (before-handles / ss total index ename data handle result)
  (setq result nil)
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq handle (strcase (swcad-title-string (swcad-title-dxf-value data 5))))
    (if (and (> (strlen handle) 0) (not (member handle before-handles)))
      (setq result (append result (list ename)))
    )
    (setq index (+ index 1))
  )
  result
)

(defun swcad-title-template-tag-p (tag / upper slot found)
  (setq upper (strcase (swcad-title-string tag)))
  (setq found nil)
  (foreach slot *swcad-title-transfer-template*
    (if (equal upper (strcase (car slot)))
      (setq found T)
    )
  )
  found
)

(defun swcad-title-insert-template-attribute-count (ename / object attrs attr count)
  (setq object (swcad-title-safe-vla-object ename))
  (setq attrs (if object (swcad-title-get-insert-attributes object) nil))
  (setq count 0)
  (foreach attr attrs
    (if (swcad-title-template-tag-p (swcad-title-attribute-tag attr))
      (setq count (+ count 1))
    )
  )
  count
)

(defun swcad-title-select-new-gmtitle-title (enames / title-name best best-score ename name score attr-count)
  (setq title-name (strcase (swcad-title-target-title-block-name)))
  (setq best nil)
  (setq best-score 0)
  (foreach ename enames
    (setq name (strcase (swcad-title-effective-insert-name ename)))
    (setq attr-count (swcad-title-insert-template-attribute-count ename))
    (setq score attr-count)
    (if (equal name title-name)
      (setq score (+ score 100))
    )
    (if (and (> score best-score) (> attr-count 0))
      (progn
        (setq best ename)
        (setq best-score score)
      )
    )
  )
  best
)

(defun swcad-title-select-new-gmtitle-frame (enames title-ename / frame-name best best-area ename name bbox area)
  (setq frame-name (strcase (swcad-title-target-frame-block-name)))
  (setq best nil)
  (setq best-area 0.0)
  (foreach ename enames
    (if (not (eq ename title-ename))
      (progn
        (setq name (strcase (swcad-title-effective-insert-name ename)))
        (setq bbox (swcad-title-safe-bbox ename))
        (setq area (swcad-title-bbox-area bbox))
        (cond
          ((equal name frame-name)
            (setq best ename)
            (setq best-area area)
          )
          ((and (not best) (> area best-area))
            (setq best ename)
            (setq best-area area)
          )
        )
      )
    )
  )
  best
)

(defun swcad-title-run-native-gmtitle (/ before-handles result new-enames title-ename frame-ename guard)
  (setq before-handles (swcad-title-insert-handle-list))
  (swcad-title-princ-line "Starting native GMTITLE. In the GMTITLE dialog, choose DR_A3_Outline and DR_titlea_3rd, then place/confirm it.")
  (swcad-title-princ-line "FILEDIA and CMDDIA are not changed by this command.")
  (initdia)
  (setq result (vl-catch-all-apply 'command (list "GMTITLE")))
  (if (vl-catch-all-error-p result)
    (swcad-title-princ-line (strcat "GMTITLE command error: " (vl-catch-all-error-message result)))
  )
  (setq guard 0)
  (while (and (> (getvar "CMDACTIVE") 0) (< guard 200))
    (setq result (vl-catch-all-apply 'command (list pause)))
    (if (vl-catch-all-error-p result)
      (swcad-title-princ-line (strcat "GMTITLE pause error: " (vl-catch-all-error-message result)))
    )
    (setq guard (+ guard 1))
  )
  (setq new-enames (swcad-title-new-insert-enames before-handles))
  (setq title-ename (swcad-title-select-new-gmtitle-title new-enames))
  (setq frame-ename (swcad-title-select-new-gmtitle-frame new-enames title-ename))
  (list title-ename frame-ename new-enames)
)

(defun swcad-title-insert-log-label (label ename / data)
  (if ename
    (progn
      (setq data (entget ename '("*")))
      (swcad-title-princ-line
        (strcat
          label
          ": handle="
          (swcad-title-string (swcad-title-dxf-value data 5))
          ", block="
          (swcad-title-effective-insert-name ename)
          ", bbox="
          (swcad-title-bbox-string (swcad-title-safe-bbox ename))
        )
      )
    )
    (swcad-title-princ-line (strcat label ": <none>"))
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

(defun swcad-title-text-entity-value (data / result pair code value)
  (setq result "")
  (foreach pair data
    (setq code (car pair))
    (setq value (cdr pair))
    (if (and (or (= code 1) (= code 3)) (swcad-title-string-p value))
      (setq result (strcat result value))
    )
  )
  result
)

(defun swcad-title-print-text-candidate (edata scale-value raw-text)
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (swcad-title-dxf-value edata 5))
      ", layout="
      (swcad-title-string (swcad-title-dxf-value edata 410))
      ", type="
      (swcad-title-string (swcad-title-dxf-value edata 0))
      ", layer="
      (swcad-title-string (swcad-title-dxf-value edata 8))
      ", value="
      (swcad-title-string scale-value)
      ", insert="
      (swcad-title-string (swcad-title-dxf-value edata 10))
      ", text=\""
      (swcad-title-string raw-text)
      "\""
    )
  )
)

(defun swcad-title-scan-text-entity (ename / edata raw-text scale-value)
  (setq edata (entget ename '("*")))
  (setq raw-text (swcad-title-text-entity-value edata))
  (setq scale-value (swcad-title-scale-text-candidate raw-text))
  (if scale-value
    (progn
      (setq *swcad-title-scan-loose-scale-count* (+ *swcad-title-scan-loose-scale-count* 1))
      (setq
        *swcad-title-scan-scale-values*
        (swcad-title-list-add-unique
          scale-value
          *swcad-title-scan-scale-values*
        )
      )
      (swcad-title-print-text-candidate edata scale-value raw-text)
      1
    )
    0
  )
)

(defun swcad-title-scan-loose-texts (/ ss index total ename)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq *swcad-title-scan-loose-text-count* total)
  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa total)))
  (swcad-title-princ-line "Loose text scale candidates:")
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (swcad-title-scan-text-entity ename)
    (setq index (+ index 1))
  )
  (if (= *swcad-title-scan-loose-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  *swcad-title-scan-loose-scale-count*
)

(defun swcad-title-text-record-less-p (a b)
  (if (equal (car a) (car b) 1e-8)
    (< (cadr a) (cadr b))
    (> (car a) (car b))
  )
)

(defun swcad-title-text-record (edata raw-text / point scale-value)
  (setq point (swcad-title-dxf-value edata 10))
  (setq scale-value (swcad-title-scale-text-candidate raw-text))
  (list
    (if (and point (cadr point)) (cadr point) 0.0)
    (if (and point (car point)) (car point) 0.0)
    (swcad-title-dxf-value edata 0)
    (swcad-title-dxf-value edata 5)
    (swcad-title-dxf-value edata 8)
    point
    raw-text
    scale-value
  )
)

(defun swcad-title-point-z (point)
  (if (and (listp point) (caddr point))
    (caddr point)
    0.0
  )
)

(defun swcad-title-number-or-default (value default)
  (if (numberp value) value default)
)

(defun swcad-title-transform-block-point (point insert-data block-base / insert-point sx sy rot local-x local-y scaled-x scaled-y cosv sinv)
  (setq insert-point (swcad-title-dxf-value insert-data 10))
  (setq sx (swcad-title-number-or-default (swcad-title-dxf-value insert-data 41) 1.0))
  (setq sy (swcad-title-number-or-default (swcad-title-dxf-value insert-data 42) 1.0))
  (setq rot (swcad-title-number-or-default (swcad-title-dxf-value insert-data 50) 0.0))
  (setq local-x (- (car point) (car block-base)))
  (setq local-y (- (cadr point) (cadr block-base)))
  (setq scaled-x (* local-x sx))
  (setq scaled-y (* local-y sy))
  (setq cosv (cos rot))
  (setq sinv (sin rot))
  (list
    (+ (car insert-point) (- (* scaled-x cosv) (* scaled-y sinv)))
    (+ (cadr insert-point) (+ (* scaled-x sinv) (* scaled-y cosv)))
    (+ (swcad-title-point-z insert-point) (swcad-title-point-z point))
  )
)

(defun swcad-title-block-text-records (insert-ename bbox / insert-data block-name block-data block-base block-obj ename edata etype raw-text local-point world-point expanded-bbox source-handle record records guard)
  (setq records nil)
  (setq insert-data (entget insert-ename '("*")))
  (setq block-name (swcad-title-dxf-value insert-data 2))
  (setq block-data (tblsearch "BLOCK" block-name))
  (setq block-base (if block-data (swcad-title-dxf-value block-data 10) nil))
  (if (not block-base)
    (setq block-base '(0.0 0.0 0.0))
  )
  (setq block-obj (tblobjname "BLOCK" block-name))
  (setq expanded-bbox (swcad-title-expand-bbox bbox 2.0))
  (setq source-handle (swcad-title-string (swcad-title-dxf-value insert-data 5)))
  (if block-obj
    (progn
      (setq ename (entnext block-obj))
      (setq guard 0)
      (while (and ename (< guard 2000))
        (setq edata (entget ename '("*")))
        (setq etype (strcase (swcad-title-string (swcad-title-dxf-value edata 0))))
        (cond
          ((equal etype "ENDBLK")
            (setq ename nil)
          )
          ((member etype '("TEXT" "MTEXT"))
            (setq raw-text (swcad-title-text-entity-value edata))
            (setq local-point (swcad-title-dxf-value edata 10))
            (if (and
                  raw-text
                  (> (strlen raw-text) 0)
                  local-point
                )
              (progn
                (setq world-point
                  (swcad-title-transform-block-point local-point insert-data block-base)
                )
                (if (or (not expanded-bbox) (swcad-title-point-in-bbox-p world-point expanded-bbox))
                  (progn
                    (setq edata (swcad-title-dxf-put edata 10 world-point))
                    (setq edata
                      (swcad-title-dxf-put
                        edata
                        5
                        (strcat
                          "BLOCK:"
                          source-handle
                          ":"
                          (swcad-title-string (swcad-title-dxf-value edata 5))
                        )
                      )
                    )
                    (setq record (swcad-title-text-record edata raw-text))
                    (setq records (append records (list record)))
                  )
                )
              )
            )
          )
        )
        (if ename
          (setq ename (entnext ename))
        )
        (setq guard (+ guard 1))
      )
    )
  )
  records
)

(defun swcad-title-print-text-record (record)
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (nth 3 record))
      ", type="
      (swcad-title-string (nth 2 record))
      ", layer="
      (swcad-title-string (nth 4 record))
      ", point="
      (swcad-title-point-string (nth 5 record))
      (if (nth 7 record)
        (strcat ", scale-candidate=" (swcad-title-string (nth 7 record)))
        ""
      )
      ", text=\""
      (swcad-title-string (nth 6 record))
      "\""
    )
  )
)

(defun swcad-title-print-attribute-record (insert-data attr-data / tag value point)
  (setq tag (swcad-title-dxf-value attr-data 2))
  (setq value (swcad-title-dxf-value attr-data 1))
  (setq point (swcad-title-dxf-value attr-data 10))
  (swcad-title-princ-line
    (strcat
      "    - attr-handle="
      (swcad-title-string (swcad-title-dxf-value attr-data 5))
      ", tag="
      (swcad-title-string tag)
      ", value=\""
      (swcad-title-string value)
      "\""
      ", layer="
      (swcad-title-string (swcad-title-dxf-value attr-data 8))
      ", point="
      (swcad-title-point-string point)
    )
  )
)

(defun swcad-title-scan-title-texts (/ insert-ss insert-index insert-total text-ss text-index text-total ename data block attrs attr-data attr-count title-like bbox bboxes title-insert-count attribute-count text-records raw-text point records-in-bounds record)
  (swcad-title-open-text-log)
  (setq title-insert-count 0)
  (setq attribute-count 0)
  (setq bboxes nil)
  (setq text-records nil)
  (swcad-title-princ-line "----- SWTITLETEXTSCAN read-only title text scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))

  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa insert-total)))
  (swcad-title-princ-line "Title-like inserts and attributes:")
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-dxf-value data 2))
    (setq attrs (swcad-title-insert-attributes ename))
    (setq attr-count (length attrs))
    (setq title-like (swcad-title-title-block-name-p block))
    (if (or title-like (> attr-count 0))
      (progn
        (setq title-insert-count (+ title-insert-count 1))
        (setq bbox (swcad-title-safe-bbox ename))
        (if title-like
          (setq bboxes (append bboxes (list (swcad-title-expand-bbox bbox 2.0))))
        )
        (swcad-title-princ-line
          (strcat
            "  - insert-handle="
            (swcad-title-string (swcad-title-dxf-value data 5))
            ", block="
            (swcad-title-string block)
            ", layer="
            (swcad-title-string (swcad-title-dxf-value data 8))
            ", insert="
            (swcad-title-point-string (swcad-title-dxf-value data 10))
            ", bbox="
            (swcad-title-bbox-string bbox)
            ", attributes="
            (itoa attr-count)
          )
        )
        (foreach attr-data attrs
          (setq attribute-count (+ attribute-count 1))
          (swcad-title-print-attribute-record data attr-data)
        )
        (if (= attr-count 0)
          (swcad-title-princ-line "    <no attributes>")
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  (if (= title-insert-count 0)
    (swcad-title-princ-line "  <none>")
  )

  (setq text-ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq text-total (if text-ss (sslength text-ss) 0))
  (setq text-index 0)
  (while (< text-index text-total)
    (setq ename (ssname text-ss text-index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (setq point (swcad-title-dxf-value data 10))
    (if (and raw-text (> (strlen raw-text) 0))
      (setq text-records
        (append text-records (list (swcad-title-text-record data raw-text)))
      )
    )
    (setq text-index (+ text-index 1))
  )
  (setq text-records (vl-sort text-records 'swcad-title-text-record-less-p))
  (setq records-in-bounds nil)
  (foreach record text-records
    (if (or (not bboxes) (swcad-title-point-in-bboxes-p (nth 5 record) bboxes))
      (setq records-in-bounds (append records-in-bounds (list record)))
    )
  )

  (swcad-title-princ-line (strcat "TEXT/MTEXT count: " (itoa text-total)))
  (if bboxes
    (swcad-title-princ-line "Loose TEXT/MTEXT inside title-block bounds:")
    (swcad-title-princ-line "Loose TEXT/MTEXT records:")
  )
  (if records-in-bounds
    (foreach record records-in-bounds
      (swcad-title-print-text-record record)
    )
    (swcad-title-princ-line "  <none>")
  )

  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line (strcat "  title-like inserts: " (itoa title-insert-count)))
  (swcad-title-princ-line (strcat "  attributes listed: " (itoa attribute-count)))
  (swcad-title-princ-line (strcat "  loose text records listed: " (itoa (length records-in-bounds))))
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-source-bbox (/ insert-ss insert-index insert-total ename data block bbox area best bestarea)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq best nil)
  (setq bestarea nil)
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (setq data (entget ename '("*")))
    (setq block (swcad-title-effective-insert-name ename))
    (if
      (and
        (swcad-title-title-block-name-p block)
        (not (swcad-title-native-target-title-name-p block))
      )
      (progn
        (setq bbox (swcad-title-safe-bbox ename))
        (if bbox
          (progn
            (setq area (* (- (caddr bbox) (car bbox)) (- (cadddr bbox) (cadr bbox))))
            (if (or (not bestarea) (< area bestarea))
              (progn
                (setq best (list ename data bbox))
                (setq bestarea area)
              )
            )
          )
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  best
)

(defun swcad-title-transfer-source-frame (source-bbox source-title-ename / insert-ss insert-index insert-total ename data block bbox area source-area best bestarea)
  (setq insert-ss (ssget "_X" '((0 . "INSERT"))))
  (setq insert-total (if insert-ss (sslength insert-ss) 0))
  (setq source-area (swcad-title-bbox-area source-bbox))
  (setq best nil)
  (setq bestarea nil)
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (if (not (eq ename source-title-ename))
      (progn
        (setq data (entget ename '("*")))
        (setq block (swcad-title-effective-insert-name ename))
        (if (not (swcad-title-native-target-frame-name-p block))
          (progn
            (setq bbox (swcad-title-safe-bbox ename))
            (setq area (swcad-title-bbox-area bbox))
            (if (and
                  bbox
                  (> area (* source-area 2.0))
                  (swcad-title-bbox-contains-bbox-p bbox source-bbox 2.0)
                )
              (if (or (not bestarea) (> area bestarea))
                (progn
                  (setq best (list ename data bbox))
                  (setq bestarea area)
                )
              )
            )
          )
        )
      )
    )
    (setq insert-index (+ insert-index 1))
  )
  best
)

(defun swcad-title-transfer-text-records (bbox source-ename / ss index total ename data raw-text point records record block-records)
  (setq records nil)
  (setq ss (ssget "_X" '((0 . "TEXT,MTEXT"))))
  (setq total (if ss (sslength ss) 0))
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (setq data (entget ename '("*")))
    (setq raw-text (swcad-title-text-entity-value data))
    (setq point (swcad-title-dxf-value data 10))
    (if (and
          raw-text
          (> (strlen raw-text) 0)
          (or (not bbox) (swcad-title-point-in-bbox-p point (swcad-title-expand-bbox bbox 2.0)))
        )
      (progn
        (setq record (swcad-title-text-record data raw-text))
        (setq records (append records (list record)))
      )
    )
    (setq index (+ index 1))
  )
  (if source-ename
    (progn
      (setq block-records (swcad-title-block-text-records source-ename bbox))
      (if block-records
        (setq records (append records block-records))
      )
    )
  )
  (vl-sort records 'swcad-title-text-record-less-p)
)

(defun swcad-title-transfer-preview-record (record bbox / point best slot dist tag label relx rely)
  (setq point (nth 5 record))
  (setq best (swcad-title-transfer-best-slot point bbox))
  (if best
    (progn
      (setq slot (car best))
      (setq dist (cadr best))
      (setq relx (caddr best))
      (setq rely (cadddr best))
      (setq tag (car slot))
      (setq label (cadddr slot))
      (list tag label (nth 6 record) (nth 3 record) point dist relx rely record)
    )
    nil
  )
)

(defun swcad-title-transfer-print-mapping (mapping)
  (swcad-title-princ-line
    (strcat
      "  "
      (car mapping)
      " ["
      (cadr mapping)
      "] <= \""
      (swcad-title-string (caddr mapping))
      "\""
      ", source-handle="
      (swcad-title-string (cadddr mapping))
      ", source-point="
      (swcad-title-point-string (nth 4 mapping))
      ", distance="
      (swcad-title-number-string (nth 5 mapping))
    )
  )
)

(defun swcad-title-transfer-print-unmapped (record bbox / best slot)
  (setq best (swcad-title-transfer-best-slot (nth 5 record) bbox))
  (swcad-title-princ-line
    (strcat
      "  - handle="
      (swcad-title-string (nth 3 record))
      ", point="
      (swcad-title-point-string (nth 5 record))
      ", text=\""
      (swcad-title-string (nth 6 record))
      "\""
      (if best
        (progn
          (setq slot (car best))
          (strcat
            ", nearest="
            (car slot)
            ", distance="
            (swcad-title-number-string (cadr best))
          )
        )
        ""
      )
    )
  )
)

(defun swcad-title-transfer-preview (/ source source-ename source-data source-bbox source-block source-frame source-frame-ename source-frame-data source-frame-bbox source-frame-block records mappings unmapped duplicates record preview tag existing slot maxdist missing-count mapped-count duplicate-count unmapped-count values inferred-frame-bbox title-graphic-handles frame-graphic-handles)
  (swcad-title-open-transfer-log)
  (setq maxdist 7.0)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-data (swcad-title-dxf-value source-data 2) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-data (swcad-title-dxf-value source-frame-data 2) nil))
  (setq mappings nil)
  (setq unmapped nil)
  (setq duplicates nil)
  (setq mapped-count 0)
  (setq duplicate-count 0)
  (setq unmapped-count 0)
  (swcad-title-princ-line "----- SWTITLETRANSFERPREVIEW read-only GM TITLE transfer preview -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (if source-bbox
    (progn
      (setq records (swcad-title-transfer-text-records source-bbox source-ename))
      (foreach record records
        (setq preview (swcad-title-transfer-preview-record record source-bbox))
        (if (and preview (<= (nth 5 preview) maxdist))
          (progn
            (setq tag (car preview))
            (setq existing (assoc tag mappings))
            (if existing
              (progn
                (setq duplicates (append duplicates (list record)))
                (setq duplicate-count (+ duplicate-count 1))
              )
              (progn
                (setq mappings (swcad-title-assoc-put tag preview mappings))
                (setq mapped-count (+ mapped-count 1))
              )
            )
          )
          (progn
            (setq unmapped (append unmapped (list record)))
            (setq unmapped-count (+ unmapped-count 1))
          )
        )
      )

      (swcad-title-princ-line "GM TITLE attribute transfer preview:")
      (setq missing-count 0)
      (foreach slot *swcad-title-transfer-template*
        (setq tag (car slot))
        (setq existing (assoc tag mappings))
        (if existing
          (swcad-title-transfer-print-mapping (cdr existing))
          (progn
            (setq missing-count (+ missing-count 1))
            (swcad-title-princ-line
              (strcat
                "  "
                tag
                " ["
                (cadddr slot)
                "] <= <missing>"
              )
            )
          )
        )
      )

      (swcad-title-princ-line "Unmapped source title texts:")
      (if unmapped
        (foreach record unmapped
          (swcad-title-transfer-print-unmapped record source-bbox)
        )
        (swcad-title-princ-line "  <none>")
      )
      (swcad-title-princ-line "Duplicate source title texts:")
      (if duplicates
        (foreach record duplicates
          (swcad-title-transfer-print-unmapped record source-bbox)
        )
        (swcad-title-princ-line "  <none>")
      )
      (setq values (swcad-title-transfer-values mappings))
      (setq inferred-frame-bbox
        (if source-frame-bbox
          source-frame-bbox
          (swcad-title-inferred-source-frame-bbox source-bbox values)
        )
      )
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (swcad-title-princ-line
        (strcat
          "Source frame insert: "
          (if source-frame-data
            (strcat
              "handle="
              (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
              ", block="
              (swcad-title-string source-frame-block)
              ", bbox="
              (swcad-title-bbox-string source-frame-bbox)
            )
            "<none>"
          )
        )
      )
      (swcad-title-princ-line (strcat "Old loose title graphics cleanup candidates: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics cleanup candidates: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (swcad-title-princ-line "Summary:")
      (swcad-title-princ-line (strcat "  source title texts: " (itoa (length records))))
      (swcad-title-princ-line (strcat "  mapped fields: " (itoa mapped-count)))
      (swcad-title-princ-line (strcat "  missing target fields: " (itoa missing-count)))
      (swcad-title-princ-line (strcat "  unmapped source texts: " (itoa unmapped-count)))
      (swcad-title-princ-line (strcat "  duplicate source texts: " (itoa duplicate-count)))
    )
    (progn
      (swcad-title-princ-line "No title-like insert was found. Run SWTITLETEXTSCAN for raw text details.")
      (swcad-title-princ-line "Summary:")
      (swcad-title-princ-line "  mapped fields: 0")
    )
  )
  (swcad-title-princ-line "No drawing data was changed.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-apply (/ source source-data source-bbox source-ename source-block source-frame source-frame-ename source-frame-data source-frame-block source-frame-bbox frame-block title-block gmtitle-result gmtitle-title-ename gmtitle-frame-ename gmtitle-new-enames title-ref build mappings records unmapped duplicates values answer attr-count deleted-text-count skipped-block-text-count old-frame-deleted record doc pair inferred-frame-bbox title-graphic-handles frame-graphic-handles deleted-title-graphic-count deleted-frame-graphic-count actual-title-name actual-frame-name deleted-new-gmtitle-count)
  (swcad-title-open-apply-log)
  (setq *swcad-title-last-apply-status* nil)
  (setq source (swcad-title-transfer-source-bbox))
  (setq source-ename (if source (car source) nil))
  (setq source-data (if source (cadr source) nil))
  (setq source-bbox (if source (caddr source) nil))
  (setq source-block (if source-data (swcad-title-dxf-value source-data 2) nil))
  (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
  (setq source-frame-ename (if source-frame (car source-frame) nil))
  (setq source-frame-data (if source-frame (cadr source-frame) nil))
  (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
  (setq source-frame-block (if source-frame-data (swcad-title-dxf-value source-frame-data 2) nil))
  (setq frame-block (swcad-title-target-frame-block-name))
  (setq title-block (swcad-title-target-title-block-name))
  (swcad-title-princ-line "----- SWTITLETRANSFERAPPLY native GMTITLE transfer apply -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (swcad-title-print-work-copy-status)
  (swcad-title-princ-line (strcat "FILEDIA before: " (swcad-title-string (getvar "FILEDIA")) " (not changed)"))
  (swcad-title-princ-line (strcat "CMDDIA before: " (swcad-title-string (getvar "CMDDIA")) " (not changed)"))
  (swcad-title-princ-line
    (strcat
      "Source title insert: "
      (if source-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-data 5))
          ", block="
          (swcad-title-string source-block)
          ", bbox="
          (swcad-title-bbox-string source-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Source frame insert: "
      (if source-frame-data
        (strcat
          "handle="
          (swcad-title-string (swcad-title-dxf-value source-frame-data 5))
          ", block="
          (swcad-title-string source-frame-block)
          ", bbox="
          (swcad-title-bbox-string source-frame-bbox)
        )
        "<none>"
      )
    )
  )
  (swcad-title-princ-line
    (strcat
      "Expected native GMTITLE frame block: "
      frame-block
    )
  )
  (swcad-title-princ-line
    (strcat
      "Expected native GMTITLE title block: "
      title-block
    )
  )
  (cond
    ((not source-bbox)
      (swcad-title-apply-result "ABORT_NO_SOURCE_TITLE")
    )
    ((swcad-title-document-read-only-p)
      (swcad-title-apply-result "ABORT_READ_ONLY_DOCUMENT")
      (swcad-title-princ-line "Open a writable copy of the DWG before applying.")
    )
    ((not (swcad-title-apply-work-copy-confirmed-p))
      (swcad-title-apply-result "ABORT_NOT_WORK_COPY")
      (swcad-title-princ-line "Open or create a copy under Documents/CAD tool/work before applying.")
    )
    (T
      (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
      (setq mappings (car build))
      (setq records (cadr build))
      (setq unmapped (caddr build))
      (setq duplicates (cadddr build))
      (setq values (swcad-title-transfer-values mappings))
      (setq inferred-frame-bbox
        (if source-frame-bbox
          source-frame-bbox
          (swcad-title-inferred-source-frame-bbox source-bbox values)
        )
      )
      (setq title-graphic-handles (swcad-title-source-title-graphic-handles source-bbox))
      (setq frame-graphic-handles
        (if source-frame-ename
          nil
          (swcad-title-source-frame-graphic-handles inferred-frame-bbox source-bbox)
        )
      )
      (swcad-title-princ-line "Values to apply:")
      (foreach pair values
        (swcad-title-princ-line
          (strcat
            "  "
            (car pair)
            " = \""
            (swcad-title-string (cdr pair))
            "\""
          )
        )
      )
      (swcad-title-princ-line
        (strcat
          "Unmapped source texts to delete with old title text: "
          (itoa (length unmapped))
        )
      )
      (swcad-title-princ-line
        (strcat
          "Duplicate source texts not mapped: "
          (itoa (length duplicates))
        )
      )
      (swcad-title-princ-line (strcat "Old loose title graphics queued for cleanup: " (itoa (length title-graphic-handles))))
      (swcad-title-princ-line
        (strcat
          "Old loose frame graphics queued for cleanup: "
          (itoa (length frame-graphic-handles))
          ", frame cleanup bbox="
          (swcad-title-bbox-string inferred-frame-bbox)
        )
      )
      (setq answer
        (if *swcad-title-batch-mode*
          "YES"
          (getstring
            T
            "\nType YES to run native GMTITLE, fill the new title attributes, and remove old title content: "
          )
        )
      )
      (if *swcad-title-batch-mode*
        (swcad-title-princ-line "Confirmation: batch mode")
      )
      (if (/= (strcase answer) "YES")
        (swcad-title-apply-result "ABORT_USER_CANCEL")
        (progn
          (setq gmtitle-result (swcad-title-run-native-gmtitle))
          (setq gmtitle-title-ename (car gmtitle-result))
          (setq gmtitle-frame-ename (cadr gmtitle-result))
          (setq gmtitle-new-enames (caddr gmtitle-result))
          (swcad-title-princ-line (strcat "Native GMTITLE new INSERT count: " (itoa (length gmtitle-new-enames))))
          (swcad-title-insert-log-label "Native GMTITLE title insert" gmtitle-title-ename)
          (swcad-title-insert-log-label "Native GMTITLE frame insert" gmtitle-frame-ename)
          (setq actual-title-name (if gmtitle-title-ename (swcad-title-effective-insert-name gmtitle-title-ename) ""))
          (setq actual-frame-name (if gmtitle-frame-ename (swcad-title-effective-insert-name gmtitle-frame-ename) ""))
          (swcad-title-princ-line (strcat "Native GMTITLE selected title block: " (if (> (strlen actual-title-name) 0) actual-title-name "<missing>")))
          (swcad-title-princ-line (strcat "Native GMTITLE selected frame block: " (if (> (strlen actual-frame-name) 0) actual-frame-name "<missing>")))
          (if gmtitle-title-ename
            (if
              (and
                (swcad-title-native-target-title-name-p actual-title-name)
                gmtitle-frame-ename
                (swcad-title-native-target-frame-name-p actual-frame-name)
              )
              (progn
                (setq title-ref (swcad-title-safe-vla-object gmtitle-title-ename))
                (setq doc (swcad-title-doc))
                (vl-catch-all-apply 'vla-StartUndoMark (list doc))
                (setq attr-count (swcad-title-set-insert-attributes title-ref values))
                (swcad-title-delete-ename source-ename)
                (setq deleted-text-count 0)
                (setq skipped-block-text-count 0)
                (foreach record records
                  (if (swcad-title-delete-text-record record)
                    (setq deleted-text-count (+ deleted-text-count 1))
                    (setq skipped-block-text-count (+ skipped-block-text-count 1))
                  )
                )
                (setq old-frame-deleted "no")
                (if source-frame-ename
                  (progn
                    (swcad-title-delete-ename source-frame-ename)
                    (setq old-frame-deleted "yes")
                  )
                )
                (setq deleted-title-graphic-count (swcad-title-delete-handle-list title-graphic-handles))
                (setq deleted-frame-graphic-count
                  (if source-frame-ename
                    0
                    (swcad-title-delete-handle-list frame-graphic-handles)
                  )
                )
                (vl-catch-all-apply 'vla-EndUndoMark (list doc))
                (swcad-title-princ-line "Native GMTITLE was used directly.")
                (swcad-title-princ-line (strcat "Attributes set: " (itoa attr-count)))
                (swcad-title-princ-line (strcat "Old loose title texts deleted: " (itoa deleted-text-count)))
                (swcad-title-princ-line (strcat "Old block-internal title texts handled by deleting source insert: " (itoa skipped-block-text-count)))
                (swcad-title-princ-line (strcat "Old loose title graphics deleted: " (itoa deleted-title-graphic-count)))
                (swcad-title-princ-line "Old title insert deleted: yes")
                (swcad-title-princ-line (strcat "Old frame insert deleted: " old-frame-deleted))
                (swcad-title-princ-line (strcat "Old loose frame graphics deleted: " (itoa deleted-frame-graphic-count)))
                (swcad-title-apply-result "APPLIED_TITLE_TRANSFER")
                (swcad-title-princ-line "Manual final check: double-click the new GMTITLE title block and confirm the GMTITLE table editor opens.")
              )
              (progn
                (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
                (swcad-title-apply-result "ABORT_WRONG_NATIVE_GMTITLE_SELECTION")
                (swcad-title-princ-line (strcat "Expected frame block: " frame-block))
                (swcad-title-princ-line (strcat "Expected title block: " title-block))
                (swcad-title-princ-line (strcat "Removed wrong/new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
                (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
              )
            )
            (progn
              (setq deleted-new-gmtitle-count (swcad-title-delete-ename-list gmtitle-new-enames))
              (swcad-title-apply-result "ABORT_NO_NATIVE_GMTITLE_TITLE")
              (swcad-title-princ-line (strcat "Removed partial/new GMTITLE inserts: " (itoa deleted-new-gmtitle-count)))
              (swcad-title-princ-line "No old SOLIDWORKS title/frame content was removed.")
            )
          )
        )
      )
    )
  )
  (swcad-title-princ-line "Note: loose frame cleanup is conservative; it deletes only pre-existing title-area graphics and inferred frame-edge graphics.")
  (swcad-title-close-log)
  (princ)
)

(defun swcad-title-transfer-batch-run (count / index source apply-result)
  (setq index 1)
  (while (<= index count)
    (setq source (swcad-title-transfer-source-bbox))
    (if source
      (progn
        (princ
          (strcat
            "\n--- SWTITLETRANSFERBATCH sheet "
            (itoa index)
            " / "
            (itoa count)
            " ---"
          )
        )
        (setq apply-result (vl-catch-all-apply 'swcad-title-transfer-apply nil))
        (if (vl-catch-all-error-p apply-result)
          (progn
            (setq *swcad-title-last-apply-status* "ERROR_BATCH_APPLY")
            (princ
              (strcat
                "\nBatch apply error: "
                (vl-catch-all-error-message apply-result)
              )
            )
            (swcad-title-close-log)
          )
        )
        (if (/= *swcad-title-last-apply-status* "APPLIED_TITLE_TRANSFER")
          (progn
            (princ
              (strcat
                "\nBatch stopped after status: "
                (swcad-title-string *swcad-title-last-apply-status*)
              )
            )
            (setq index count)
          )
        )
      )
      (progn
        (setq *swcad-title-last-apply-status* "STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (princ "\nResult: STOP_NO_MORE_SOLIDWORKS_TITLE_SOURCE")
        (setq index count)
      )
    )
    (setq index (+ index 1))
  )
)

(defun swcad-title-transfer-batch (/ count answer old-batch-mode batch-result)
  (setq count (getint "\nNumber of SOLIDWORKS title blocks/sheets to process with native GMTITLE <1>: "))
  (if (not count)
    (setq count 1)
  )
  (if (< count 1)
    (setq count 1)
  )
  (setq answer
    (getstring
      T
      (strcat
        "\nType YES to process "
        (itoa count)
        " sheet(s). Native GMTITLE will open once per sheet: "
      )
    )
  )
  (if (/= (strcase answer) "YES")
    (progn
      (princ "\nResult: ABORT_USER_CANCEL")
      (princ)
    )
    (progn
      (setq old-batch-mode *swcad-title-batch-mode*)
      (setq *swcad-title-batch-mode* T)
      (setq batch-result (vl-catch-all-apply 'swcad-title-transfer-batch-run (list count)))
      (setq *swcad-title-batch-mode* old-batch-mode)
      (if (vl-catch-all-error-p batch-result)
        (progn
          (setq *swcad-title-last-apply-status* "ERROR_BATCH_FATAL")
          (princ
            (strcat
              "\nBatch fatal error: "
              (vl-catch-all-error-message batch-result)
            )
          )
        )
      )
      (princ "\nSWTITLETRANSFERBATCH finished. Run SWTITLEGMTITLEVERIFY, then double-click a new title block for the final table-editor check.")
      (princ)
    )
  )
)

(defun swcad-title-scale-text-to-dimlfac (text / cleaned ratio pos left right numerator denominator value)
  (setq cleaned (vl-string-trim " \t\r\n" (swcad-title-string text)))
  (setq ratio (swcad-title-extract-ratio-text cleaned))
  (if ratio
    (setq cleaned ratio)
  )
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
  (setq *swcad-title-scan-loose-text-count* 0)
  (setq *swcad-title-scan-loose-scale-count* 0)
  (setq *swcad-title-scan-scale-values* nil)
  (swcad-title-princ-line "----- SWTITLESCAN read-only title scale scan -----")
  (swcad-title-princ-line (strcat "DWG: " (getvar "DWGPREFIX") (getvar "DWGNAME")))
  (swcad-title-princ-line (strcat "CTAB: " (getvar "CTAB")))
  (setq ss (ssget "_X" '((0 . "INSERT"))))
  (setq total (if ss (sslength ss) 0))
  (swcad-title-princ-line (strcat "INSERT count: " (itoa total)))
  (swcad-title-princ-line "Attribute title scale candidates:")
  (setq index 0)
  (while (< index total)
    (setq ename (ssname ss index))
    (swcad-title-scan-insert ename)
    (setq index (+ index 1))
  )
  (if (= *swcad-title-scan-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-scan-loose-texts)
  (swcad-title-princ-line "Summary:")
  (swcad-title-princ-line
    (strcat "  title inserts with scale: " (itoa *swcad-title-scan-title-insert-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale attributes: " (itoa *swcad-title-scan-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  loose text scale candidates: " (itoa *swcad-title-scan-loose-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale values: " (swcad-title-list-string *swcad-title-scan-scale-values*))
  )
  (swcad-title-princ-line
    (strcat
      "Result: "
      (if (> (+ *swcad-title-scan-scale-count* *swcad-title-scan-loose-scale-count*) 0)
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

(defun c:SWTITLETEXTSCAN ()
  (swcad-title-scan-title-texts)
)

(defun c:SWTITLEGMTITLEVERIFY ()
  (swcad-title-gmtitle-verify)
)

(defun c:SWTITLETRANSFERPREVIEW ()
  (swcad-title-transfer-preview)
)

(defun c:SWTITLETRANSFERAPPLY ()
  (swcad-title-transfer-apply)
)

(defun c:SWTITLETRANSFERBATCH ()
  (swcad-title-transfer-batch)
)

(defun c:SWSCALESCAN (/ insert-ss insert-index insert-total dim-ss dim-index dim-total ename data overrides style styledata override-value style-value effective-value expected-values effective-counts override-counts style-counts match-count mismatch-count mismatch-example-count match result)
  (swcad-title-open-scale-log)
  (setq *swcad-title-scan-title-insert-count* 0)
  (setq *swcad-title-scan-scale-count* 0)
  (setq *swcad-title-scan-loose-text-count* 0)
  (setq *swcad-title-scan-loose-scale-count* 0)
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
  (swcad-title-princ-line "Attribute title scale candidates:")
  (setq insert-index 0)
  (while (< insert-index insert-total)
    (setq ename (ssname insert-ss insert-index))
    (swcad-title-scan-insert ename)
    (setq insert-index (+ insert-index 1))
  )
  (if (= *swcad-title-scan-scale-count* 0)
    (swcad-title-princ-line "  <none>")
  )
  (swcad-title-scan-loose-texts)

  (setq expected-values (swcad-title-expected-dimlfac-values *swcad-title-scan-scale-values*))
  (swcad-title-princ-line "Title scale summary:")
  (swcad-title-princ-line
    (strcat "  title inserts with scale: " (itoa *swcad-title-scan-title-insert-count*))
  )
  (swcad-title-princ-line
    (strcat "  scale attributes: " (itoa *swcad-title-scan-scale-count*))
  )
  (swcad-title-princ-line
    (strcat "  loose text scale candidates: " (itoa *swcad-title-scan-loose-scale-count*))
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
(princ "\nCommands: SWTITLEDEBUG, SWTITLESCAN, SWTITLETEXTSCAN, SWTITLEGMTITLEVERIFY, SWTITLETRANSFERPREVIEW, SWTITLETRANSFERAPPLY, SWTITLETRANSFERBATCH, SWSCALESCAN")
(princ)
