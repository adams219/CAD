;;; SWCAD loader for GstarCAD / GstarCAD Mechanical automation tools.
;;;
;;; Daily use:
;;;   APPLOAD this file, then run SWAUTO or diagnostic commands.

(vl-load-com)

(setq *swcad-version* "260704-4step-gmtitle-main63-guided-a3a4-batch")

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

(defun swcad-loader-root-valid-p (dir)
  (and
    dir
    (findfile (strcat dir "/src/tools/gmtitle/swcad_title_scale.lsp"))
  )
)

(defun swcad-loader-parent-dir (dir / clean)
  (setq clean (if dir (vl-string-right-trim "\\/" dir) nil))
  (if clean (vl-filename-directory clean) nil)
)

(defun swcad-loader-root (/ src dir dwg-dir dwg-parent user-root)
  (setq src (swcad-loader-source))
  (setq dir (if src (vl-filename-directory src) nil))
  (setq dwg-dir (getvar "DWGPREFIX"))
  (setq dwg-parent (swcad-loader-parent-dir dwg-dir))
  (setq user-root
    (if (getenv "USERPROFILE")
      (strcat (getenv "USERPROFILE") "/Documents/CAD tool")
      nil
    )
  )
  (cond
    ((swcad-loader-root-valid-p dir) dir)
    ((swcad-loader-root-valid-p dwg-dir) dwg-dir)
    ((swcad-loader-root-valid-p dwg-parent) dwg-parent)
    ((swcad-loader-root-valid-p user-root) user-root)
    (dir dir)
    (T ".")
  )
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

(swcad-load-file "src/lsp/swcad_common.lsp")
(swcad-load-file "src/lsp/swcad_config.lsp")
(swcad-load-file "src/lsp/swcad_dimstyle.lsp")
(swcad-load-file "src/lsp/swcad_mechfit.lsp")
(swcad-load-file "src/tools/gmtitle/swcad_title_scale.lsp")
(swcad-load-file "src/lsp/swcad_cleanup.lsp")
(swcad-load-file "src/lsp/swcad_debug.lsp")

;;; The current production command set is kept intact until modular migration.
(swcad-load-file "src/tools/gstarcad-dimstyle/gstarcad_dimstyle_keep_tolerance.lsp")

(princ "\nSWCAD 준비 완료.")
(princ "\n주 명령어: SWAUTO")
(princ "\n도움말: SWHELP")
(princ "\nGMTITLE 작업 흐름: SWTITLESTATUS, SWTITLEPREPARE, SWTITLECONVERT, SWTITLEVERIFY")
(princ "\nGMTITLE 참고: 예전 SWTITLE transfer/fast/A3A4/frame-only 직접 명령은 사용하지 말고 위 4단계 흐름을 사용하세요.")
(princ "\n로드된 LSP 확인: SWTITLEVERSION")
(princ)
