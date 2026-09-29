;;; Read-only probe: every model-space entity as ENT|handle|object name|layer|bbox.
;;; Environment: SWT_ENT_LOG = log path.
(vl-load-com)

(defun swt-e-bbox (obj / minp maxp r)
  (setq r (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'minp 'maxp)))
  (if (vl-catch-all-error-p r)
    ""
    (progn
      (setq minp (vlax-safearray->list minp))
      (setq maxp (vlax-safearray->list maxp))
      (strcat (rtos (car minp) 2 2) "," (rtos (cadr minp) 2 2) "," (rtos (car maxp) 2 2) "," (rtos (cadr maxp) 2 2))
    )
  )
)

(defun swt-e-main (/ log obj)
  (setq log (open (getenv "SWT_ENT_LOG") "w"))
  (vlax-for obj (vla-get-ModelSpace (vla-get-ActiveDocument (vlax-get-acad-object)))
    (write-line
      (strcat "ENT|" (vla-get-Handle obj) "|" (vla-get-ObjectName obj) "|" (vla-get-Layer obj) "|" (swt-e-bbox obj))
      log
    )
  )
  (write-line "Entity probe completed: yes" log)
  (close log)
  (princ)
)

(swt-e-main)
