;;; Read-only probe for the GMTITLE value fix.  For every source sheet of a drawing at
;;; the TITLE stage it logs the source title data and the 11 values the transfer would
;;; write, using the loaded swcad_title_scale.lsp functions.  Nothing is changed.
;;; Environment: SWT_PLAN_LOG = log path, SWT_PLAN_MODULE = swcad_title_scale.lsp path.

(vl-load-com)
(load (getenv "SWT_PLAN_MODULE"))

(defun swt-plan-clean (text / idx ch out)
  (setq text (swcad-title-string text))
  (setq out "")
  (setq idx 1)
  (while (<= idx (strlen text))
    (setq ch (substr text idx 1))
    (cond
      ((= ch "|") (setq out (strcat out "/")))
      ((member ch '("\n" "\r" "\t")) (setq out (strcat out " ")))
      (T (setq out (strcat out ch)))
    )
    (setq idx (1+ idx))
  )
  out
)

(defun swt-plan-line (log parts / text part)
  (setq text "")
  (foreach part parts
    (setq text (strcat text (if (= text "") "" "|") (swt-plan-clean part)))
  )
  (write-line text log)
)

(defun swt-plan-defaults-object (/ ss idx obj result)
  ;; A bound "...$0$DR_titlea_3rd" carries the same attribute defaults as DR_titlea_3rd.
  (setq ss (ssget "_X" '((0 . "INSERT") (66 . 1))))
  (setq idx 0)
  (setq result nil)
  (if ss
    (while (and (not result) (< idx (sslength ss)))
      (setq obj (vlax-ename->vla-object (ssname ss idx)))
      (if (wcmatch (strcase (swcad-title-vla-block-name obj)) "*DR_TITLEA_3RD")
        (setq result obj)
      )
      (setq idx (1+ idx))
    )
  )
  result
)

(defun swt-plan-record-status (record mappings unmapped duplicates / handle status pair)
  (setq handle (swcad-title-string (nth 3 record)))
  (setq status "NOT_LISTED")
  (foreach pair mappings
    (if (equal (swcad-title-string (nth 3 (cdr pair))) handle)
      (setq status (strcat "MAPPED:" (car pair)))
    )
  )
  (foreach pair unmapped
    (if (equal (swcad-title-string (nth 3 pair)) handle) (setq status "UNMAPPED"))
  )
  (foreach pair duplicates
    (if (equal (swcad-title-string (nth 3 pair)) handle) (setq status "DUPLICATE"))
  )
  status
)

(defun swt-plan-old-values (mappings block-sheet / result pair preview)
  ;; What the previous version wrote: raw text of text mappings only, plus the sheet size.
  (setq result nil)
  (foreach pair mappings
    (setq preview (cdr pair))
    (if (/= (cadr preview) "attribute")
      (setq result (swcad-title-assoc-put (car pair) (nth 2 preview) result))
    )
  )
  (setq result (swcad-title-normalize-combined-approval-date-values result))
  (swcad-title-values-with-sheet-size-override result block-sheet)
)

(defun swt-plan-main (/ log defaults-object records index item source frame-record source-ename source-bbox source-block source-frame source-frame-ename source-frame-bbox source-frame-block build mappings text-records unmapped duplicates values old-values block-sheet inferred-frame-bbox frame-block old-frame-block final object attrs attr record pair)
  (setq log (open (getenv "SWT_PLAN_LOG") "w"))
  (swt-plan-line log (list "DWG" (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
  (swt-plan-line log (list "VERSION" *swcad-title-scale-version*))
  (setq defaults-object (swt-plan-defaults-object))
  (swt-plan-line log (list "DEFAULTS_BLOCK" (if defaults-object (swcad-title-vla-block-name defaults-object) "<none>")))
  (if defaults-object
    (foreach pair (swcad-title-attribute-definition-defaults (swcad-title-vla-block-name defaults-object))
      (swt-plan-line log (list "DEFAULT" (car pair) (cdr pair)))
    )
  )
  (swt-plan-line log (list "LOGIN" (getvar "LOGINNAME")))
  (setq records (swcad-title-transfer-batch-source-records))
  (swt-plan-line log (list "SOURCE_COUNT" (itoa (length records))))
  (setq index 0)
  (foreach item records
    (setq index (1+ index))
    (setq source (car item))
    (setq source-ename (car source))
    (setq source-bbox (caddr source))
    (setq source-block (if source-ename (swcad-title-effective-insert-name source-ename) ""))
    (setq source-frame (if source-bbox (swcad-title-transfer-source-frame source-bbox source-ename) nil))
    (setq source-frame-ename (if source-frame (car source-frame) nil))
    (setq source-frame-bbox (if source-frame (caddr source-frame) nil))
    (setq source-frame-block (if source-frame-ename (swcad-title-effective-insert-name source-frame-ename) nil))
    (setq build (swcad-title-transfer-build-mappings source-bbox source-ename 7.0))
    (setq mappings (car build))
    (setq text-records (cadr build))
    (setq unmapped (caddr build))
    (setq duplicates (cadddr build))
    (setq values (swcad-title-transfer-values mappings))
    (if (not source-ename)
      (setq values (swcad-title-values-fill-missing-template-empty values))
    )
    (setq block-sheet (swcad-title-source-block-sheet-size source-block source-frame-block))
    (setq values (swcad-title-values-with-sheet-size-override values block-sheet))
    (setq inferred-frame-bbox (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox values block-sheet))
    (setq frame-block (swcad-title-target-frame-block-name-for-source source-block source-frame-block values inferred-frame-bbox))
    (setq old-values (swt-plan-old-values mappings block-sheet))
    (setq old-frame-block
      (swcad-title-target-frame-block-name-for-source
        source-block
        source-frame-block
        old-values
        (swcad-title-effective-source-frame-bbox source-bbox source-frame-bbox old-values block-sheet)
      )
    )
    (setq final (swcad-title-complete-title-values values defaults-object))
    (swt-plan-line log
      (list
        "SHEET" (itoa index)
        (if source-ename (swcad-title-ename-handle source-ename) "<loose>")
        source-block
        (if source-ename "insert" "loose-text")
        (swcad-title-string block-sheet)
        frame-block
        old-frame-block
        (swcad-title-bbox-string source-bbox)
      )
    )
    (setq object (if source-ename (swcad-title-safe-vla-object source-ename) nil))
    (setq attrs (if object (swcad-title-get-insert-attributes object) nil))
    (foreach attr attrs
      (swt-plan-line log (list "SRCATTR" (itoa index) (swcad-title-attribute-tag attr) (swcad-title-attribute-value attr)))
    )
    (foreach record text-records
      (swt-plan-line log
        (list
          "SRCTEXT" (itoa index)
          (swcad-title-string (nth 3 record))
          (swcad-title-string (nth 2 record))
          (swcad-title-point-string (nth 5 record))
          (swt-plan-record-status record mappings unmapped duplicates)
          (nth 6 record)
          (swcad-title-record-plain-text record)
        )
      )
    )
    (foreach pair old-values
      (swt-plan-line log (list "OLD" (itoa index) (car pair) (cdr pair)))
    )
    (foreach pair final
      (swt-plan-line log
        (list
          "FINAL" (itoa index) (car pair) (cdr pair)
          (cond
            ((and (assoc (car pair) mappings) (equal (cadr (cdr (assoc (car pair) mappings))) "attribute")) "attribute")
            ((assoc (car pair) mappings) "text")
            ((and (equal (car pair) "GEN-TITLE-SIZ{6.7}") block-sheet) "sheet-size")
            (T "default")
          )
        )
      )
    )
  )
  (write-line "Value plan probe completed: yes" log)
  (close log)
  (princ)
)

(swt-plan-main)
