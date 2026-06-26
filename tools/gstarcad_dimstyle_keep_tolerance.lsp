;;; GstarCAD / AutoCAD dimension style unifier that keeps SOLIDWORKS tolerances.
;;;
;;; Commands:
;;;   SWAUTO        - Run the normal workflow in one command:
;;;                   AM_ISO style mapping, REGENALL, Mechanical fit conversion,
;;;                   REGENALL, and final old style cleanup.
;;;   SWHELP        - Print the short daily-use workflow and troubleshooting
;;;                   commands.
;;;   SWDIMKEEPAMISO - Update current-tab dimensions to AM_ISO$0, but diameter
;;;                    dimensions to AM_ISO$3, while preserving overrides.
;;;   SWPURGESTYLES - Purge unused non-default dimension styles after SWAUTO.
;;;   SWFINDSTYLE  - Find dimensions still using a style wildcard such as
;;;                  *SLDDIMSTYLE* in layouts and block definitions.
;;;   SWTRYDELDIMSTYLES - Try to delete unused matching dimension styles through
;;;                       CAD ActiveX delete; referenced styles are left alone.
;;;   SWDEBUG      - Check AM_ISO mapping, fit code, tolerance, DIMLFAC, size
;;;                  overrides, and optionally save one detailed dump file.
;;;   SWMECHFITSEL  - Convert selected dimensions with embedded fit codes to
;;;                   GstarCAD Mechanical fit xdata.
;;;   SWMECHFITALL  - Convert all eligible dimensions in the current tab.
;;;
;;; Why this exists:
;;; SOLIDWORKS-exported DWG files often store tolerance display through generated
;;; dimension styles such as SLDIMSTYLE0..6. If those dimensions are simply
;;; changed to one standard style, the style-level tolerance display can disappear.
;;; This command first "bakes" the effective tolerance values into each dimension's
;;; ACAD/DSTYLE xdata, then changes the style name.

(vl-load-com)

(setq *swdt-dimvar-specs*
  '(
    (3   . string) ; DIMPOST
    (4   . string) ; DIMAPOST
    (40  . real)   ; DIMSCALE
    (41  . real)   ; DIMASZ
    (42  . real)   ; DIMEXO
    (43  . real)   ; DIMDLI
    (44  . real)   ; DIMEXE
    (46  . real)   ; DIMDLE
    (47  . real)   ; DIMTP
    (48  . real)   ; DIMTM
    (71  . int)    ; DIMTOL
    (72  . int)    ; DIMLIM
    (140 . real)   ; DIMTXT
    (141 . real)   ; DIMCEN
    (142 . real)   ; DIMTSZ
    (144 . real)   ; DIMLFAC
    (146 . real)   ; DIMTFAC
    (147 . real)   ; DIMGAP
    (272 . int)    ; DIMTDEC
    (274 . int)    ; DIMALTTD
    (283 . int)    ; DIMTOLJ
    (284 . int)    ; DIMTZIN
    (286 . int)    ; DIMALTTZ
  )
)

(setq *swdt-fit-review-matches* nil)
(setq *swdt-fit-review-index* 0)
(setq *swdt-mechfit-stage* "")
(setq *swdt-version* "260626-1048")

(defun swdt-mechfit-stage (label)
  (setq *swdt-mechfit-stage* label)
)

(defun swdt-doc ()
  (vla-get-ActiveDocument (vlax-get-acad-object))
)

