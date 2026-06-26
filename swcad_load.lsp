;;; SWCAD loader for GstarCAD / GstarCAD Mechanical automation tools.
;;;
;;; Daily use:
;;;   APPLOAD this file, then run SWAUTO or diagnostic commands.

(vl-load-com)

(setq *swcad-version* "260626-1356")

(defun swcad-loader-source (/ src)
  (setq src nil)
  (if (and (boundp '*load-truename*) *load-truename*)
    (setq src *load-truename*)
  )
  (if (not src)
    (setq src (findfile "swcad_load.lsp"))
  )
  src
)

(defun swcad-loader-root (/ src dir)
  (setq src (swcad-loader-source))
  (setq dir (if src (vl-filename-directory src) nil))
  (if dir dir ".")
)

(setq *swcad-root* (swcad-loader-root))

(defun swcad-path (relative)
  (strcat *swcad-root* "/" relative)
)

(defun swcad-load-file (relative / path result)
  (setq path (swcad-path relative))
  (cond
    ((findfile path)
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (progn
          (princ (strcat "\nSWCAD load failed: " relative))
          (princ (strcat "\n  " (vl-catch-all-error-message result)))
          nil
        )
        (progn
          (princ (strcat "\nSWCAD loaded: " relative))
          T
        )
      )
    )
    (T
      (princ (strcat "\nSWCAD missing module: " relative))
      nil
    )
  )
)

(princ (strcat "\nLoading SWCAD tool set " *swcad-version* "..."))

(swcad-load-file "lsp/swcad_common.lsp")
(swcad-load-file "lsp/swcad_config.lsp")
(swcad-load-file "lsp/swcad_dimstyle.lsp")
(swcad-load-file "lsp/swcad_mechfit.lsp")
(swcad-load-file "GMTITLE/swcad_title_scale.lsp")
(swcad-load-file "lsp/swcad_cleanup.lsp")
(swcad-load-file "lsp/swcad_debug.lsp")

;;; The current production command set is kept intact until modular migration.
(swcad-load-file "gstarcad_dimstyle/gstarcad_dimstyle_keep_tolerance.lsp")

(princ "\nSWCAD ready.")
(princ "\nMain command: SWAUTO")
(princ "\nHelp: SWHELP")
(princ "\nTitle/scale diagnostics planned: SWTITLESCAN, SWSCALESCAN, SWTITLEDEBUG")
(princ)
