;;; APPLOAD entry for the GMTITLE UX experiment copy.
;;;
;;; Original daily loader is unchanged:
;;;   swcad_load.lsp  ->  src/tools/gmtitle/swcad_title_scale.lsp
;;;
;;; Use this file only when comparing the copy:
;;;   APPLOAD src/tools/gmtitle/swcad_title_scale_ux_load.lsp
;;;
;;; Do not load the original GMTITLE LSP in the same CAD session.

(vl-load-com)

(defun swcad-title-ux-loader-source (/ src)
  (setq src nil)
  (if (and (boundp '*load-truename*) *load-truename*)
    (setq src *load-truename*)
  )
  (if (not src)
    (setq src (findfile "swcad_title_scale_ux_load.lsp"))
  )
  src
)

(defun swcad-title-ux-loader-dir (/ src)
  (setq src (swcad-title-ux-loader-source))
  (if src (vl-filename-directory src) ".")
)

(setq *swcad-title-ux-loader-dir* (swcad-title-ux-loader-dir))

(princ "\nLoading GMTITLE UX experiment copy...")
(if (findfile (strcat *swcad-title-ux-loader-dir* "/swcad_title_scale_ux.lsp"))
  (progn
    (load (strcat *swcad-title-ux-loader-dir* "/swcad_title_scale_ux.lsp"))
    (princ "\nUX copy commands: SWTITLEUXSTATUS SWTITLEUXPREPARE SWTITLEUXCONVERTNEXT SWTITLEUXVERIFY")
    (princ "\nOriginal SWTITLE* commands stay on swcad_load.lsp / swcad_title_scale.lsp")
  )
  (princ "\nGMTITLE UX copy missing: swcad_title_scale_ux.lsp")
)
(princ)
