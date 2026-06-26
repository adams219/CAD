;;; Shared SWCAD helpers.
;;; Keep this module small while legacy commands are being migrated.

(setq *swcad-common-loaded* T)

(defun swcad-princ-line (text)
  (princ (strcat "\n" text))
)

(defun swcad-string (value)
  (cond
    ((= (type value) 'STR) value)
    ((not value) "")
    (T (vl-princ-to-string value))
  )
)

(princ "\n  swcad_common.lsp ready")
(princ)
