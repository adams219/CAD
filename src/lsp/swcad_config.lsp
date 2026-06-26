;;; SWCAD configuration defaults.

(setq *swcad-config-loaded* T)

(setq *swcad-normal-dimstyle-candidates*
  '("AM_ISO$0" "AM_ISO" "ISO-25" "AM_ISO$3")
)

(setq *swcad-diameter-dimstyle-candidates*
  '("AM_ISO$3" "AM_ISO$0" "AM_ISO" "ISO-25")
)

(setq *swcad-solidworks-dimstyle-pattern* "*SLDDIMSTYLE*")

(princ "\n  swcad_config.lsp ready")
(princ)
