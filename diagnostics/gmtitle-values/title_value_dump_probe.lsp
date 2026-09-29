;;; Read-only probe: dumps every GMTITLE title block (DR_titlea_3rd) attribute and
;;; every DR_A*_Outline frame in model space. Environment: SWT_ATTR_LOG = log path.

(vl-load-com)

(defun swt-attr-str (value)
  (cond
    ((= (type value) 'STR) value)
    ((null value) "")
    (T (vl-princ-to-string value))
  )
)

(defun swt-attr-clean (text / idx ch out)
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

(defun swt-attr-effective-name (obj / name)
  (setq name (vl-catch-all-apply 'vla-get-EffectiveName (list obj)))
  (if (vl-catch-all-error-p name) (vla-get-Name obj) name)
)

(defun swt-attr-point (obj / p)
  (setq p (vlax-safearray->list (vlax-variant-value (vla-get-InsertionPoint obj))))
  (strcat (rtos (car p) 2 3) "," (rtos (cadr p) 2 3))
)

(defun swt-attr-main (/ log ss idx ent obj name atts att count)
  (setq log (open (getenv "SWT_ATTR_LOG") "w"))
  (write-line (strcat "DWG|" (getvar "DWGPREFIX") (getvar "DWGNAME")) log)
  (setq ss (ssget "_X" '((0 . "INSERT") (410 . "Model"))))
  (setq idx 0)
  (setq count 0)
  (if ss
    (while (< idx (sslength ss))
      (setq ent (ssname ss idx))
      (setq obj (vlax-ename->vla-object ent))
      (setq name (swt-attr-effective-name obj))
      (cond
        ((wcmatch (strcase name) "DR_A?_OUTLINE")
          (write-line (strcat "FRAME|" (cdr (assoc 5 (entget ent))) "|" name "|" (swt-attr-point obj)) log)
        )
        ((= (strcase name) "DR_TITLEA_3RD")
          (setq count (1+ count))
          (write-line (strcat "TITLE|" (cdr (assoc 5 (entget ent))) "|" (swt-attr-point obj)) log)
          (setq atts (vl-catch-all-apply 'vlax-invoke (list obj 'GetAttributes)))
          (if (not (vl-catch-all-error-p atts))
            (foreach att atts
              (write-line
                (strcat
                  "ATTR|" (cdr (assoc 5 (entget ent)))
                  "|" (swt-attr-str (vla-get-TagString att))
                  "|" (swt-attr-clean (swt-attr-str (vla-get-TextString att)))
                )
                log
              )
            )
          )
        )
      )
      (setq idx (1+ idx))
    )
  )
  (write-line (strcat "TITLE_COUNT|" (itoa count)) log)
  (foreach item (dictsearch (namedobjdict) "SWCAD_WORKFLOW_STATE")
    (if
      (and
        (= (car item) 1)
        (or
          (wcmatch (cdr item) "FINAL_SHEET_*")
          (wcmatch (cdr item) "SOURCE_SHEET_*")
          (wcmatch (cdr item) "LAYOUT_OWNED_*")
        )
      )
      (write-line (strcat "STATE|" (swt-attr-clean (cdr item))) log)
    )
  )
  (write-line "Attribute probe completed: yes" log)
  (close log)
  (princ)
)

(swt-attr-main)
