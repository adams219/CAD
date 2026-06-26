;;; Read-only title-block and scale diagnostic module.
;;;
;;; These commands are placeholders until GMTITLE / FTAP data samples are
;;; inspected in real drawings. They intentionally do not modify the drawing.

(setq *swcad-title-scale-loaded* T)

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

(defun c:SWTITLESCAN ()
  (swcad-title-scale-not-ready "SWTITLESCAN")
)

(defun c:SWSCALESCAN ()
  (swcad-title-scale-not-ready "SWSCALESCAN")
)

(defun c:SWTITLEDEBUG ()
  (swcad-title-scale-not-ready "SWTITLEDEBUG")
)

(princ "\n  swcad_title_scale.lsp ready")
(princ)
