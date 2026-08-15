;;; Runtime probe for portable Save As work-copy authorization.

(vl-load-com)

(defun swtitle-portable-write-line (handle text)
  (if handle (write-line text handle))
)

(defun swtitle-portable-bool (value)
  (if value "yes" "no")
)

(defun swtitle-portable-main (/ root main-path mode destination log-path handle load-result load-ok source-before saveas-result marker-ok authorization current-path path-ok helper-path helper-ok log-root local-log-ok dbmod all-good)
  (setq root (getenv "SWTITLE_REPO_ROOT"))
  (setq mode (strcase (if (getenv "SWTITLE_PORTABLE_MODE") (getenv "SWTITLE_PORTABLE_MODE") "VERIFY")))
  (setq destination (getenv "SWTITLE_PORTABLE_DEST"))
  (setq log-path (getenv "SWTITLE_PORTABLE_LOG"))
  (setq main-path
    (if root
      (strcat (vl-string-right-trim "\\/" root) "/src/tools/gmtitle/swcad_title_scale.lsp")
      nil
    )
  )
  (setq handle (if log-path (open log-path "w") nil))
  (swtitle-portable-write-line handle "SWTITLE portable Save As work-copy probe")
  (swtitle-portable-write-line handle (strcat "Mode: " mode))
  (swtitle-portable-write-line handle (strcat "DWG before: " (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))))
  (setq load-result (if main-path (vl-catch-all-apply 'load (list main-path)) nil))
  (setq load-ok (and main-path (not (vl-catch-all-error-p load-result)) (boundp '*swcad-title-scale-version*)))
  (swtitle-portable-write-line handle (strcat "Loaded: " (swtitle-portable-bool load-ok)))
  (if load-ok
    (progn
      (swtitle-portable-write-line handle (strcat "Loaded version: " *swcad-title-scale-version*))
      (setq source-before (swcad-title-current-dwg-full-path))
      (if (equal mode "CREATE")
        (progn
          (setq *swcad-title-work-copy-saveas-path-override* destination)
          (setq saveas-result (vl-catch-all-apply 'swcad-title-saveas-selected-work-copy nil))
          (setq *swcad-title-work-copy-saveas-path-override* nil)
          (setq saveas-result (and (not (vl-catch-all-error-p saveas-result)) saveas-result))
        )
        (setq saveas-result T)
      )
      (setq marker-ok (swcad-title-selected-work-copy-p))
      (setq authorization (swcad-title-work-copy-authorization-source))
      (setq current-path (swcad-title-current-dwg-full-path))
      (setq path-ok (and destination (swcad-title-path-equal-p current-path destination)))
      (setq helper-path (swcad-title-gmtitle-autoselect-helper-path))
      (setq helper-ok (and helper-path (findfile helper-path)))
      (setq log-root (swcad-title-local-log-root-path))
      (setq local-log-ok (and log-root (vl-string-search "/SWTITLE/LOGS/" (strcase (vl-string-translate "\\" "/" log-root)))))
      (setq dbmod (getvar "DBMOD"))
      (setq all-good
        (and
          saveas-result
          marker-ok
          (equal authorization "user-selected-saveas-copy")
          path-ok
          helper-ok
          local-log-ok
          (= dbmod 0)
          (equal *swcad-title-scale-version* "260713-frame-style-structure-guard-1")
        )
      )
      (swtitle-portable-write-line handle (strcat "Source before: " source-before))
      (swtitle-portable-write-line handle (strcat "Destination expected: " destination))
      (swtitle-portable-write-line handle (strcat "Current DWG: " current-path))
      (swtitle-portable-write-line handle (strcat "Save As result: " (swtitle-portable-bool saveas-result)))
      (swtitle-portable-write-line handle (strcat "Persistent marker: " (swtitle-portable-bool marker-ok)))
      (swtitle-portable-write-line handle (strcat "Authorization: " authorization))
      (swtitle-portable-write-line handle (strcat "Path match: " (swtitle-portable-bool path-ok)))
      (swtitle-portable-write-line handle (strcat "Portable helper found: " (swtitle-portable-bool helper-ok)))
      (swtitle-portable-write-line handle (strcat "Local log root: " log-root))
      (swtitle-portable-write-line handle (strcat "Local log root valid: " (swtitle-portable-bool local-log-ok)))
      (swtitle-portable-write-line handle (strcat "DBMOD after: " (itoa dbmod)))
      (swtitle-portable-write-line handle (strcat "Result: " (if all-good "PORTABLE_WORKCOPY_OK" "PORTABLE_WORKCOPY_FAIL")))
    )
    (progn
      (if (vl-catch-all-error-p load-result)
        (swtitle-portable-write-line handle (strcat "Load error: " (vl-catch-all-error-message load-result)))
      )
      (swtitle-portable-write-line handle "Result: PORTABLE_WORKCOPY_LOAD_FAIL")
    )
  )
  (swtitle-portable-write-line handle "Runtime check completed: yes")
  (if handle (close handle))
  (princ)
)

(swtitle-portable-main)