(defun swdt-safe-call (fn args / result)
  (setq result (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swdt-dxf-put (data code value)
  (if (assoc code data)
    (subst (cons code value) (assoc code data) data)
    (append data (list (cons code value)))
  )
)

(defun swdt-remove-xdata (data)
  (vl-remove-if '(lambda (item) (= (car item) -3)) data)
)

(defun swdt-xdata-apps (data / xd)
  (setq xd (assoc -3 data))
  (if xd (cdr xd) nil)
)

(defun swdt-string-p (value / typ typtext)
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

(defun swdt-safe-string (value)
  (if (swdt-string-p value) value nil)
)

(defun swdt-text-value-string (value)
  (cond
    ((swdt-string-p value) value)
    ((not value) "")
    (T (vl-princ-to-string value))
  )
)

(defun swdt-princ-string (value)
  (cond
    ((swdt-string-p value) value)
    ((numberp value) (rtos (float value) 2 6))
    ((not value) "nil")
    (T (vl-princ-to-string value))
  )
)

(defun swdt-xdata-app-name (app)
  (if (and (listp app) (swdt-string-p (car app)))
    (car app)
    nil
  )
)

(defun swdt-acad-app (apps / result name)
  (foreach app apps
    (setq name (swdt-xdata-app-name app))
    (if (and (not result) name (equal name "ACAD"))
      (setq result app)
    )
  )
  result
)

(defun swdt-remove-dstyle-section (pairs / result skipping depth item)
  (setq result nil)
  (setq skipping nil)
  (setq depth 0)
  (while pairs
    (setq item (car pairs))
    (cond
      ((and (not skipping)
            (= (car item) 1000)
            (equal (cdr item) "DSTYLE")
            (cadr pairs)
            (= (car (cadr pairs)) 1002)
            (equal (cdr (cadr pairs)) "{"))
        (setq skipping T)
        (setq depth 0)
      )
      (skipping
        (cond
          ((and (= (car item) 1002) (equal (cdr item) "{"))
            (setq depth (1+ depth))
          )
          ((and (= (car item) 1002) (equal (cdr item) "}"))
            (setq depth (1- depth))
            (if (<= depth 0)
              (setq skipping nil)
            )
          )
        )
      )
      (T
        (setq result (append result (list item)))
      )
    )
    (setq pairs (cdr pairs))
  )
  result
)

(defun swdt-xdata-value-pair (kind value)
  (cond
    ((and (eq kind 'real) (numberp value)) (cons 1040 (float value)))
    ((and (eq kind 'int) (numberp value)) (cons 1070 (fix value)))
    ((eq kind 'string) (cons 1000 (if (swdt-string-p value) value "")))
    (T nil)
  )
)

(defun swdt-build-dstyle-pairs (overrides / result spec code kind value valuepair)
  (if overrides
    (progn
      (setq result (list (cons 1000 "DSTYLE") (cons 1002 "{")))
      (foreach spec *swdt-dimvar-specs*
        (setq code (car spec))
        (setq kind (cdr spec))
        (if (assoc code overrides)
          (progn
            (setq value (cdr (assoc code overrides)))
            (setq valuepair (swdt-xdata-value-pair kind value))
            (if valuepair
              (setq result
                (append result (list (cons 1070 code) valuepair))
              )
            )
          )
        )
      )
      (append result (list (cons 1002 "}")))
    )
    nil
  )
)

(defun swdt-set-dstyle-xdata (data overrides / apps acad newpairs dstyle newapps app name)
  (setq apps (swdt-xdata-apps data))
  (setq acad (swdt-acad-app apps))
  (setq dstyle (swdt-build-dstyle-pairs overrides))
  (setq newapps nil)
  (foreach app apps
    (setq name (swdt-xdata-app-name app))
    (if (and name (equal name "ACAD"))
      (progn
        (setq newpairs (swdt-remove-dstyle-section (cdr app)))
        (if dstyle
          (setq newpairs (append newpairs dstyle))
        )
        (if newpairs
          (setq newapps (append newapps (list (cons "ACAD" newpairs))))
        )
      )
      (if name
        (setq newapps (append newapps (list app)))
      )
    )
  )
  (if (and (not acad) dstyle)
    (setq newapps (append newapps (list (cons "ACAD" dstyle))))
  )
  (if newapps
    (append (swdt-remove-xdata data) (list (cons -3 newapps)))
    (swdt-remove-xdata data)
  )
)

(defun swdt-get-dstyle-overrides (data / apps acad pairs result item code valuepair)
  (setq apps (swdt-xdata-apps data))
  (setq acad (swdt-acad-app apps))
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
              (setq result (swdt-dxf-put result code (cdr valuepair)))
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

(defun swdt-effective-tolerance-values (data / style styledata overrides result spec code value)
  (setq style (swdt-safe-string (cdr (assoc 3 data))))
  (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
  (setq overrides (swdt-get-dstyle-overrides data))
  (setq result nil)
  (foreach spec *swdt-dimvar-specs*
    (setq code (car spec))
    (cond
      ((assoc code overrides)
        (setq value (cdr (assoc code overrides)))
        (setq result (swdt-dxf-put result code value))
      )
      ((and styledata (assoc code styledata))
        (setq value (cdr (assoc code styledata)))
        (setq result (swdt-dxf-put result code value))
      )
    )
  )
  result
)

(defun swdt-nonzero-real-p (value)
  (and value (numberp value) (> (abs (float value)) 1e-12))
)

(defun swdt-meaningful-text-p (text)
  (and
    (swdt-string-p text)
    (/= text "")
    (/= text "<>")
    (/= text " ")
  )
)

(defun swdt-tolerance-active-p (values text / dimtol dimlim dimtp dimtm dimpost dimapost)
  (setq dimtol (cdr (assoc 71 values)))
  (setq dimlim (cdr (assoc 72 values)))
  (setq dimtp (cdr (assoc 47 values)))
  (setq dimtm (cdr (assoc 48 values)))
  (setq dimpost (cdr (assoc 3 values)))
  (setq dimapost (cdr (assoc 4 values)))
  (or
    (and dimtol (= dimtol 1))
    (and dimlim (= dimlim 1))
    (swdt-nonzero-real-p dimtp)
    (swdt-nonzero-real-p dimtm)
    (swdt-meaningful-text-p dimpost)
    (swdt-meaningful-text-p dimapost)
    (swdt-meaningful-text-p text)
  )
)

(defun swdt-display-size-override-code-p (code)
  (member code '(40 41 42 43 44 46 140 141 142 147))
)

(defun swdt-preserve-dstyle-override-p (code value)
  (cond
    ((swdt-display-size-override-code-p code) nil)
    (T T)
  )
)

(defun swdt-filter-overrides-for-entity (values text / result spec code value)
  (if (swdt-tolerance-active-p values text)
    (progn
      (setq result nil)
      (foreach spec *swdt-dimvar-specs*
        (setq code (car spec))
        (if (assoc code values)
          (progn
            (setq value (cdr (assoc code values)))
            (if (swdt-preserve-dstyle-override-p code value)
              (setq result (swdt-dxf-put result code value))
            )
          )
        )
      )
      result
    )
    nil
  )
)

(defun swdt-process-dimension (ent target / data text values overrides newdata ok)
  (setq data (entget ent '("ACAD")))
  (setq text (swdt-safe-string (cdr (assoc 1 data))))
  (setq values (swdt-effective-tolerance-values data))
  (setq overrides (swdt-filter-overrides-for-entity values text))
  (setq newdata (swdt-dxf-put data 3 target))
  (if text
    (setq newdata (swdt-dxf-put newdata 1 text))
  )
  (setq newdata (swdt-set-dstyle-xdata newdata overrides))
  (regapp "ACAD")
  (setq ok (entmod newdata))
  (if ok (entupd ent))
  (if ok
    (if overrides 'tolerance 'style-only)
    nil
  )
)

(defun swdt-dim-subclass-present-p (data subclass / found item)
  (setq found nil)
  (foreach item data
    (if (and
          (= (car item) 100)
          (swdt-string-p (cdr item))
          (equal (strcase (cdr item)) (strcase subclass))
        )
      (setq found T)
    )
  )
  found
)

(defun swdt-dim-text-has-diameter-symbol-p (data / text values dimpost dimapost)
  (setq text (swdt-text-value-string (cdr (assoc 1 data))))
  (setq values (swdt-effective-tolerance-values data))
  (setq dimpost (swdt-text-value-string (cdr (assoc 3 values))))
  (setq dimapost (swdt-text-value-string (cdr (assoc 4 values))))
  (or
    (vl-string-search "%%C" (strcase text))
    (vl-string-search "%%C" (strcase dimpost))
    (vl-string-search "%%C" (strcase dimapost))
  )
)

(defun swdt-diameter-dimension-p (ent / data dtype dimtype obj objname)
  (setq data (entget ent '("ACAD")))
  (setq dtype (cdr (assoc 70 data)))
  (setq dimtype (if (numberp dtype) (rem (fix dtype) 8) nil))
  (setq obj (vlax-ename->vla-object ent))
  (setq objname (swdt-safe-prop obj 'ObjectName))
  (or
    (and dimtype (= dimtype 3))
    (swdt-dim-subclass-present-p data "AcDbDiametricDimension")
    (and (swdt-string-p objname) (vl-string-search "DIAMETRIC" (strcase objname)))
    (swdt-dim-text-has-diameter-symbol-p data)
  )
)

(defun swdt-print-values (values / spec code value)
  (foreach spec *swdt-dimvar-specs*
    (setq code (car spec))
    (if (assoc code values)
      (progn
        (setq value (cdr (assoc code values)))
        (princ (strcat "\n  " (itoa code) " = "))
        (princ value)
      )
    )
  )
)

(defun swdt-dimstyle-names (/ item names)
  (setq names nil)
  (setq item (tblnext "DIMSTYLE" T))
  (while item
    (setq names (append names (list (cdr (assoc 2 item)))))
    (setq item (tblnext "DIMSTYLE"))
  )
  names
)

(defun swdt-print-dimstyle-matches (needle limit / upper count name names)
  (setq names (swdt-dimstyle-names))
  (setq upper (strcase needle))
  (setq count 0)
  (foreach name names
    (if
      (or
        (= upper "")
        (vl-string-search upper (strcase name))
        (vl-string-search (strcase name) upper)
      )
      (if (< count limit)
        (progn
          (setq count (1+ count))
          (princ (strcat "\n  " (itoa count) ". " name))
        )
      )
    )
  )
  (if (= count 0)
    (progn
      (princ "\n  No close matches. First available dimension styles:")
      (setq count 0)
      (foreach name names
        (if (< count limit)
          (progn
            (setq count (1+ count))
            (princ (strcat "\n  " (itoa count) ". " name))
          )
        )
      )
    )
  )
  count
)

(defun swdt-print-dimstyle-numbered-list (names / idx name)
  (setq idx 1)
  (foreach name names
    (princ (strcat "\n  " (itoa idx) ". " name))
    (setq idx (1+ idx))
  )
)

(defun swdt-sorted-dimstyle-names ()
  (vl-sort (swdt-dimstyle-names)
    '(lambda (a b) (< (strcase a) (strcase b)))
  )
)

(defun swdt-print-dimstyle-page (names page pagesize / count start idx shown name)
  (setq count (length names))
  (setq start (* page pagesize))
  (setq idx start)
  (setq shown 0)
  (princ (strcat "\nDimension styles page " (itoa (1+ page)) ":"))
  (while (and (< idx count) (< shown pagesize))
    (setq name (nth idx names))
    (setq shown (1+ shown))
    (princ (strcat "\n  " (itoa shown) ". " name))
    (setq idx (1+ idx))
  )
  (princ "\n  0. Next page")
  (princ "\n -1. Previous page")
  (princ "\n -9. Cancel")
  shown
)

(defun swdt-pick-dimstyle-by-number (/ names count pagesize page shown choice selected done absolute)
  (setq names (swdt-sorted-dimstyle-names))
  (setq count (length names))
  (setq pagesize 20)
  (setq page 0)
  (setq selected nil)
  (setq done nil)
  (cond
    ((= count 0)
      (princ "\nNo dimension styles found in this drawing.")
      nil
    )
    (T
      (while (not done)
        (setq shown (swdt-print-dimstyle-page names page pagesize))
        (initget 1)
        (setq choice (getint "\nDimension style number, 0 next, -1 previous, -9 cancel: "))
        (cond
          ((= choice -9)
            (setq done T)
          )
          ((= choice 0)
            (if (< (* (1+ page) pagesize) count)
              (setq page (1+ page))
              (princ "\nAlready at last page.")
            )
          )
          ((= choice -1)
            (if (> page 0)
              (setq page (1- page))
              (princ "\nAlready at first page.")
            )
          )
          ((and (>= choice 1) (<= choice shown))
            (setq absolute (+ (* page pagesize) choice -1))
            (setq selected (nth absolute names))
            (princ (strcat "\nSelected target style: " selected))
            (setq done T)
          )
          (T
            (princ "\nInvalid number on this page.")
          )
        )
      )
      selected
    )
  )
)

(defun swdt-string-replace-all (text old new / pos)
  (if (not (swdt-string-p text)) (setq text ""))
  (if (not (swdt-string-p old)) (setq old ""))
  (if (not (swdt-string-p new)) (setq new ""))
  (if (/= old "")
    (progn
      (while (setq pos (vl-string-search old text))
        (setq text
          (strcat
            (substr text 1 pos)
            new
            (substr text (+ pos (strlen old) 1))
          )
        )
      )
      text
    )
    text
  )
)

(defun swdt-mtext-plain (text / result idx len ch next)
  (setq result "")
  (if (not (swdt-string-p text)) (setq text ""))
  (if text
    (progn
      (setq idx 1)
      (setq len (strlen text))
      (while (<= idx len)
        (setq ch (substr text idx 1))
        (cond
          ((and (<= (+ idx 2) len) (= (strcase (substr text idx 3)) "%%P"))
            (setq result (strcat result "%%p"))
            (setq idx (+ idx 3))
          )
          ((= ch (chr 177))
            (setq result (strcat result "%%p"))
            (setq idx (1+ idx))
          )
          ((= ch "\\")
            (if (< idx len)
              (progn
                (setq next (substr text (1+ idx) 1))
                (cond
                  ((member next '("P" "p"))
                    (setq result (strcat result "/"))
                    (setq idx (+ idx 2))
                  )
                  ((member next '("S" "s"))
                    (setq idx (+ idx 2))
                    (while (and (<= idx len) (/= (substr text idx 1) ";"))
                      (setq ch (substr text idx 1))
                      (cond
                        ((or (= ch "^") (= ch "#"))
                          (setq result (strcat result "/"))
                        )
                        ((not (member ch '("{" "}")))
                          (setq result (strcat result ch))
                        )
                      )
                      (setq idx (1+ idx))
                    )
                    (if (<= idx len) (setq idx (1+ idx)))
                  )
                  ((member next '("A" "a" "C" "c" "F" "f" "H" "h" "Q" "q" "T" "t" "W" "w"))
                    (setq idx (+ idx 2))
                    (while (and (<= idx len) (/= (substr text idx 1) ";"))
                      (setq idx (1+ idx))
                    )
                    (if (<= idx len) (setq idx (1+ idx)))
                  )
                  ((member next '("{" "}"))
                    (setq idx (+ idx 2))
                  )
                  (T
                    (setq result (strcat result next))
                    (setq idx (+ idx 2))
                  )
                )
              )
              (setq idx (1+ idx))
            )
          )
          ((member ch '("{" "}"))
            (setq idx (1+ idx))
          )
          (T
            (setq result (strcat result ch))
            (setq idx (1+ idx))
          )
        )
      )
    )
  )
  result
)

(defun swdt-clean-tolerance-text (text / result idx ch)
  (setq result "")
  (if (not (swdt-string-p text)) (setq text ""))
  (setq text (swdt-mtext-plain text))
  (if text
    (progn
      (setq idx 1)
      (while (<= idx (strlen text))
        (setq ch (substr text idx 1))
        (if
          (not
            (member ch
              '(" " "\t" "\n" "\r" "{" "}" "(" ")" "[" "]" "<" ">" ";" ":")
            )
          )
          (setq result (strcat result ch))
        )
        (setq idx (1+ idx))
      )
    )
  )
  result
)

(defun swdt-alpha-char-p (ch / code)
  (if (and (swdt-string-p ch) (> (strlen ch) 0))
    (progn
      (setq code (ascii (substr ch 1 1)))
      (or
        (and (>= code 65) (<= code 90))
        (and (>= code 97) (<= code 122))
      )
    )
    nil
  )
)

(defun swdt-digit-char-p (ch / code)
  (if (and (swdt-string-p ch) (> (strlen ch) 0))
    (progn
      (setq code (ascii (substr ch 1 1)))
      (and (>= code 48) (<= code 57))
    )
    nil
  )
)

(defun swdt-single-fit-code-p (text / len idx letters digits ch)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq len (strlen text))
      (setq idx 1)
      (setq letters 0)
      (setq digits 0)
      (while (and (<= idx len) (swdt-alpha-char-p (substr text idx 1)))
        (setq letters (1+ letters))
        (setq idx (1+ idx))
      )
      (while (and (<= idx len) (swdt-digit-char-p (substr text idx 1)))
        (setq digits (1+ digits))
        (setq idx (1+ idx))
      )
      (and
        (= idx (1+ len))
        (>= letters 1)
        (<= letters 2)
        (>= digits 1)
        (<= digits 2)
      )
    )
  )
)

(defun swdt-paper-size-text-p (text / upper)
  (if (swdt-string-p text)
    (progn
      (setq upper (strcase text))
      (member upper '("A0" "A1" "A2" "A3" "A4" "A5"))
    )
    nil
  )
)

(defun swdt-count-char (text target / idx count)
  (if (not (swdt-string-p text)) (setq text ""))
  (setq idx 1)
  (setq count 0)
  (while (<= idx (strlen text))
    (if (= (substr text idx 1) target)
      (setq count (1+ count))
    )
    (setq idx (1+ idx))
  )
  count
)

(defun swdt-date-like-text-p (text / parts)
  (cond
    ((>= (swdt-count-char text "-") 2) T)
    ((>= (swdt-count-char text ".") 2) T)
    (T nil)
  )
)

(defun swdt-split-by-slash (text / pos)
  (if (not (swdt-string-p text))
    (list "")
    (progn
      (setq pos (vl-string-search "/" text))
      (if pos
        (list (substr text 1 pos) (substr text (+ pos 2)))
        (list text)
      )
    )
  )
)

(defun swdt-fit-code-from-clean (cleaned / parts)
  (if (not (swdt-string-p cleaned)) (setq cleaned ""))
  (cond
    ((= cleaned "") nil)
    ((swdt-paper-size-text-p cleaned) nil)
    ((swdt-date-like-text-p cleaned) nil)
    ((vl-string-search "/" cleaned)
      (setq parts (swdt-split-by-slash cleaned))
      (if
        (and
          (= (length parts) 2)
          (swdt-single-fit-code-p (car parts))
          (swdt-single-fit-code-p (cadr parts))
        )
        cleaned
        nil
      )
    )
    ((swdt-single-fit-code-p cleaned) cleaned)
    (T nil)
  )
)

(defun swdt-fit-code-from-text (text)
  (if (swdt-string-p text)
    (swdt-fit-code-from-clean (swdt-clean-tolerance-text text))
    nil
  )
)

(defun swdt-fit-simple-alpha-p (ch / code)
  (setq code (ascii ch))
  (or
    (and (>= code 65) (<= code 90))
    (and (>= code 97) (<= code 122))
  )
)

(defun swdt-fit-simple-digit-p (ch / code)
  (setq code (ascii ch))
  (and (>= code 48) (<= code 57))
)

(defun swdt-fit-code-simple (text / raw cleaned len idx ch start letters digits)
  (setq text (swdt-text-value-string text))
  (setq raw text)
  (setq cleaned "")
  (setq idx 1)
  (while (<= idx (strlen raw))
    (setq ch (substr raw idx 1))
    (if
      (not
        (member ch
          '(" " "\t" "\n" "\r" "{" "}" "(" ")" "[" "]" "<" ">" ";" ":")
        )
      )
      (setq cleaned (strcat cleaned ch))
    )
    (setq idx (1+ idx))
  )
  (if (and (>= (strlen cleaned) 3) (equal (strcase (substr cleaned 1 3)) "%%C"))
    (setq cleaned (substr cleaned 4))
  )
  (setq len (strlen cleaned))
  (setq idx 1)
  (while (and (<= idx len) (not (swdt-fit-simple-alpha-p (substr cleaned idx 1))))
    (setq idx (1+ idx))
  )
  (setq start idx)
  (setq letters 0)
  (while (and (<= idx len) (swdt-fit-simple-alpha-p (substr cleaned idx 1)) (< letters 2))
    (setq letters (1+ letters))
    (setq idx (1+ idx))
  )
  (setq digits 0)
  (while (and (<= idx len) (swdt-fit-simple-digit-p (substr cleaned idx 1)) (< digits 2))
    (setq digits (1+ digits))
    (setq idx (1+ idx))
  )
  (if (and
        (>= letters 1)
        (<= letters 2)
        (>= digits 1)
        (<= digits 2)
        (> start 0)
      )
    (substr cleaned start (+ letters digits))
    nil
  )
)

(defun swdt-string-has-digit-p (text / idx found)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq idx 1)
      (setq found nil)
      (while (and (not found) (<= idx (strlen text)))
        (if (swdt-digit-char-p (substr text idx 1))
          (setq found T)
        )
        (setq idx (1+ idx))
      )
      found
    )
  )
)

(defun swdt-decimal-number-text-p (text / idx len ch ok digit)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq idx 1)
      (setq len (strlen text))
      (setq ok (> len 0))
      (setq digit nil)
      (while (and ok (<= idx len))
        (setq ch (substr text idx 1))
        (cond
          ((swdt-digit-char-p ch) (setq digit T))
          ((member ch '("." ",")) nil)
          (T (setq ok nil))
        )
        (setq idx (1+ idx))
      )
      (and ok digit)
    )
  )
)

(defun swdt-zero-number-text-p (text / idx nonzero)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq idx 1)
      (setq nonzero nil)
      (while (and (not nonzero) (<= idx (strlen text)))
        (if (member (substr text idx 1) '("1" "2" "3" "4" "5" "6" "7" "8" "9"))
          (setq nonzero T)
        )
        (setq idx (1+ idx))
      )
      (and (swdt-decimal-number-text-p text) (not nonzero))
    )
  )
)

(defun swdt-has-decimal-sep-p (text)
  (and
    (swdt-string-p text)
    (or (vl-string-search "." text) (vl-string-search "," text))
  )
)

(defun swdt-slash-zero-tolerance-p (text / parts first second)
  (if (and (swdt-string-p text) (vl-string-search "/" text))
    (progn
      (setq parts (swdt-split-by-slash text))
      (if (= (length parts) 2)
        (progn
          (setq first (car parts))
          (setq second (cadr parts))
          (and
            (swdt-decimal-number-text-p first)
            (swdt-decimal-number-text-p second)
            (or (swdt-zero-number-text-p first) (swdt-zero-number-text-p second))
            (or (swdt-has-decimal-sep-p first) (swdt-has-decimal-sep-p second))
          )
        )
        nil
      )
    )
    nil
  )
)

(defun swdt-string-has-tol-sign-p (text)
  (and
    (swdt-string-p text)
    (or
      (vl-string-search "%%P" (strcase text))
      (vl-string-search "+" text)
      (vl-string-search "-" text)
    )
  )
)

(defun swdt-numeric-tolerance-p (text / idx len ch ok)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq idx 1)
      (setq len (strlen text))
      (setq ok T)
      (while (and ok (<= idx len))
        (setq ch (substr text idx 1))
        (cond
          ((swdt-digit-char-p ch) nil)
          ((member ch '("." "," "+" "-" "/" "%")) nil)
          ((member ch '("P" "p")) nil)
          (T (setq ok nil))
        )
        (setq idx (1+ idx))
      )
      (and
        ok
        (> len 0)
        (<= len 40)
        (not (swdt-date-like-text-p text))
        (not (swdt-paper-size-text-p text))
        (swdt-string-has-digit-p text)
        (or
          (swdt-string-has-tol-sign-p text)
          (swdt-slash-zero-tolerance-p text)
        )
      )
    )
  )
)

(defun swdt-first-tol-sign-pos (text / idx len ch found)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq idx 1)
      (setq len (strlen text))
      (setq found nil)
      (while (and (not found) (<= idx len))
        (setq ch (substr text idx 1))
        (if (or (= ch "+") (= ch "-") (= ch "%"))
          (setq found idx)
        )
        (setq idx (1+ idx))
      )
      found
    )
  )
)

(defun swdt-composite-tolerance-p (text / pos prefix suffix)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq pos (swdt-first-tol-sign-pos text))
      (if (and pos (> pos 1))
        (progn
          (setq prefix (substr text 1 (1- pos)))
          (setq suffix (substr text pos))
          (and
            (swdt-fit-code-from-clean prefix)
            (swdt-numeric-tolerance-p suffix)
          )
        )
        nil
      )
    )
  )
)

(defun swdt-tolerance-token-from-text (text / cleaned fit)
  (if (not (swdt-string-p text))
    nil
    (progn
      (setq cleaned (swdt-clean-tolerance-text text))
      (setq fit (swdt-fit-code-from-clean cleaned))
      (cond
        ((swdt-date-like-text-p cleaned) nil)
        ((swdt-paper-size-text-p cleaned) nil)
        (fit fit)
        ((swdt-numeric-tolerance-p cleaned) cleaned)
        ((swdt-composite-tolerance-p cleaned) cleaned)
        (T nil)
      )
    )
  )
)

(defun swdt-token-fit-only-p (token)
  (and
    (swdt-string-p token)
    (swdt-fit-code-from-clean token)
    (not (swdt-numeric-tolerance-p token))
    (not (swdt-composite-tolerance-p token))
  )
)

(defun swdt-nonzero-p (value)
  (and value (not (equal (float value) 0.0 1e-12)))
)

(defun swdt-dim-has-tolerance-p (data / values)
  (setq values (swdt-effective-tolerance-values data))
  (or
    (= (cdr (assoc 71 values)) 1)
    (= (cdr (assoc 72 values)) 1)
    (swdt-nonzero-p (cdr (assoc 47 values)))
    (swdt-nonzero-p (cdr (assoc 48 values)))
  )
)


(defun swdt-entity-point (data)
  (cond
    ((assoc 11 data) (cdr (assoc 11 data)))
    ((assoc 10 data) (cdr (assoc 10 data)))
    (T nil)
  )
)

(defun swdt-contains-ci-p (text token)
  (if (and (swdt-string-p text) (swdt-string-p token) (vl-string-search (strcase token) (strcase text)))
    T
    nil
  )
)

(defun swdt-merge-token-into-dim (dim token / data old new ok)
  (setq data (entget dim '("ACAD")))
  (setq old (swdt-safe-string (cdr (assoc 1 data))))
  (cond
    ((and old (swdt-contains-ci-p old token))
      (setq new old)
    )
    ((or (not old) (= old "") (= old "<>"))
      (setq new (strcat "<> " token))
    )
    ((vl-string-search "<>" old)
      (setq new (strcat old " " token))
    )
    (T
      (setq new (strcat old " " token))
    )
  )
  (setq data (swdt-dxf-put data 1 new))
  (setq ok (entmod data))
  (if ok (entupd dim))
  ok
)

(defun swdt-nearest-dim (pt dims maxdist requiretol / best bestd d item)
  (setq best nil)
  (setq bestd maxdist)
  (foreach item dims
    (if (and pt (cadr item) (or (not requiretol) (caddr item)))
      (progn
        (setq d (distance pt (cadr item)))
        (if (<= d bestd)
          (progn
            (setq best (car item))
            (setq bestd d)
          )
        )
      )
    )
  )
  best
)


(defun swdt-dist-text (value)
  (if value (rtos value 2 2) "n/a")
)

(defun swdt-current-space-tol-ss ()
  (ssget "_X" (list '(0 . "DIMENSION,TEXT,MTEXT") (cons 410 (getvar "CTAB"))))
)




(defun swdt-inc-alist (key alist / item)
  (setq item (assoc key alist))
  (if item
    (subst (cons key (1+ (cdr item))) item alist)
    (append alist (list (cons key 1)))
  )
)

(defun swdt-entity-handle (ent / data)
  (setq data (entget ent))
  (if (assoc 5 data)
    (cdr (assoc 5 data))
    "?"
  )
)

(defun swdt-style-pattern-normalize (value / pattern)
  (setq pattern (swdt-text-value-string value))
  (if (= pattern "")
    (setq pattern "*SLDDIMSTYLE*")
  )
  (if (and
        (not (vl-string-search "*" pattern))
        (not (vl-string-search "?" pattern))
      )
    (setq pattern (strcat "*" pattern "*"))
  )
  pattern
)

(defun swdt-dimstyle-match-p (style pattern)
  (and
    (swdt-string-p style)
    (swdt-string-p pattern)
    (wcmatch (strcase style) (strcase pattern))
  )
)

(defun swdt-dimstyle-names-matching (pattern / result name)
  (setq result nil)
  (foreach name (swdt-dimstyle-names)
    (if (swdt-dimstyle-match-p name pattern)
      (setq result (append result (list name)))
    )
  )
  result
)

(defun swdt-print-limited-list (items limit prefix / idx item hidden)
  (setq idx 0)
  (foreach item items
    (if (< idx limit)
      (princ (strcat "\n" prefix item))
    )
    (setq idx (1+ idx))
  )
  (setq hidden (- (length items) limit))
  (if (> hidden 0)
    (princ (strcat "\n" prefix "More hidden: " (itoa hidden)))
  )
)

(defun swdt-scan-layout-dimstyle-usage (pattern / ss idx ent data style tab ctab total currentss currentcount counts examples key currentstyle)
  (setq ss (ssget "_X" '((0 . "DIMENSION"))))
  (setq ctab (getvar "CTAB"))
  (setq total 0)
  (setq currentcount 0)
  (setq currentss (ssadd))
  (setq counts nil)
  (setq examples nil)
  (setq currentstyle (swdt-safe-call 'getvar (list "DIMSTYLE")))
  (if ss
    (progn
      (setq idx 0)
      (while (< idx (sslength ss))
        (setq ent (ssname ss idx))
        (setq data (entget ent))
        (setq style (cdr (assoc 3 data)))
        (setq tab (cdr (assoc 410 data)))
        (if (swdt-dimstyle-match-p style pattern)
          (progn
            (setq total (1+ total))
            (setq key (strcat (swdt-princ-string tab) " / " style))
            (setq counts (swdt-inc-alist key counts))
            (if (equal tab ctab)
              (progn
                (ssadd ent currentss)
                (setq currentcount (1+ currentcount))
              )
            )
            (if (< (length examples) 12)
              (setq examples
                (append examples
                  (list
                    (strcat
                      "#"
                      (swdt-entity-handle ent)
                      " tab="
                      (swdt-princ-string tab)
                      " style="
                      style
                    )
                  )
                )
              )
            )
          )
        )
        (setq idx (1+ idx))
      )
    )
  )
  (list total currentcount currentss counts examples currentstyle)
)

(defun swdt-layout-block-name-p (name / upper)
  (setq upper (strcase (swdt-princ-string name)))
  (or
    (wcmatch upper "`*MODEL_SPACE*")
    (wcmatch upper "`*PAPER_SPACE*")
  )
)

(defun swdt-scan-block-dimstyle-usage (pattern / blk bname ent data style total counts examples key done)
  (setq total 0)
  (setq counts nil)
  (setq examples nil)
  (setq blk (swdt-safe-tblnext "BLOCK" T))
  (while blk
    (setq bname (cdr (assoc 2 blk)))
    (if (not (swdt-layout-block-name-p bname))
      (progn
        (setq ent (cdr (assoc -2 blk)))
        (setq done nil)
        (while (and ent (not done))
          (setq data (swdt-safe-entget ent nil))
          (cond
            ((equal (cdr (assoc 0 data)) "ENDBLK")
              (setq done T)
            )
            (T
              (if (and
                    (equal (cdr (assoc 0 data)) "DIMENSION")
                    (swdt-dimstyle-match-p (cdr (assoc 3 data)) pattern)
                  )
                (progn
                  (setq style (cdr (assoc 3 data)))
                  (setq total (1+ total))
                  (setq key (strcat (swdt-princ-string bname) " / " style))
                  (setq counts (swdt-inc-alist key counts))
                  (if (< (length examples) 12)
                    (setq examples
                      (append examples
                        (list
                          (strcat
                            "block="
                            (swdt-princ-string bname)
                            " #"
                            (swdt-entity-handle ent)
                            " style="
                            style
                          )
                        )
                      )
                    )
                  )
                )
              )
              (setq ent (entnext ent))
            )
          )
        )
      )
    )
    (setq blk (swdt-safe-tblnext "BLOCK" nil))
  )
  (list total counts examples)
)

(defun swdt-print-style-counts (title counts / pair)
  (if counts
    (progn
      (princ title)
      (foreach pair counts
        (princ (strcat "\n    " (car pair) ": " (itoa (cdr pair))))
      )
    )
  )
)

(setq *swdt-deep-targets* nil)
(setq *swdt-deep-target-handles* nil)
(setq *swdt-deep-regapps* nil)
(setq *swdt-deep-total* 0)
(setq *swdt-deep-examples* nil)
(setq *swdt-deep-visited* nil)
(setq *swdt-deep-limit* 30)

(defun swdt-target-style-pairs (names / result name ent handle data)
  (setq result nil)
  (foreach name names
    (setq ent (swdt-safe-tblobjname "DIMSTYLE" name))
    (setq handle nil)
    (if ent
      (progn
        (setq data (swdt-safe-entget ent nil))
        (setq handle (cdr (assoc 5 data)))
      )
    )
    (setq result (append result (list (list name ent handle))))
  )
  result
)

(defun swdt-safe-tblnext (table reset / result)
  (setq result
    (vl-catch-all-apply
      'tblnext
      (if reset (list table T) (list table))
    )
  )
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swdt-safe-tblobjname (table name / result)
  (setq result (vl-catch-all-apply 'tblobjname (list table name)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swdt-safe-entget (ent apps / result)
  (setq result
    (vl-catch-all-apply
      'entget
      (if apps (list ent apps) (list ent))
    )
  )
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swdt-deep-target-record-p (ent / handle found item data)
  (setq found nil)
  (if ent
    (progn
      (setq data (swdt-safe-entget ent nil))
      (setq handle (cdr (assoc 5 data)))
      (foreach item *swdt-deep-targets*
        (if (and handle (equal handle (caddr item)))
          (setq found T)
        )
      )
    )
  )
  found
)

(defun swdt-deep-record-hit (label hit)
  (setq *swdt-deep-total* (1+ *swdt-deep-total*))
  (if (< (length *swdt-deep-examples*) *swdt-deep-limit*)
    (setq *swdt-deep-examples*
      (append *swdt-deep-examples* (list (strcat label " / " hit)))
    )
  )
)

(defun swdt-style-ref-hit-lines-from-value (code value / result target name targetent targethandle sval sub subcode subvalue)
  (setq result nil)
  (cond
    ((listp value)
      (foreach sub value
        (if (and (listp sub) (not (null sub)))
          (progn
            (if (numberp (car sub))
              (progn
                (setq subcode (car sub))
                (setq subvalue (cdr sub))
              )
              (progn
                (setq subcode code)
                (setq subvalue sub)
              )
            )
            (setq result
              (append result (swdt-style-ref-hit-lines-from-value subcode subvalue))
            )
          )
          (setq result
            (append result (swdt-style-ref-hit-lines-from-value code sub))
          )
        )
      )
    )
    (T
      (foreach target *swdt-deep-targets*
        (setq name (car target))
        (setq targetent (cadr target))
        (setq targethandle (caddr target))
        (cond
          ((and targetent (equal value targetent))
            (setq result
              (append result
                (list (strcat "pointer code " (itoa code) " -> " name))
              )
            )
          )
          ((and targethandle (swdt-string-p value) (equal (strcase value) (strcase targethandle)))
            (setq result
              (append result
                (list (strcat "handle string code " (itoa code) " -> " name))
              )
            )
          )
          ((swdt-string-p value)
            (setq sval (strcase value))
            (if (vl-string-search (strcase name) sval)
              (setq result
                (append result
                  (list
                    (strcat
                      "string code "
                      (itoa code)
                      " contains "
                      name
                      ": "
                      (if (> (strlen value) 80)
                        (strcat (substr value 1 80) "...")
                        value
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swdt-style-ref-hit-lines (data / result item code value)
  (setq result nil)
  (foreach item data
    (setq code (car item))
    (setq value (cdr item))
    (setq result
      (append result (swdt-style-ref-hit-lines-from-value code value))
    )
  )
  result
)

(defun swdt-deep-scan-data (label data / hits hit)
  (setq hits (swdt-style-ref-hit-lines data))
  (foreach hit hits
    (swdt-deep-record-hit label hit)
  )
)

(defun swdt-deep-scan-ename (ent label / data handle result type)
  (if (and ent (not (swdt-deep-target-record-p ent)))
    (progn
      (setq data (swdt-safe-entget ent nil))
      (setq handle (cdr (assoc 5 data)))
      (if (not (member handle *swdt-deep-visited*))
        (progn
          (setq *swdt-deep-visited* (append *swdt-deep-visited* (list handle)))
          (setq result (if *swdt-deep-regapps* (swdt-safe-entget ent *swdt-deep-regapps*) nil))
          (if result (setq data result))
          (setq type (cdr (assoc 0 data)))
          (swdt-deep-scan-data
            (strcat label " type=" (swdt-princ-string type) " #" (swdt-princ-string handle))
            data
          )
        )
      )
    )
  )
)

(defun swdt-deep-scan-main-entities (/ result ent)
  (setq result (vl-catch-all-apply 'entnext nil))
  (if (not (vl-catch-all-error-p result))
    (progn
      (setq ent result)
      (while ent
        (swdt-deep-scan-ename ent "DB_ENTITY")
        (setq ent (entnext ent))
      )
    )
  )
)

(defun swdt-deep-scan-block-entities (/ blk bname ent done data)
  (setq blk (swdt-safe-tblnext "BLOCK" T))
  (while blk
    (setq bname (cdr (assoc 2 blk)))
    (if (not (swdt-layout-block-name-p bname))
      (progn
        (setq ent (cdr (assoc -2 blk)))
        (setq done nil)
        (while (and ent (not done))
          (setq data (swdt-safe-entget ent nil))
          (if (equal (cdr (assoc 0 data)) "ENDBLK")
            (setq done T)
            (progn
              (swdt-deep-scan-ename ent (strcat "BLOCK " (swdt-princ-string bname)))
              (setq ent (entnext ent))
            )
          )
        )
      )
    )
    (setq blk (swdt-safe-tblnext "BLOCK" nil))
  )
)

(defun swdt-deep-scan-vla-dict-items (dict label depth / child childlabel objname name handle ent)
  (if (< depth 4)
    (vlax-for child dict
      (setq objname (swdt-safe-prop child 'ObjectName))
      (setq name (swdt-safe-prop child 'Name))
      (setq childlabel
        (strcat
          label
          "/"
          (swdt-princ-string objname)
          ":"
          (swdt-princ-string name)
        )
      )
      (setq handle (swdt-safe-prop child 'Handle))
      (if handle
        (progn
          (setq ent (handent (swdt-dump-value-string handle)))
          (if ent
            (swdt-deep-scan-ename ent childlabel)
          )
        )
      )
      (if (and objname (vl-string-search "DICTIONARY" (strcase (swdt-princ-string objname))))
        (vl-catch-all-apply 'swdt-deep-scan-vla-dict-items (list child childlabel (1+ depth)))
      )
    )
  )
)

(defun swdt-deep-scan-dictionaries (/ doc dicts dict label handle ent result)
  (setq doc (swdt-doc))
  (setq dicts (swdt-safe-method 'vla-get-Dictionaries (list doc)))
  (if dicts
    (vlax-for dict dicts
      (setq label
        (strcat
          "DICTIONARY "
          (swdt-princ-string (swdt-safe-prop dict 'Name))
        )
      )
      (setq handle (swdt-safe-prop dict 'Handle))
      (if handle
        (progn
          (setq ent (handent (swdt-dump-value-string handle)))
          (if ent
            (swdt-deep-scan-ename ent label)
          )
        )
      )
      (setq result (vl-catch-all-apply 'swdt-deep-scan-vla-dict-items (list dict label 0)))
    )
  )
)

(defun swdt-deep-style-reference-scan (names / result)
  (setq *swdt-deep-targets* (swdt-target-style-pairs names))
  (setq *swdt-deep-regapps* nil)
  (setq *swdt-deep-total* 0)
  (setq *swdt-deep-examples* nil)
  (setq *swdt-deep-visited* nil)
  (vl-catch-all-apply 'swdt-deep-scan-main-entities nil)
  (vl-catch-all-apply 'swdt-deep-scan-block-entities nil)
  (vl-catch-all-apply 'swdt-deep-scan-dictionaries nil)
  (setq result (list *swdt-deep-total* *swdt-deep-examples*))
  (setq *swdt-deep-targets* nil)
  (setq *swdt-deep-regapps* nil)
  (setq *swdt-deep-visited* nil)
  result
)



(defun swdt-regapp-names ()
  '("ACAD" "GENIUS_GENDTOL_13")
)


(defun swdt-string-prefix-p (prefix text)
  (and
    prefix
    text
    (<= (strlen prefix) (strlen text))
    (= prefix (substr text 1 (strlen prefix)))
  )
)






(defun swdt-dump-value-string (value / typ converted)
  (cond
    ((null value) "<nil>")
    ((eq (type value) 'VARIANT)
      (swdt-dump-value-string (vlax-variant-value value))
    )
    ((eq (type value) 'SAFEARRAY)
      (setq converted (vl-catch-all-apply 'vlax-safearray->list (list value)))
      (if (vl-catch-all-error-p converted)
        "<safearray-unreadable>"
        (vl-princ-to-string converted)
      )
    )
    (T (vl-princ-to-string value))
  )
)

(defun swdt-safe-prop (obj prop / result)
  (setq result (vl-catch-all-apply 'vlax-get-property (list obj prop)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swdt-safe-method (fn args / result)
  (setq result (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swdt-write-vla-summary (f obj label / objname name handle)
  (write-line (strcat label ":") f)
  (setq objname (swdt-safe-prop obj 'ObjectName))
  (setq name (swdt-safe-prop obj 'Name))
  (setq handle (swdt-safe-prop obj 'Handle))
  (write-line (strcat "  ObjectName=" (swdt-dump-value-string objname)) f)
  (write-line (strcat "  Name=" (swdt-dump-value-string name)) f)
  (write-line (strcat "  Handle=" (swdt-dump-value-string handle)) f)
  handle
)

(defun swdt-write-entget-by-handle (f handle label / ent data apps item)
  (if handle
    (progn
      (setq ent (handent (swdt-dump-value-string handle)))
      (write-line (strcat label ":") f)
      (if ent
        (progn
          (setq apps (swdt-regapp-names))
          (setq data (if apps (entget ent apps) (entget ent)))
          (foreach item data
            (write-line (strcat "  " (vl-princ-to-string item)) f)
          )
        )
        (write-line "  <handle not found by handent>" f)
      )
    )
  )
)

(defun swdt-write-extension-dict-items (f dict / idx child handle)
  (setq idx 0)
  (vlax-for child dict
    (setq idx (1+ idx))
    (setq handle (swdt-write-vla-summary f child (strcat "EXTDICT_ITEM_" (itoa idx))))
    (swdt-write-entget-by-handle f handle (strcat "EXTDICT_ITEM_" (itoa idx) "_ENTGET"))
  )
  (if (= idx 0)
    (write-line "  <extension dictionary has no enumerable items>" f)
  )
  idx
)

(defun swdt-write-extension-dict (f ent / obj hasdict dict handle result)
  (write-line "EXTENSION_DICTIONARY:" f)
  (setq obj (vlax-ename->vla-object ent))
  (setq hasdict (swdt-safe-prop obj 'HasExtensionDictionary))
  (write-line (strcat "  HasExtensionDictionary=" (swdt-dump-value-string hasdict)) f)
  (if (or (= hasdict :vlax-true) (= hasdict T))
    (progn
      (setq dict (swdt-safe-method 'vla-GetExtensionDictionary (list obj)))
      (if dict
        (progn
          (setq handle (swdt-write-vla-summary f dict "EXTDICT_OBJECT"))
          (swdt-write-entget-by-handle f handle "EXTDICT_OBJECT_ENTGET")
          (setq result (vl-catch-all-apply 'swdt-write-extension-dict-items (list f dict)))
          (if (vl-catch-all-error-p result)
            (write-line (strcat "  <could not enumerate extension dictionary: " (vl-catch-all-error-message result) ">") f)
          )
        )
        (write-line "  <GetExtensionDictionary failed>" f)
      )
    )
    (write-line "  <no extension dictionary visible through COM>" f)
  )
)

(defun swdt-trim-tol-real (value / s)
  (setq s (rtos (abs (float value)) 2 6))
  (setq s (vl-string-right-trim "0" s))
  (if (and (> (strlen s) 0) (= (substr s (strlen s) 1) "."))
    (setq s (substr s 1 (1- (strlen s))))
  )
  (if (= s "") "0" s)
)

(defun swdt-zero-real-p (value)
  (or (not value) (equal (float value) 0.0 1e-12))
)

(defun swdt-leading-fit-code-from-tail (tail / cleaned len idx ch start letters digits candidate)
  (setq cleaned (swdt-mtext-plain (swdt-text-value-string tail)))
  (setq cleaned (vl-string-left-trim " \t\r\n{}()[]<>;:" cleaned))
  (if (and (>= (strlen cleaned) 3) (equal (strcase (substr cleaned 1 3)) "%%C"))
    (setq cleaned (vl-string-left-trim " \t\r\n{}()[]<>;:" (substr cleaned 4)))
  )
  (setq len (strlen cleaned))
  (setq idx 1)
  (setq letters 0)
  (setq digits 0)
  (while (and (<= idx len) (swdt-alpha-char-p (substr cleaned idx 1)) (< letters 2))
    (setq letters (1+ letters))
    (setq idx (1+ idx))
  )
  (while (and (<= idx len) (swdt-digit-char-p (substr cleaned idx 1)) (< digits 2))
    (setq digits (1+ digits))
    (setq idx (1+ idx))
  )
  (if (and (>= letters 1) (<= letters 2) (>= digits 1) (<= digits 2))
    (progn
      (setq candidate (substr cleaned 1 (+ letters digits)))
      (if (swdt-single-fit-code-p candidate) candidate nil)
    )
    nil
  )
)

(defun swdt-dim-fit-code-from-data (data / text pos tail token)
  (setq text (swdt-text-value-string (cdr (assoc 1 data))))
  (setq token nil)
  (if (/= text "")
    (progn
      (setq pos (vl-string-search "<>" text))
      (if pos
        (progn
          (setq tail (substr text (+ pos 3)))
          (setq token (swdt-leading-fit-code-from-tail tail))
        )
        (setq pos nil)
      )
      (if (and (not token) (not pos))
        (progn
          (setq token (swdt-fit-code-simple text))
          (if (not token)
            (setq token (swdt-fit-code-from-text text))
          )
        )
      )
    )
  )
  token
)

(defun swdt-dim-display-prefix (data / text)
  (setq text (swdt-safe-string (cdr (assoc 1 data))))
  (if (and text (vl-string-search "%%C" (strcase text)))
    "%%C<>"
    "<>"
  )
)

(defun swdt-mechfit-default-style ()
  (cond
    ((tblsearch "DIMSTYLE" "AM_ISO$0") "AM_ISO$0")
    ((tblsearch "DIMSTYLE" "AM_ISO") "AM_ISO")
    ((tblsearch "DIMSTYLE" "ISO-25") "ISO-25")
    (T nil)
  )
)

(defun swdt-style-or-override-value (data code / style styledata overrides)
  (setq overrides (swdt-get-dstyle-overrides data))
  (setq style (swdt-safe-string (cdr (assoc 3 data))))
  (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
  (cond
    ((assoc code overrides) (cdr (assoc code overrides)))
    ((assoc code data) (cdr (assoc code data)))
    ((and styledata (assoc code styledata)) (cdr (assoc code styledata)))
    (T nil)
  )
)

(defun swdt-dimstyle-or-override-value (data code / style styledata overrides)
  (setq overrides (swdt-get-dstyle-overrides data))
  (setq style (swdt-safe-string (cdr (assoc 3 data))))
  (setq styledata (if style (tblsearch "DIMSTYLE" style) nil))
  (cond
    ((assoc code overrides) (cdr (assoc code overrides)))
    ((and styledata (assoc code styledata)) (cdr (assoc code styledata)))
    (T nil)
  )
)

(defun swdt-positive-real-p (value)
  (and value (numberp value) (> (float value) 0.0))
)

(defun swdt-dim-linear-scale (ent data / obj value)
  (setq value (swdt-dimstyle-or-override-value data 144))
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    (progn
      (setq obj (vlax-ename->vla-object ent))
      (setq value (swdt-safe-prop obj 'LinearScaleFactor))
    )
  )
  (if (or (not value) (not (numberp value)) (equal (float value) 0.0 1e-12))
    1.0
    (float value)
  )
)

(defun swdt-dim-point-distance-measurement (data / p1 p2 d)
  (setq p1 (cdr (assoc 13 data)))
  (setq p2 (cdr (assoc 14 data)))
  (if (and p1 p2)
    (progn
      (setq d (distance p1 p2))
      (if (swdt-positive-real-p d)
        (float d)
        nil
      )
    )
    nil
  )
)

(defun swdt-dim-raw-measurement (ent data / obj value fallback)
  (setq obj (vlax-ename->vla-object ent))
  (setq value (swdt-safe-prop obj 'Measurement))
  (if (or (not value) (not (numberp value)) (<= (float value) 0.0))
    (setq value (cdr (assoc 42 data)))
  )
  (if (or (not value) (not (numberp value)) (<= (float value) 0.0))
    (progn
      (setq fallback (swdt-dim-point-distance-measurement data))
      (if fallback
        (setq value fallback)
      )
    )
  )
  (if (swdt-positive-real-p value)
    (float value)
    0.0
  )
)

(defun swdt-dim-measurement (ent data / raw dimlfac)
  (setq raw (swdt-dim-raw-measurement ent data))
  (setq dimlfac (swdt-dim-linear-scale ent data))
  (if (swdt-positive-real-p raw)
    (* raw dimlfac)
    0.0
  )
)

(defun swdt-mech-fit-tolstack (upper lower / up low)
  (setq up (swdt-trim-tol-real upper))
  (setq low (swdt-trim-tol-real lower))
  (cond
    ((and (swdt-zero-real-p upper) (not (swdt-zero-real-p lower)))
      (strcat "-\\S0^" low ";")
    )
    ((and (not (swdt-zero-real-p upper)) (swdt-zero-real-p lower))
      (strcat "+\\S" up "^0;")
    )
    ((and (swdt-zero-real-p upper) (swdt-zero-real-p lower))
      "\\S0^0;"
    )
    (T
      (strcat "\\S+" up "^-" low ";")
    )
  )
)

(defun swdt-mech-fit-template (upper lower / sign)
  (setq sign
    (cond
      ((and (swdt-zero-real-p upper) (not (swdt-zero-real-p lower))) "$-")
      ((and (not (swdt-zero-real-p upper)) (swdt-zero-real-p lower)) "$+")
      (T "")
    )
  )
  (strcat "{$3 $T$2{\\H1.42x;\\W0.5;(}{\\A0;\\H0.71x;" sign "\\S$P^$M;}{\\H1.42x;\\W0.5;)}}")
)

(defun swdt-mech-fit-display (prefix fit upper lower)
  (strcat prefix "}{}{\\C2; " fit "\\C3;{\\H1.42x;\\W0.5;(}{\\A0;\\H0.71x;" (swdt-mech-fit-tolstack upper lower) "}{\\H1.42x;\\W0.5;)}}")
)

(defun swdt-mech-dstyle-pairs (data upper lower dimlfac / result code value dimtfac)
  (setq result
    (list
      (cons 1000 "DSTYLE")
      (cons 1002 "{")
      (cons 1070 274)
      (cons 1070 5)
      (cons 1070 4)
      (cons 1000 "")
    )
  )
  (foreach code '(40 41 42 43 44 46 140 141 142 147)
    (setq value (swdt-dimstyle-or-override-value data code))
    (if (and (numberp value) (swdt-preserve-dstyle-override-p code value))
      (setq result
        (append result
          (list
            (cons 1070 code)
            (cons 1040 (float value))
          )
        )
      )
    )
  )
  (setq dimtfac (swdt-dimstyle-or-override-value data 146))
  (if (not (numberp dimtfac)) (setq dimtfac 1.0))
  (append result
    (list
      (cons 1070 144)
      (cons 1040 (float dimlfac))
      (cons 1070 146)
      (cons 1040 (float dimtfac))
      (cons 1070 48)
      (cons 1040 (float lower))
      (cons 1070 47)
      (cons 1040 (float upper))
      (cons 1002 "}")
    )
  )
)

(defun swdt-set-acad-dstyle-raw (data dstyle / apps newapps app newpairs name)
  (setq apps (swdt-xdata-apps data))
  (setq newapps nil)
  (foreach app apps
    (setq name (swdt-xdata-app-name app))
    (if (and name (equal name "ACAD"))
      (progn
        (setq newpairs (swdt-remove-dstyle-section (cdr app)))
        (setq newpairs (append newpairs dstyle))
        (setq newapps (append newapps (list (cons "ACAD" newpairs))))
      )
      (if name
        (setq newapps (append newapps (list app)))
      )
    )
  )
  (if (not (swdt-acad-app apps))
    (setq newapps (append newapps (list (cons "ACAD" dstyle))))
  )
  (append (swdt-remove-xdata data) (list (cons -3 newapps)))
)

(defun swdt-set-xdata-app-raw (data app / apps newapps old appname item itemname)
  (setq appname (car app))
  (setq apps (swdt-xdata-apps data))
  (setq newapps nil)
  (setq old nil)
  (foreach item apps
    (setq itemname (swdt-xdata-app-name item))
    (if (and itemname (equal itemname appname))
      (setq old T)
      (if itemname
        (setq newapps (append newapps (list item)))
      )
    )
  )
  (setq newapps (append newapps (list app)))
  (append (swdt-remove-xdata data) (list (cons -3 newapps)))
)

(defun swdt-mech-genius-app (fit upper lower measurement)
  (cons
    "GENIUS_GENDTOL_13"
    (list
      (cons 1000 "FitGBStd")
      (cons 1000 (if (swdt-string-p fit) fit ""))
      (cons 1000 (swdt-mech-fit-template upper lower))
      (cons 1040 (float measurement))
    )
  )
)

(defun swdt-mechfit-entget (ent)
  (entget ent '("ACAD" "GENIUS_GENDTOL_13"))
)

(defun swdt-apply-mech-fit-to-dim (ent fit targetstyle / data values upper lower measurement dimlfac prefix newtext dstyle newdata ok basedata okbase data2 okgen)
  (swdt-mechfit-stage "apply:start")
  (if (not (swdt-string-p fit))
    (list nil 0.0 0.0 0.0 "" nil nil)
    (progn
      (swdt-mechfit-stage "apply:entget")
      (setq data (swdt-mechfit-entget ent))
      (swdt-mechfit-stage "apply:effective-tolerance-values")
      (setq values (swdt-effective-tolerance-values data))
      (setq upper (cdr (assoc 47 values)))
      (setq lower (cdr (assoc 48 values)))
      (if (not upper) (setq upper 0.0))
      (if (not lower) (setq lower 0.0))
      (swdt-mechfit-stage "apply:measurement")
      (setq dimlfac (swdt-dim-linear-scale ent data))
      (setq measurement (swdt-dim-measurement ent data))
      (swdt-mechfit-stage "apply:display-prefix")
      (setq prefix (swdt-dim-display-prefix data))
      (swdt-mechfit-stage "apply:display-string")
      (setq newtext (swdt-mech-fit-display prefix fit upper lower))
      (swdt-mechfit-stage "apply:dstyle-pairs")
      (setq dstyle (swdt-mech-dstyle-pairs data upper lower dimlfac))
      (swdt-mechfit-stage "apply:combined-build")
      (setq newdata (swdt-dxf-put data 1 newtext))
      (if (and (swdt-string-p targetstyle) (tblsearch "DIMSTYLE" targetstyle))
        (setq newdata (swdt-dxf-put newdata 3 targetstyle))
      )
      (setq newdata (swdt-set-acad-dstyle-raw newdata dstyle))
      (setq newdata (swdt-set-xdata-app-raw newdata (swdt-mech-genius-app fit upper lower measurement)))
      (regapp "ACAD")
      (regapp "GENIUS_GENDTOL_13")
      (swdt-mechfit-stage "apply:combined-entmod")
      (setq ok (entmod newdata))
      (if ok
        (entupd ent)
        (progn
          ; Some bound SOLIDWORKS dimensions reject style/text/GENIUS xdata in one entmod.
          ; First try the older proven style-normalization path, then attach Mechanical xdata.
          (setq okbase nil)
          (if (and (swdt-string-p targetstyle) (tblsearch "DIMSTYLE" targetstyle))
            (progn
              (swdt-mechfit-stage "apply:fallback-process-dimension")
              (setq okbase (swdt-process-dimension ent targetstyle))
            )
          )
          (if okbase
            (progn
              (entupd ent)
              (swdt-mechfit-stage "apply:fallback-genius-entget")
              (setq data2 (swdt-mechfit-entget ent))
              (swdt-mechfit-stage "apply:fallback-genius-build")
              (setq data2 (swdt-dxf-put data2 1 newtext))
              (setq data2 (swdt-set-acad-dstyle-raw data2 dstyle))
              (setq data2 (swdt-set-xdata-app-raw data2 (swdt-mech-genius-app fit upper lower measurement)))
              (swdt-mechfit-stage "apply:fallback-genius-entmod")
              (setq okgen (entmod data2))
              (if okgen
                (progn
                  (entupd ent)
                  (setq ok okgen)
                )
              )
            )
          )
          (if (not ok)
            (progn
              ; Last fallback: apply the display/style without old xdata, then attach GENIUS xdata.
              (swdt-mechfit-stage "apply:last-base-build")
              (setq basedata (swdt-dxf-put (swdt-remove-xdata data) 1 newtext))
              (if (and (swdt-string-p targetstyle) (tblsearch "DIMSTYLE" targetstyle))
                (setq basedata (swdt-dxf-put basedata 3 targetstyle))
              )
              (setq basedata (swdt-set-acad-dstyle-raw basedata dstyle))
              (swdt-mechfit-stage "apply:last-base-entmod")
              (setq okbase (entmod basedata))
              (if okbase
                (progn
                  (entupd ent)
                  (swdt-mechfit-stage "apply:last-genius-build")
                  (setq data2 (swdt-mechfit-entget ent))
                  (setq data2 (swdt-set-xdata-app-raw data2 (swdt-mech-genius-app fit upper lower measurement)))
                  (swdt-mechfit-stage "apply:last-genius-entmod")
                  (setq okgen (entmod data2))
                  (if okgen
                    (progn
                      (entupd ent)
                      (setq ok okgen)
                    )
                  )
                )
              )
            )
          )
        )
      )
      (swdt-mechfit-stage "apply:done")
      (list ok upper lower measurement newtext okbase okgen)
    )
  )
)

(defun swdt-xdata-app-present-p (data appname / apps item itemname found)
  (setq apps (swdt-xdata-apps data))
  (setq found nil)
  (foreach item apps
    (setq itemname (swdt-xdata-app-name item))
    (if (and itemname (equal (strcase itemname) (strcase appname)))
      (setq found T)
    )
  )
  found
)

(defun swdt-mech-fit-code-from-xdata (data / apps app appname pairs result seenfit item candidate)
  (setq apps (swdt-xdata-apps data))
  (setq result nil)
  (foreach app apps
    (setq appname (swdt-xdata-app-name app))
    (if (and appname (equal (strcase appname) "GENIUS_GENDTOL_13"))
      (progn
        (setq pairs (cdr app))
        (setq seenfit nil)
        (foreach item pairs
          (if (and (= (car item) 1000) (equal (cdr item) "FitGBStd"))
            (setq seenfit T)
            (if (and seenfit (= (car item) 1000) (not result))
              (progn
                (setq candidate (swdt-safe-string (cdr item)))
                (if (swdt-fit-code-from-text candidate)
                  (setq result candidate)
                )
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun swdt-fit-values-usable-p (values)
  (or
    (swdt-nonzero-real-p (cdr (assoc 47 values)))
    (swdt-nonzero-real-p (cdr (assoc 48 values)))
  )
)

(defun swdt-mechfit-convert-one (ent targetstyle / data fit values result currentstyle already fittxt)
  (swdt-mechfit-stage "convert:entget")
  (setq data (swdt-mechfit-entget ent))
  (setq currentstyle (swdt-safe-string (cdr (assoc 3 data))))
  (swdt-mechfit-stage "convert:xdata-present")
  (setq already (swdt-xdata-app-present-p data "GENIUS_GENDTOL_13"))
  (cond
    ((not (equal (cdr (assoc 0 data)) "DIMENSION"))
      'not-dimension
    )
    ((and already (or (not targetstyle) (equal currentstyle targetstyle)))
      'already-mechanical
    )
    ((progn
       (swdt-mechfit-stage "convert:fit-code")
       (setq fittxt (swdt-dim-fit-code-from-data data))
       (if (not fittxt)
         (setq fittxt (swdt-mech-fit-code-from-xdata data))
       )
       (setq fit (swdt-fit-code-simple fittxt))
       (if (not fit)
         (setq fit (swdt-fit-code-from-text fittxt))
       )
       (not fit)
     )
      'no-fit-code
    )
    ((progn
       (swdt-mechfit-stage "convert:tolerance-values")
       (not (swdt-fit-values-usable-p (setq values (swdt-effective-tolerance-values data))))
     )
      'no-tolerance
    )
    (T
      (swdt-mechfit-stage "convert:apply")
      (setq result (swdt-apply-mech-fit-to-dim ent fit targetstyle))
      (if (car result)
        (if already 'repaired 'converted)
        (progn
          (princ
            (strcat
              "\n  Failed dim#"
              (swdt-entity-handle ent)
              " fit="
              (swdt-princ-string fit)
              " meas="
              (swdt-trim-tol-real (cadddr result))
              " style="
              (if targetstyle targetstyle "<keep>")
              " style-pass="
              (if (nth 5 result) "T" "nil")
              " genius-pass="
              (if (nth 6 result) "T" "nil")
            )
          )
          'failed
        )
      )
    )
  )
)

(defun swdt-run-mechfit-on-ss (ss label / doc idx ent status errmsg targetstyle normalstyle diamstyle converted repaired already nofit notol notdim failed errcount)
  (if (not ss)
    (progn
      (princ "\nNo dimensions selected.")
      nil
    )
    (progn
      (setq normalstyle (swdt-amiso-normal-style))
      (setq diamstyle (swdt-amiso-diameter-style normalstyle))
      (if normalstyle
        (princ (strcat "\nTarget normal dimension style: " normalstyle))
        (princ "\nWarning: no normal AM_ISO target style found; converted normal dimensions will keep their current style.")
      )
      (if diamstyle
        (princ (strcat "\nTarget diameter dimension style: " diamstyle))
        (princ "\nWarning: no diameter AM_ISO target style found; converted diameter dimensions will keep their current style.")
      )
      (setq doc (swdt-doc))
      (swdt-safe-call 'vla-StartUndoMark (list doc))
      (setq idx 0)
      (setq converted 0)
      (setq repaired 0)
      (setq already 0)
      (setq nofit 0)
      (setq notol 0)
      (setq notdim 0)
      (setq failed 0)
      (setq errcount 0)
      (while (< idx (sslength ss))
        (setq ent (ssname ss idx))
        (setq targetstyle (swdt-amiso-target-style-for-dim ent))
        (setq status (vl-catch-all-apply 'swdt-mechfit-convert-one (list ent targetstyle)))
        (if (vl-catch-all-error-p status)
          (progn
            (setq errcount (1+ errcount))
            (setq errmsg (vl-catch-all-error-message status))
            (setq status 'failed)
            (princ
              (strcat
                "\n  Error on dimension #"
                (swdt-entity-handle ent)
                " at "
                *swdt-mechfit-stage*
                ": "
                errmsg
              )
            )
          )
        )
        (cond
          ((eq status 'converted) (setq converted (1+ converted)))
          ((eq status 'repaired) (setq repaired (1+ repaired)))
          ((eq status 'already-mechanical) (setq already (1+ already)))
          ((eq status 'no-fit-code) (setq nofit (1+ nofit)))
          ((eq status 'no-tolerance) (setq notol (1+ notol)))
          ((eq status 'not-dimension) (setq notdim (1+ notdim)))
          (T (setq failed (1+ failed)))
        )
        (setq idx (1+ idx))
      )
      (swdt-safe-call 'vla-EndUndoMark (list doc))
      (princ (strcat "\n" label " finished."))
      (princ (strcat "\n  Dimensions checked: " (itoa (sslength ss))))
      (princ (strcat "\n  Converted to Mechanical fit: " (itoa converted)))
      (princ (strcat "\n  Repaired existing Mechanical fit style: " (itoa repaired)))
      (princ (strcat "\n  Already Mechanical fit: " (itoa already)))
      (princ (strcat "\n  Skipped, no embedded fit code: " (itoa nofit)))
      (princ (strcat "\n  Skipped, no tolerance values: " (itoa notol)))
      (princ (strcat "\n  Skipped, not dimensions: " (itoa notdim)))
      (princ (strcat "\n  Failed: " (itoa failed)))
      (princ (strcat "\n  Runtime errors caught: " (itoa errcount)))
      (princ "\nRun REGENALL, then check several converted dimensions with GMPOWEREDIT.")
      (princ "\nStandalone H7/h6 TEXT next to a dimension is not converted by this command.")
      (and (= failed 0) (= errcount 0))
    )
  )
)


















(defun swdt-write-mech-dim-dump (f ent / data apps item xapps style layer typ)
  (setq apps (swdt-regapp-names))
  (setq data (if apps (entget ent apps) (entget ent)))
  (setq typ (cdr (assoc 0 data)))
  (setq style (if (assoc 3 data) (cdr (assoc 3 data)) ""))
  (setq layer (if (assoc 8 data) (cdr (assoc 8 data)) ""))
  (setq xapps (swdt-xdata-apps data))
  (write-line (strcat "CTAB=" (getvar "CTAB")) f)
  (write-line (strcat "HANDLE=" (swdt-entity-handle ent)) f)
  (write-line (strcat "OBJECT_TYPE=" typ) f)
  (write-line (strcat "STYLE=" style) f)
  (write-line (strcat "LAYER=" layer) f)
  (write-line (strcat "REGISTERED_APPIDS_COUNT=" (itoa (length apps))) f)
  (write-line (strcat "VISIBLE_XDATA_APP_COUNT=" (itoa (length xapps))) f)
  (if xapps
    (foreach item xapps
      (write-line (strcat "VISIBLE_XDATA_APP=" (car item)) f)
    )
  )
  (write-line "ENTITY_DATA_WITH_ALL_REGISTERED_XDATA:" f)
  (foreach item data
    (write-line (vl-princ-to-string item) f)
  )
  (swdt-write-extension-dict f ent)
)




(defun c:SWMECHFITSEL (/ ss)
  (setq ss (ssget '((0 . "DIMENSION"))))
  (swdt-run-mechfit-on-ss ss "SWMECHFITSEL")
  (princ)
)

(defun c:SWMECHFITALL (/ ss confirm)
  (setq ss (swdt-current-space-dim-ss))
  (if (not ss)
    (princ "\nNo dimensions found in current tab.")
    (progn
      (princ (strcat "\nCurrent tab: " (getvar "CTAB")))
      (princ (strcat "\nDimensions found: " (itoa (sslength ss))))
      (initget "Yes No")
      (setq confirm (getkword "\nConvert all eligible dimensions in current tab to Mechanical fit? [Yes/No] <No>: "))
      (if (not confirm) (setq confirm "No"))
      (if (= confirm "Yes")
        (swdt-run-mechfit-on-ss ss "SWMECHFITALL")
        (princ "\nNothing changed.")
      )
    )
  )
  (princ)
)


(defun c:SWDEBUG (/ ent data raw text simple standard dimfit values rawmeas dimlfac scaledmeas
                    dimtxt dimasz dimgap isdiam normalstyle diamstyle target save base path f)
  (setq ent (car (entsel "\nSelect one dimension for SWDEBUG: ")))
  (cond
    ((not ent)
      (princ "\nNothing selected.")
    )
    (T
      (setq data (swdt-mechfit-entget ent))
      (if (not (equal (cdr (assoc 0 data)) "DIMENSION"))
        (princ "\nSelected object is not a DIMENSION.")
        (progn
          (setq raw (cdr (assoc 1 data)))
          (setq text (swdt-text-value-string raw))
          (setq simple (swdt-fit-code-simple text))
          (setq standard (swdt-fit-code-from-text text))
          (setq dimfit (swdt-dim-fit-code-from-data data))
          (setq values (swdt-effective-tolerance-values data))
          (setq rawmeas (swdt-dim-raw-measurement ent data))
          (setq dimlfac (swdt-dim-linear-scale ent data))
          (setq scaledmeas (swdt-dim-measurement ent data))
          (setq dimtxt (swdt-dimstyle-or-override-value data 140))
          (setq dimasz (swdt-dimstyle-or-override-value data 41))
          (setq dimgap (swdt-dimstyle-or-override-value data 147))
          (setq isdiam (swdt-diameter-dimension-p ent))
          (setq normalstyle (swdt-amiso-normal-style))
          (setq diamstyle (swdt-amiso-diameter-style normalstyle))
          (setq target (if isdiam diamstyle normalstyle))

          (princ (strcat "\nSWDEBUG handle: " (swdt-entity-handle ent)))
          (princ (strcat "\n  Current style: " (swdt-princ-string (cdr (assoc 3 data)))))
          (princ (strcat "\n  Target AM_ISO style: " (swdt-princ-string target)))
          (princ (strcat "\n  Diameter dimension detected: " (if isdiam "Yes" "No")))
          (princ (strcat "\n  Raw group 1: " (swdt-princ-string raw)))
          (princ (strcat "\n  Text value: " text))
          (princ (strcat "\n  Simple fit parser: " (swdt-princ-string simple)))
          (princ (strcat "\n  Standard fit parser: " (swdt-princ-string standard)))
          (princ (strcat "\n  Dimension fit parser: " (swdt-princ-string dimfit)))
          (princ (strcat "\n  Tolerance upper 47: " (swdt-princ-string (cdr (assoc 47 values)))))
          (princ (strcat "\n  Tolerance lower 48: " (swdt-princ-string (cdr (assoc 48 values)))))
          (princ (strcat "\n  Raw measurement: " (swdt-princ-string rawmeas)))
          (princ (strcat "\n  DIMLFAC / linear scale: " (swdt-princ-string dimlfac)))
          (princ (strcat "\n  Scaled measurement for Mechanical fit: " (swdt-princ-string scaledmeas)))
          (princ (strcat "\n  DIMSCALE / overall scale: " (swdt-princ-string (swdt-dimstyle-or-override-value data 40))))
          (princ (strcat "\n  DIMTXT / text height: " (swdt-princ-string dimtxt)))
          (princ (strcat "\n  DIMASZ / arrow size: " (swdt-princ-string dimasz)))
          (princ (strcat "\n  DIMGAP / text gap: " (swdt-princ-string dimgap)))
          (if (or (numberp dimtxt) (numberp dimasz) (numberp dimgap))
            (princ "\n  Note: SWAUTO normalizes display-size overrides; text/arrow/gap size will follow the target style.")
          )

          (initget "Yes No")
          (setq save (getkword "\nSave detailed DXF/xdata dump for this dimension? [Yes/No] <No>: "))
          (if (not save) (setq save "No"))
          (if (= save "Yes")
            (progn
              (setq base (getvar "DWGPREFIX"))
              (if (not base) (setq base ""))
              (setq path (getfiled "Save SWDEBUG dump" (strcat base "swdebug_dump.txt") "txt" 1))
              (if (not path)
                (princ "\nCanceled: no dump file.")
                (progn
                  (setq f (open path "w"))
                  (if (not f)
                    (princ "\nCould not open dump file for writing.")
                    (progn
                      (write-line "SWDEBUG_DUMP_V1" f)
                      (write-line "DUMP_COMMAND=SWDEBUG" f)
                      (write-line (strcat "TARGET_AMISO_STYLE=" (swdt-princ-string target)) f)
                      (write-line (strcat "FIT_CODE=" (swdt-princ-string dimfit)) f)
                      (swdt-write-mech-dim-dump f ent)
                      (close f)
                      (princ (strcat "\nSWDEBUG dump saved to: " path))
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  (princ)
)





(defun swdt-current-space-dim-ss ()
  (ssget "_X" (list '(0 . "DIMENSION") (cons 410 (getvar "CTAB"))))
)

(defun swdt-run-dimkeep-on-ss (target ss / doc idx ent result changed tolonly failed)
  (if (not ss)
    (princ "\nNo dimensions selected.")
    (progn
      (setq doc (swdt-doc))
      (swdt-safe-call 'vla-StartUndoMark (list doc))
      (setq idx 0)
      (setq changed 0)
      (setq tolonly 0)
      (setq failed 0)
      (while (< idx (sslength ss))
        (setq ent (ssname ss idx))
        (setq result (swdt-process-dimension ent target))
        (cond
          ((eq result 'tolerance)
            (setq changed (1+ changed))
            (setq tolonly (1+ tolonly))
          )
          ((eq result 'style-only)
            (setq changed (1+ changed))
          )
          (T
            (setq failed (1+ failed))
          )
        )
        (setq idx (1+ idx))
      )
      (swdt-safe-call 'vla-EndUndoMark (list doc))
      (princ "\nDimension style update finished.")
      (princ (strcat "\n  Target style: " target))
      (princ (strcat "\n  Dimensions changed: " (itoa changed)))
      (princ (strcat "\n  Dimensions with preserved tolerance/text overrides: " (itoa tolonly)))
      (princ (strcat "\n  Failed: " (itoa failed)))
      (princ "\nRun REGENALL and visually check several tolerance dimensions.")
    )
  )
)

(defun swdt-first-existing-dimstyle (names / found name)
  (while (and names (not found))
    (setq name (car names))
    (if (tblsearch "DIMSTYLE" name)
      (setq found name)
    )
    (setq names (cdr names))
  )
  found
)

(defun swdt-amiso-normal-style ()
  (swdt-first-existing-dimstyle '("AM_ISO$0" "AM_ISO" "ISO-25" "AM_ISO$3"))
)

(defun swdt-amiso-diameter-style (normalstyle / found)
  (setq found (swdt-first-existing-dimstyle '("AM_ISO$3" "AM_ISO$0" "AM_ISO" "ISO-25")))
  (if found found normalstyle)
)

(defun swdt-amiso-target-style-for-dim (ent / normalstyle diamstyle)
  (setq normalstyle (swdt-amiso-normal-style))
  (setq diamstyle (swdt-amiso-diameter-style normalstyle))
  (if (swdt-diameter-dimension-p ent)
    diamstyle
    normalstyle
  )
)

(defun swdt-swauto-final-audit (/ ss idx ent data style target isdiam normalstyle diamstyle normaltotal diamtotal normalok diamok mismatch examples)
  (setq ss (swdt-current-space-dim-ss))
  (setq normalstyle (swdt-amiso-normal-style))
  (setq diamstyle (swdt-amiso-diameter-style normalstyle))
  (setq idx 0)
  (setq normaltotal 0)
  (setq diamtotal 0)
  (setq normalok 0)
  (setq diamok 0)
  (setq mismatch 0)
  (setq examples nil)
  (if ss
    (while (< idx (sslength ss))
      (setq ent (ssname ss idx))
      (setq data (entget ent))
      (setq style (swdt-safe-string (cdr (assoc 3 data))))
      (setq target (swdt-amiso-target-style-for-dim ent))
      (setq isdiam (swdt-diameter-dimension-p ent))
      (if isdiam
        (setq diamtotal (1+ diamtotal))
        (setq normaltotal (1+ normaltotal))
      )
      (if (and target (equal style target))
        (if isdiam
          (setq diamok (1+ diamok))
          (setq normalok (1+ normalok))
        )
        (progn
          (setq mismatch (1+ mismatch))
          (if (< (length examples) 8)
            (setq examples
              (append examples
                (list
                  (strcat
                    "#"
                    (swdt-entity-handle ent)
                    " "
                    (if isdiam "diam" "normal")
                    " style="
                    style
                    " target="
                    (swdt-princ-string target)
                  )
                )
              )
            )
          )
        )
      )
      (setq idx (1+ idx))
    )
  )
  (princ "\n--- Final audit: dimension styles after SWAUTO ---")
  (princ (strcat "\n  Normal dimensions (" (swdt-princ-string normalstyle) "): " (itoa normaltotal) ", target-style matches: " (itoa normalok)))
  (princ (strcat "\n  Diameter dimensions (" (swdt-princ-string diamstyle) "): " (itoa diamtotal) ", target-style matches: " (itoa diamok)))
  (princ (strcat "\n  Style mismatches: " (itoa mismatch)))
  (if examples
    (progn
      (princ "\n  Mismatch examples:")
      (foreach item examples
        (princ (strcat "\n    " item))
      )
      (if (> mismatch (length examples))
        (princ (strcat "\n    More mismatches hidden: " (itoa (- mismatch (length examples)))))
      )
    )
  )
  (= mismatch 0)
)

(defun swdt-swauto-fit-audit (/ ss idx ent data hasmech dimfit fit values tolusable residual residualexamples mechcount tolcount)
  (setq ss (swdt-current-space-dim-ss))
  (setq idx 0)
  (setq mechcount 0)
  (setq tolcount 0)
  (setq residual 0)
  (setq residualexamples nil)
  (if ss
    (while (< idx (sslength ss))
      (setq ent (ssname ss idx))
      (setq data (swdt-mechfit-entget ent))
      (setq hasmech (swdt-xdata-app-present-p data "GENIUS_GENDTOL_13"))
      (setq dimfit (swdt-dim-fit-code-from-data data))
      (setq fit (swdt-fit-code-simple dimfit))
      (if (not fit)
        (setq fit (swdt-fit-code-from-text dimfit))
      )
      (setq values (swdt-effective-tolerance-values data))
      (setq tolusable (swdt-fit-values-usable-p values))
      (if hasmech
        (setq mechcount (1+ mechcount))
      )
      (if tolusable
        (setq tolcount (1+ tolcount))
      )
      (if (and fit tolusable (not hasmech))
        (progn
          (setq residual (1+ residual))
          (if (< (length residualexamples) 8)
            (setq residualexamples
              (append residualexamples
                (list
                  (strcat
                    "#"
                    (swdt-entity-handle ent)
                    " fit="
                    (swdt-princ-string fit)
                    " style="
                    (swdt-princ-string (cdr (assoc 3 data)))
                  )
                )
              )
            )
          )
        )
      )
      (setq idx (1+ idx))
    )
  )
  (princ "\n--- Final audit: Mechanical fit data after SWAUTO ---")
  (princ (strcat "\n  Dimensions with tolerance values: " (itoa tolcount)))
  (princ (strcat "\n  Dimensions with Mechanical fit data: " (itoa mechcount)))
  (princ (strcat "\n  Residual embedded fit-code dimensions: " (itoa residual)))
  (if residualexamples
    (progn
      (princ "\n  Residual examples:")
      (foreach item residualexamples
        (princ (strcat "\n    " item))
      )
    )
  )
  (= residual 0)
)

(defun swdt-run-dimkeep-amiso-on-ss (ss / normalstyle diamstyle doc idx ent target result changed normalchanged diamchanged tolonly failed missing)
  (setq normalstyle (swdt-amiso-normal-style))
  (setq diamstyle (swdt-amiso-diameter-style normalstyle))
  (setq missing nil)
  (if (not normalstyle)
    (setq missing (append missing (list "AM_ISO$0 / AM_ISO / ISO-25 / AM_ISO$3")))
  )
  (if (not diamstyle)
    (setq missing (append missing (list "AM_ISO$3 / AM_ISO$0 / AM_ISO / ISO-25")))
  )
  (cond
    (missing
      (princ "\nCanceled: required dimension style not found.")
      (foreach target missing
        (princ (strcat "\n  Missing: " target))
      )
      (princ "\nCreate or import an AM_ISO style, then run SWAUTO again.")
      nil
    )
    ((not ss)
      (princ "\nNo dimensions selected.")
      nil
    )
    (T
      (setq doc (swdt-doc))
      (swdt-safe-call 'vla-StartUndoMark (list doc))
      (setq idx 0)
      (setq changed 0)
      (setq normalchanged 0)
      (setq diamchanged 0)
      (setq tolonly 0)
      (setq failed 0)
      (while (< idx (sslength ss))
        (setq ent (ssname ss idx))
        (if (swdt-diameter-dimension-p ent)
          (setq target diamstyle)
          (setq target normalstyle)
        )
        (setq result (swdt-process-dimension ent target))
        (cond
          ((eq result 'tolerance)
            (setq changed (1+ changed))
            (setq tolonly (1+ tolonly))
            (if (equal target diamstyle)
              (setq diamchanged (1+ diamchanged))
              (setq normalchanged (1+ normalchanged))
            )
          )
          ((eq result 'style-only)
            (setq changed (1+ changed))
            (if (equal target diamstyle)
              (setq diamchanged (1+ diamchanged))
              (setq normalchanged (1+ normalchanged))
            )
          )
          (T
            (setq failed (1+ failed))
          )
        )
        (setq idx (1+ idx))
      )
      (swdt-safe-call 'vla-EndUndoMark (list doc))
      (princ "\nAM_ISO smart dimension style update finished.")
      (princ (strcat "\n  Normal target style: " normalstyle))
      (princ (strcat "\n  Diameter target style: " diamstyle))
      (princ (strcat "\n  Dimensions checked: " (itoa (sslength ss))))
      (princ (strcat "\n  Normal dimensions changed: " (itoa normalchanged)))
      (princ (strcat "\n  Diameter dimensions changed: " (itoa diamchanged)))
      (princ (strcat "\n  Dimensions with preserved overrides: " (itoa tolonly)))
      (princ (strcat "\n  Failed: " (itoa failed)))
      (princ "\nRun REGENALL and visually check several diameter/tolerance dimensions.")
      (= failed 0)
    )
  )
)

(defun swdt-run-dimkeep (target / ss)
  (setq ss (ssget '((0 . "DIMENSION"))))
  (swdt-run-dimkeep-on-ss target ss)
)



(defun c:SWDIMKEEPAMISO (/ ss confirm normalstyle diamstyle)
  (setq ss (swdt-current-space-dim-ss))
  (if (not ss)
    (princ "\nNo dimensions found in current tab.")
    (progn
      (setq normalstyle (swdt-amiso-normal-style))
      (setq diamstyle (swdt-amiso-diameter-style normalstyle))
      (princ (strcat "\nCurrent tab: " (getvar "CTAB")))
      (princ (strcat "\nDimensions found: " (itoa (sslength ss))))
      (if normalstyle
        (princ (strcat "\nNormal dimensions will use " normalstyle "."))
        (princ "\nNormal target style missing: AM_ISO$0 / AM_ISO / ISO-25 / AM_ISO$3.")
      )
      (if diamstyle
        (princ (strcat "\nDiameter dimensions will use " diamstyle "."))
        (princ "\nDiameter target style missing: AM_ISO$3 / AM_ISO$0 / AM_ISO / ISO-25.")
      )
      (initget "Yes No")
      (setq confirm (getkword "\nApply AM_ISO smart style mapping? [Yes/No] <No>: "))
      (if (not confirm) (setq confirm "No"))
      (if (= confirm "Yes")
        (swdt-run-dimkeep-amiso-on-ss ss)
        (princ "\nNothing changed.")
      )
    )
  )
  (princ)
)

(defun swdt-purge-dimstyles-core (/ before after removed)
  (setq before (length (swdt-dimstyle-names)))
  (vl-cmdf "_.-PURGE" "_Dimstyles" "*" "_No")
  (setq after (length (swdt-dimstyle-names)))
  (setq removed (- before after))
  (if (< removed 0) (setq removed 0))
  (list before after removed)
)

(defun c:SWPURGESTYLES (/ result)
  (princ "\nSWPURGESTYLES will purge unused dimension styles.")
  (princ "\nDefault or currently used styles cannot be purged by CAD and will remain.")
  (setq result (swdt-purge-dimstyles-core))
  (princ "\nSWPURGESTYLES finished.")
  (princ (strcat "\n  Dimension styles before: " (itoa (nth 0 result))))
  (princ (strcat "\n  Dimension styles after: " (itoa (nth 1 result))))
  (princ (strcat "\n  Purged unused dimension styles: " (itoa (nth 2 result))))
  (princ "\nRun SWAUTO first if old SOLIDWORKS styles are still in use.")
  (princ)
)

(defun c:SWFINDSTYLE (/ input pattern names layout block layouttotal currentcount currentss layoutcounts layoutexamples currentstyle blocktotal blockcounts blockexamples deep deeptotal deepexamples hidden)
  (setq input (getstring T "\nDimension style wildcard <*SLDDIMSTYLE*>: "))
  (setq pattern (swdt-style-pattern-normalize input))
  (setq names (swdt-dimstyle-names-matching pattern))
  (setq layout (swdt-scan-layout-dimstyle-usage pattern))
  (setq block (swdt-scan-block-dimstyle-usage pattern))
  (setq layouttotal (nth 0 layout))
  (setq currentcount (nth 1 layout))
  (setq currentss (nth 2 layout))
  (setq layoutcounts (nth 3 layout))
  (setq layoutexamples (nth 4 layout))
  (setq currentstyle (nth 5 layout))
  (setq blocktotal (nth 0 block))
  (setq blockcounts (nth 1 block))
  (setq blockexamples (nth 2 block))
  (princ "\nSWFINDSTYLE finished.")
  (princ (strcat "\n  Pattern: " pattern))
  (princ (strcat "\n  Matching dimension style definitions: " (itoa (length names))))
  (if names
    (swdt-print-limited-list names 20 "    ")
  )
  (princ (strcat "\n  Current DIMSTYLE: " (swdt-princ-string currentstyle)))
  (if (swdt-dimstyle-match-p currentstyle pattern)
    (princ "\n  Warning: current DIMSTYLE matches the pattern, so CAD may refuse to purge it.")
  )
  (princ (strcat "\n  Matching top-level/layout dimensions: " (itoa layouttotal)))
  (princ (strcat "\n  Matching dimensions in current tab selected: " (itoa currentcount)))
  (if (> currentcount 0)
    (sssetfirst nil currentss)
  )
  (swdt-print-style-counts "\n  By tab/style:" layoutcounts)
  (if layoutexamples
    (progn
      (princ "\n  Layout examples:")
      (swdt-print-limited-list layoutexamples 12 "    ")
    )
  )
  (princ (strcat "\n  Matching dimensions inside block definitions: " (itoa blocktotal)))
  (swdt-print-style-counts "\n  By block/style:" blockcounts)
  (if blockexamples
    (progn
      (princ "\n  Block examples:")
      (swdt-print-limited-list blockexamples 12 "    ")
    )
  )
  (if names
    (progn
      (princ "\n  Deep reference scan, excluding the style definitions themselves:")
      (setq deep (swdt-deep-style-reference-scan names))
      (setq deeptotal (car deep))
      (setq deepexamples (cadr deep))
      (princ (strcat "\n    References found: " (itoa deeptotal)))
      (if deepexamples
        (progn
          (princ "\n    Deep examples:")
          (swdt-print-limited-list deepexamples 30 "      ")
          (setq hidden (- deeptotal (length deepexamples)))
          (if (> hidden 0)
            (princ (strcat "\n      More deep references hidden: " (itoa hidden)))
          )
        )
      )
    )
  )
  (if (and (= layouttotal 0) (= blocktotal 0))
    (progn
      (princ "\nNo DIMENSION entities using that style were found in layouts or block definitions.")
      (if (and names deeptotal (= deeptotal 0))
        (princ "\nDeep scan also found no visible references. Try AUDIT, save/reopen, then purge again.")
        (princ "\nIf PURGE still cannot remove it, review the Deep examples above.")
      )
    )
  )
  (princ)
)

(defun swdt-protected-dimstyle-name-p (name current / upper)
  (setq upper (strcase (swdt-princ-string name)))
  (or
    (and current (equal (strcase (swdt-princ-string current)) upper))
    (member upper '("STANDARD" "ANNOTATIVE"))
    (vl-string-search "AM_ISO" upper)
    (vl-string-search "ISO-25" upper)
  )
)

(defun swdt-vla-get-dimstyle (styles name / result)
  (setq result (vl-catch-all-apply 'vla-Item (list styles name)))
  (if (vl-catch-all-error-p result)
    nil
    result
  )
)

(defun swdt-try-delete-dimstyles-core (pattern verbose / names current doc styles deleted failed protected notfound accessfail name obj result message)
  (setq names (swdt-dimstyle-names-matching pattern))
  (setq current (getvar "DIMSTYLE"))
  (setq deleted 0)
  (setq failed 0)
  (setq protected 0)
  (setq notfound 0)
  (setq accessfail 0)
  (if names
    (progn
      (setq doc (swdt-doc))
      (setq styles (vl-catch-all-apply 'vla-get-DimStyles (list doc)))
      (if (vl-catch-all-error-p styles)
        (progn
          (setq accessfail 1)
          (if verbose
            (princ (strcat "\nCannot access DimStyles collection: " (vl-catch-all-error-message styles)))
          )
        )
        (progn
          (swdt-safe-call 'vla-StartUndoMark (list doc))
          (foreach name names
            (cond
              ((swdt-protected-dimstyle-name-p name current)
                (setq protected (1+ protected))
                (if verbose (princ (strcat "\n  SKIP protected/current: " name)))
              )
              (T
                (setq obj (swdt-vla-get-dimstyle styles name))
                (if (not obj)
                  (progn
                    (setq notfound (1+ notfound))
                    (if verbose (princ (strcat "\n  SKIP not found in ActiveX collection: " name)))
                  )
                  (progn
                    (setq result (vl-catch-all-apply 'vla-Delete (list obj)))
                    (if (vl-catch-all-error-p result)
                      (progn
                        (setq failed (1+ failed))
                        (setq message (vl-catch-all-error-message result))
                        (if verbose (princ (strcat "\n  FAIL: " name " / " message)))
                      )
                      (progn
                        (setq deleted (1+ deleted))
                        (if verbose (princ (strcat "\n  DELETED: " name)))
                      )
                    )
                  )
                )
              )
            )
          )
          (swdt-safe-call 'vla-EndUndoMark (list doc))
        )
      )
    )
  )
  (list (length names) deleted failed protected notfound accessfail)
)

(defun c:SWTRYDELDIMSTYLES (/ input pattern names confirm result)
  (setq input (getstring T "\nDimension style wildcard to try-delete <*SLDDIMSTYLE*>: "))
  (setq pattern (swdt-style-pattern-normalize input))
  (setq names (swdt-dimstyle-names-matching pattern))
  (princ "\nSWTRYDELDIMSTYLES will try ActiveX Delete on unused matching dimension styles.")
  (princ "\nIt does not use entdel. Referenced styles should fail and remain.")
  (princ (strcat "\n  Pattern: " pattern))
  (princ (strcat "\n  Matching style definitions: " (itoa (length names))))
  (if names
    (swdt-print-limited-list names 20 "    ")
  )
  (if names
    (progn
      (initget "Yes No")
      (setq confirm (getkword "\nTry delete matching dimension styles? [Yes/No] <No>: "))
      (if (not confirm) (setq confirm "No"))
      (if (= confirm "Yes")
        (progn
          (setq result (swdt-try-delete-dimstyles-core pattern T))
          (princ "\nSWTRYDELDIMSTYLES finished.")
          (princ (strcat "\n  Deleted: " (itoa (nth 1 result))))
          (princ (strcat "\n  Failed because CAD still sees a reference: " (itoa (nth 2 result))))
          (princ (strcat "\n  Protected/current skipped: " (itoa (nth 3 result))))
          (princ (strcat "\n  Not found through ActiveX: " (itoa (nth 4 result))))
          (if (> (nth 5 result) 0)
            (princ "\n  Could not access DimStyles collection.")
          )
          (princ "\nRun SWFINDSTYLE again, then AUDIT / QSAVE / reopen if styles remain.")
        )
        (princ "\nNothing changed.")
      )
    )
    (princ "\nNo matching dimension styles.")
  )
  (princ)
)


(defun swdt-autofix-preflight (ss / normalstyle diamstyle ok)
  (setq normalstyle (swdt-amiso-normal-style))
  (setq diamstyle (swdt-amiso-diameter-style normalstyle))
  (setq ok T)
  (princ "\nPreflight:")
  (princ (strcat "\n  Current tab: " (getvar "CTAB")))
  (princ (strcat "\n  Dimensions found: " (if ss (itoa (sslength ss)) "0")))
  (if normalstyle
    (princ (strcat "\n  Normal target style: " normalstyle " OK"))
    (progn
      (setq ok nil)
      (princ "\n  Normal target style: Missing AM_ISO$0 / AM_ISO / ISO-25 / AM_ISO$3")
    )
  )
  (if diamstyle
    (princ (strcat "\n  Diameter target style: " diamstyle " OK"))
    (progn
      (setq ok nil)
      (princ "\n  Diameter target style: Missing AM_ISO$3 / AM_ISO$0 / AM_ISO / ISO-25")
    )
  )
  ok
)

(defun swdt-cleanup-old-dimstyles-core (/ purge deleted remaining ok)
  (princ "\n--- Step 5/5: Cleanup unused SOLIDWORKS dimension styles ---")
  (setq purge (swdt-purge-dimstyles-core))
  (princ (strcat "\n  Purged unused dimension styles: " (itoa (nth 2 purge))))
  (setq deleted (swdt-try-delete-dimstyles-core "*SLDDIMSTYLE*" nil))
  (princ (strcat "\n  ActiveX-deleted leftover SLD styles: " (itoa (nth 1 deleted))))
  (princ (strcat "\n  ActiveX-delete failed/referenced: " (itoa (nth 2 deleted))))
  (setq remaining (length (swdt-dimstyle-names-matching "*SLDDIMSTYLE*")))
  (princ (strcat "\n  Remaining SLD style definitions: " (itoa remaining)))
  (setq ok (and (= (nth 2 deleted) 0) (= (nth 5 deleted) 0) (= remaining 0)))
  (if (not ok)
    (princ "\n  Cleanup note: remaining styles are not forced; use SWFINDSTYLE if needed.")
  )
  ok
)

(defun swdt-run-autofix-core (ss / styleok fitok auditok fitauditok cleanupok normalstyle diamstyle)
  (setq normalstyle (swdt-amiso-normal-style))
  (setq diamstyle (swdt-amiso-diameter-style normalstyle))
  (princ "\n--- Step 1/5: AM_ISO smart style mapping ---")
  (setq styleok (swdt-run-dimkeep-amiso-on-ss ss))
  (if styleok
    (progn
      (princ "\n--- Step 2/5: REGENALL ---")
      (vl-cmdf "_.REGENALL")
      (setq ss (swdt-current-space-dim-ss))
      (princ "\n--- Step 3/5: Mechanical fit conversion ---")
      (setq fitok (swdt-run-mechfit-on-ss ss "SWAUTO Mechanical fit phase"))
      (princ "\n--- Step 4/5: REGENALL and final audit ---")
      (vl-cmdf "_.REGENALL")
      (setq auditok (swdt-swauto-final-audit))
      (setq fitauditok (swdt-swauto-fit-audit))
      (setq cleanupok (swdt-cleanup-old-dimstyles-core))
      (princ "\nSWAUTO finished.")
      (if (and fitok auditok fitauditok cleanupok)
        (progn
          (princ "\nSWAUTO RESULT: OK")
          (princ "\nVerify several dimensions with GMPOWEREDIT, then save.")
          T
        )
        (progn
          (princ "\nSWAUTO RESULT: CHECK NEEDED")
          (princ "\nReview failed conversions, style mismatches, or cleanup notes above. Use SWDEBUG or SWFINDSTYLE only if needed.")
          nil
        )
      )
    )
    (progn
      (princ "\nSWAUTO stopped before Mechanical fit conversion.")
      (princ "\nSWAUTO RESULT: CHECK NEEDED")
      nil
    )
  )
)

(defun swdt-run-swauto-command (/ ss ok normalstyle diamstyle)
  (setq ss (swdt-current-space-dim-ss))
  (if (not ss)
    (princ "\nNo dimensions found in current tab.")
    (progn
      (setq normalstyle (swdt-amiso-normal-style))
      (setq diamstyle (swdt-amiso-diameter-style normalstyle))
      (setq ok (swdt-autofix-preflight ss))
      (princ "\nSWAUTO will run:")
      (princ "\n  1. AM_ISO smart style mapping")
      (princ (strcat "\n     Normal dimensions  -> " (if normalstyle normalstyle "missing AM_ISO style")))
      (princ (strcat "\n     Diameter dimensions -> " (if diamstyle diamstyle "missing AM_ISO style")))
      (princ "\n  2. REGENALL")
      (princ "\n  3. Mechanical fit conversion")
      (princ "\n  4. REGENALL and final audit")
      (princ "\n  5. Cleanup unused SOLIDWORKS dimension styles")
      (if ok
        (swdt-run-autofix-core ss)
        (progn
          (princ "\nSWAUTO stopped before changing dimensions.")
          (princ "\nSWAUTO RESULT: CHECK NEEDED")
        )
      )
    )
  )
  (princ)
)


(defun c:SWAUTO ()
  (swdt-run-swauto-command)
  (princ)
)

(defun c:SWHELP ()
  (princ "\nSolidWorks DWG cleanup daily workflow:")
  (princ "\n  1. Save a backup copy.")
  (princ "\n  2. Run SWAUTO.")
  (princ "\n  3. Preflight should show selected normal/diameter target styles.")
  (princ "\n  4. Check SWAUTO RESULT: OK.")
  (princ "\n  5. Verify several dimensions with GMPOWEREDIT, then QSAVE.")
  (princ "\n")
  (princ "\nWhat SWAUTO does:")
  (princ "\n  - Normal dimensions  -> AM_ISO$0, or AM_ISO/ISO-25/AM_ISO$3 if AM_ISO$0 is missing")
  (princ "\n  - Diameter dimensions -> AM_ISO$3, or the nearest available AM_ISO fallback")
  (princ "\n  - Converts embedded H7/h6/H9 fit tolerances to Mechanical fit data")
  (princ "\n  - Preserves tolerance and DIMLFAC, while normalizing text/arrow/gap size to the target style")
  (princ "\n  - Purges unused old styles and safely deletes leftover SLD styles if CAD allows it")
  (princ "\n")
  (princ "\nTroubleshooting commands:")
  (princ "\n  SWDEBUG - check style target, fit code, tolerance, scale, size, and optional dump")
  (princ "\n  SWFINDSTYLE - find dimensions using a style wildcard, default *SLDDIMSTYLE*")
  (princ "\n")
  (princ "\nManual-only commands:")
  (princ "\n  SWDIMKEEPAMISO, SWMECHFITSEL, SWMECHFITALL, SWPURGESTYLES, SWTRYDELDIMSTYLES")
  (princ)
)


(princ (strcat "\nLoaded gstarcad_dimstyle_keep_tolerance.lsp " *swdt-version*))
(princ "\nMain command: SWAUTO")
(princ "\nHelp: SWHELP")
(princ "\nTroubleshooting: SWDEBUG, SWFINDSTYLE")
(princ)
